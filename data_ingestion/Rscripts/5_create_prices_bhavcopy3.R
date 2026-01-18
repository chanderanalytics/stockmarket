#!/usr/bin/env Rscript

# 5_create_prices_bhavcopy3.R
# Script to create prices_bhavcopy3 with return flags

source("data_ingestion/Rscripts/0_setup_renv.R")


# Load required packages
if (!require("RPostgres")) install.packages("RPostgres", repos = "https://cran.rstudio.com/")
if (!require("data.table")) install.packages("data.table", repos = "https://cran.rstudio.com/")
if (!require("DBI")) install.packages("DBI", repos = "https://cran.rstudio.com/")
if (!require("futile.logger")) install.packages("futile.logger", repos = "https://cran.rstudio.com/")
if (!require("optparse")) install.packages("optparse", repos = "https://cran.rstudio.com/")

library(RPostgres)
library(data.table)
library(DBI)
library(futile.logger)
library(optparse)

# Ensure log directory exists
if (!dir.exists("log")) dir.create("log", recursive = TRUE)

# Set up logging
log_file <- file.path("log", sprintf("create_prices_bhavcopy3_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S")))
flog.appender(appender.file(log_file))
flog.threshold(INFO)
flog.info("Starting to create prices_bhavcopy3 with return flags")

# Database connection function
get_db_connection <- function() {
  tryCatch({
    con <- dbConnect(
      RPostgres::Postgres(),
      dbname = Sys.getenv("PGDATABASE", "stockdb"),
      host = Sys.getenv("PGHOST", "localhost"),
      port = Sys.getenv("PGPORT", 5432),
      user = Sys.getenv("PGUSER"),
      password = Sys.getenv("PGPASSWORD")
    )
    return(con)
  }, error = function(e) {
    flog.error("Failed to connect to database: %s", e$message)
    return(NULL)
  })
}

# Function to create prices_bhavcopy3 with return flags
create_prices_bhavcopy3 <- function(con, batch_size = 1000) {
  tryCatch({
    # Check if table already exists
    table_exists <- dbGetQuery(con, "
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'prices_bhavcopy3'
      )
    ")$exists
    
    if (table_exists) {
      flog.info("prices_bhavcopy3 already exists. Dropping and recreating...")
      dbExecute(con, "DROP TABLE IF EXISTS prices_bhavcopy3")
    }
    
    # Create the new table with return flags and financial bins
    flog.info("Creating prices_bhavcopy3 table...")
    dbExecute(con, "
      CREATE TABLE prices_bhavcopy3 AS
      SELECT 
        p.*,
        NULL::INTEGER as return_gt_4_5pct,
        NULL::INTEGER as return_gt_9_5pct
      FROM prices_bhavcopy_2 p
      WHERE 1=0  -- Create empty table with same structure
    ")
    
    # Add primary key and indexes
    dbExecute(con, "
      ALTER TABLE prices_bhavcopy3 
      ADD PRIMARY KEY (id),
      ADD UNIQUE (company_id, timestamp)
    ")
    
    # Calculate merge rate between prices_bhavcopy_2 and merged_price_baseline_probabilities_wide
    merge_stats <- dbGetQuery(con, "
      WITH 
      base_companies AS (
        SELECT DISTINCT company_id::text 
        FROM prices_bhavcopy_2
      ),
      merged_companies AS (
        SELECT DISTINCT company_id::text 
        FROM merged_price_baseline_probabilities_wide
      )
      SELECT 
        COUNT(DISTINCT b.company_id)::integer as total_companies,
        COUNT(DISTINCT m.company_id)::integer as merged_companies,
        ROUND(COUNT(DISTINCT m.company_id) * 100.0 / 
              NULLIF(COUNT(DISTINCT b.company_id), 0), 2) as merge_percentage
      FROM base_companies b
      LEFT JOIN merged_companies m ON b.company_id = m.company_id
    ")
    
    flog.info("Merge rate with merged_price_baseline_probabilities_wide:")
    flog.info("Total companies in prices_bhavcopy_2: %d", as.integer(merge_stats$total_companies))
    flog.info("Companies found in merged table: %d", as.integer(merge_stats$merged_companies))
    flog.info("Merge percentage: %.2f%%", merge_stats$merge_percentage)
    
    company_count <- merge_stats$total_companies
    
    flog.info("Processing %s companies in batches of %s", 
             as.character(company_count), 
             as.character(batch_size))
    
    # Process companies in batches
    offset <- 0
    processed <- 0
    
    while (TRUE) {
      # Get a batch of company IDs
      company_batch <- dbGetQuery(con, "
        SELECT DISTINCT company_id 
        FROM prices_bhavcopy_2
        ORDER BY company_id
        LIMIT $1 OFFSET $2
      ", params = list(batch_size, offset))$company_id
      
      if (length(company_batch) == 0) break
      
      flog.info("Processing companies %s to %s of %s", 
                as.character(offset + 1), 
                as.character(offset + length(company_batch)), 
                as.character(company_count))
      
      # Process each company in the batch
      for (company_id in company_batch) {
        # Calculate returns and insert into new table
        dbExecute(con, "
          INSERT INTO prices_bhavcopy3
          SELECT 
            p.*,
            CASE 
              WHEN 100 * (p.close - prev_p.close) / NULLIF(prev_p.close, 0) > 4.5 THEN 1
              WHEN prev_p.close IS NULL THEN NULL
              ELSE 0
            END as return_gt_4_5pct,
            CASE 
              WHEN 100 * (p.close - prev_p.close) / NULLIF(prev_p.close, 0) > 9.5 THEN 1
              WHEN prev_p.close IS NULL THEN NULL
              ELSE 0
            END as return_gt_9_5pct
          FROM prices_bhavcopy_2 p
          LEFT JOIN LATERAL (
            SELECT close 
            FROM prices_bhavcopy_2 
            WHERE company_id = p.company_id 
            AND timestamp < p.timestamp
            ORDER BY timestamp DESC 
            LIMIT 1
          ) prev_p ON true
          WHERE p.company_id = $1
          ORDER BY p.timestamp
          ON CONFLICT (company_id, timestamp) DO NOTHING
        ", params = list(company_id))
        
        processed <- processed + 1
        if (processed %% 100 == 0) {
          flog.info("Processed %s of %s companies (%s%%)", 
                   as.character(processed), 
                   as.character(company_count), 
                   as.character(round(100 * processed / company_count, 1)))
        }
      }
      
      offset <- offset + batch_size
    }
    
    # Add indexes for better query performance
    flog.info("Adding indexes to prices_bhavcopy3...")
    
    # Execute each index creation separately
    index_queries <- c(
      "CREATE INDEX idx_prices_b3_company_id ON prices_bhavcopy3(company_id)",
      "CREATE INDEX idx_prices_b3_timestamp ON prices_bhavcopy3(timestamp)",
      "CREATE INDEX idx_prices_b3_return_4_5pct ON prices_bhavcopy3(return_gt_4_5pct) WHERE return_gt_4_5pct = 1",
      "CREATE INDEX idx_prices_b3_return_9_5pct ON prices_bhavcopy3(return_gt_9_5pct) WHERE return_gt_9_5pct = 1"
    )
    
    for (query in index_queries) {
      dbExecute(con, query)
      flog.info("Created index: %s", query)
    }
    
    flog.info("Successfully created prices_bhavcopy3 with return flags")
    return(TRUE)
    
  }, error = function(e) {
    flog.error("Error in create_prices_bhavcopy3: %s", e$message)
    return(FALSE)
  })
}

# Function to delete records for a specific date
delete_records_for_date <- function(con, delete_date) {
  tryCatch({
    flog.info("Deleting records for date: %s", as.character(delete_date))
    
    # Delete records for the specified date
    result <- dbExecute(con, "
      DELETE FROM prices_bhavcopy3 
      WHERE DATE(timestamp) = $1
    ", params = list(delete_date))
    
    flog.info("Deleted %d records for date %s", result, as.character(delete_date))
    return(TRUE)
    
  }, error = function(e) {
    flog.error("Error deleting records for date %s: %s", as.character(delete_date), e$message)
    return(FALSE)
  })
}

# Function to update prices_bhavcopy3 with new data
update_prices_bhavcopy3 <- function(con) {
  tryCatch({
    # Find the latest date in prices_bhavcopy3
    latest_date <- dbGetQuery(con, "
      SELECT COALESCE(MAX(timestamp), '1900-01-01'::date) as latest_date 
      FROM prices_bhavcopy3
    ")$latest_date
    
    flog.info("Latest date in prices_bhavcopy3: %s", as.character(latest_date))
    
    # Get new dates to process
    new_dates <- dbGetQuery(con, "
      SELECT DISTINCT timestamp as date 
      FROM prices_bhavcopy_2 
      WHERE timestamp > $1
      ORDER BY timestamp
    ", params = list(latest_date))$date
    
    if (length(new_dates) == 0) {
      flog.info("No new dates to process")
      return(TRUE)
    }
    
    flog.info("Processing %d new dates", length(new_dates))
    
    # Process each new date
    for (i in seq_along(new_dates)) {
      current_date <- new_dates[i]
      flog.info("Processing date: %s (%d/%d)", 
               as.character(current_date), i, length(new_dates))
      
      # Insert new records with return flags
      dbExecute(con, "
        INSERT INTO prices_bhavcopy3
        SELECT 
          p.*,
          CASE 
            WHEN (p.close - prev_p.close) / NULLIF(prev_p.close, 0) > 0.045 THEN TRUE
            WHEN prev_p.close IS NULL THEN NULL
            ELSE FALSE
          END as return_gt_4_5pct,
          CASE 
            WHEN (p.close - prev_p.close) / NULLIF(prev_p.close, 0) > 0.095 THEN TRUE
            WHEN prev_p.close IS NULL THEN NULL
            ELSE FALSE
          END as return_gt_9_5pct
        FROM prices_bhavcopy_2 p
        LEFT JOIN LATERAL (
          SELECT close 
          FROM prices_bhavcopy_2 
          WHERE company_id = p.company_id 
          AND timestamp < p.timestamp
          ORDER BY timestamp DESC 
          LIMIT 1
        ) prev_p ON true
        WHERE p.timestamp = $1
      ", params = list(current_date))
    }
    
    flog.info("Successfully updated prices_bhavcopy3 with new data")
    return(TRUE)
    
  }, error = function(e) {
    flog.error("Error in update_prices_bhavcopy3: %s", e$message)
    return(FALSE)
  })
}

# Main function
main <- function() {
  # Set up logging first
  log_file <- file.path("log", paste0("create_prices_bhavcopy3_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
  dir.create("log", showWarnings = FALSE, recursive = TRUE)
  
  flog.appender(appender.tee(log_file))
  flog.threshold(INFO)
  flog.info("Starting script execution")
  
  # Parse command line arguments
  option_list <- list(
    make_option(c("-u", "--update"), action="store_true", default=FALSE, 
                help="Update existing prices_bhavcopy3 table instead of recreating it"),
    make_option(c("--batch-size"), type="integer", default=1000, 
                help="Number of companies to process in each batch [default: 1000]"),
    make_option(c("--delete-date"), type="character", default=NA,
                help="Delete records for a specific date (YYYY-MM-DD) before processing")
  )
  
  flog.info("Parsing command line arguments")
  opt_parser <- OptionParser(option_list=option_list)
  opt <- parse_args(opt_parser)
  
  # Connect to database
  flog.info("Connecting to database...")
  con <- tryCatch({
    conn <- dbConnect(RPostgres::Postgres(), 
                     dbname = Sys.getenv("PGDATABASE"),
                     host = Sys.getenv("PGHOST"),
                     port = Sys.getenv("PGPORT"),
                     user = Sys.getenv("PGUSER"),
                     password = Sys.getenv("PGPASSWORD"))
    flog.info("Successfully connected to database")
    conn
  }, error = function(e) {
    flog.error("Failed to connect to database: %s", e$message)
    stop("Database connection failed")
  })
  
  # Call appropriate function based on update flag
  if (opt$update) {
    success <- update_prices_bhavcopy3(con)
  } else {
    success <- create_prices_bhavcopy3(con, opt$`batch-size`)
  }
  
  # Delete records for specified date if provided (after processing)
  if (!is.na(opt$`delete-date`) && success) {
    delete_success <- delete_records_for_date(con, opt$`delete-date`)
    if (!delete_success) {
      flog.warn("Failed to delete records for date: %s", opt$`delete-date`)
    }
  }
  
  # Close database connection
  flog.info("Closing database connection")
  dbDisconnect(con)
  
  if (success) {
    flog.info("Script completed successfully")
    quit(status = 0)
  } else {
    flog.error("Script failed")
    quit(status = 1)
  }
}

# Run the main function
if (!interactive()) {
  status <- tryCatch({
    main()
  }, error = function(e) {
    flog.error("Script failed: %s", e$message)
    1
  })
  
  quit(save = "no", status = status)
}
