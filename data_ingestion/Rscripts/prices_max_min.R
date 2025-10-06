# prices_max_min

source("data_ingestion/Rscripts/0_setup_renv.R")

# Load libraries
library(DBI)
library(RPostgres)
library(data.table)
library(futile.logger)


# Set up logging
log_file <- sprintf("log/prices_max_min_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
flog.appender(appender.file(log_file))
flog.info("Starting prices max min script")

# Load credentials from environment variables
user <- Sys.getenv("PGUSER")
password <- Sys.getenv("PGPASSWORD")
host <- Sys.getenv("PGHOST", "localhost")
port <- as.integer(Sys.getenv("PGPORT", "5432"))
dbname <- Sys.getenv("PGDATABASE", "stockdb")

# Connect to PostgreSQL
db_con <- dbConnect(
  RPostgres::Postgres(),
  dbname = dbname,
  host = host,
  port = port,
  user = user,
  password = password
)

tryCatch({
  # Get price data from the v2 compatible view
  flog.info("Fetching price data from prices_v2_compatible view...")
  query <- "
    SELECT 
      company_id,
      company_name,
      date,
      close as adj_close
    FROM prices_v2_compatible
  "
  prices_dt <- as.data.table(dbGetQuery(db_con, query))
  
  # Process data
  flog.info("Processing data...")
  prices_dt[, date := as.Date(date)]
  
  # Ensure we have valid data
  prices_dt <- prices_dt[!is.na(company_id) & !is.na(company_name) & !is.na(adj_close) & adj_close > 0]
  
  # Sort by company_id and date (newest first)
  setorder(prices_dt, company_id, -date)
  
  # Add row numbers for each company_id
  prices_dt[, row_num := seq_len(.N), by = company_id]
  
  # Calculate max/min prices and dates (grouped by company_id)
  prices_dt[, `:=`(
    max_price_historical = max(adj_close, na.rm = TRUE),
    min_price_historical = min(adj_close, na.rm = TRUE)
  ), by = company_id]
  
  # Calculate percentages
  prices_dt[is.finite(max_price_historical) & adj_close > 0,
          cmp_from_max := ((adj_close - max_price_historical) / max_price_historical) * 100]
          
  prices_dt[is.finite(min_price_historical) & min_price_historical > 0,
          cmp_from_min := ((adj_close - min_price_historical) / min_price_historical) * 100]
  
  # Get dates for min/max prices (grouped by company_id)
  prices_dt[, `:=`(
    max_date = date[which.max(adj_close)][1],  # Take first date if multiple max values
    min_date = date[which.min(adj_close)][1]   # Take first date if multiple min values
  ), by = company_id]
  
  # Keep only the most recent row for each company_id
  result_dt <- prices_dt[row_num == 1, ]
  
  # Truncate and update the table
  flog.info("Truncating prices_max_min table...")
  dbExecute(db_con, "TRUNCATE TABLE prices_max_min")
  
  # Write to database
  flog.info("Writing results to database...")
  dbWriteTable(db_con, "prices_max_min", as.data.frame(result_dt), append = TRUE)
  flog.info(sprintf("Successfully updated data for %d companies", nrow(result_dt)))
  
}, error = function(e) {
  flog.error("Error in script: %s", e$message)
  stop(e)
}, finally = {
  # Ensure database connection is closed
  if (exists("db_con") && dbIsValid(db_con)) {
    dbDisconnect(db_con)
    flog.info("Disconnected from database.")
  }
  flog.info("Script completed")
})