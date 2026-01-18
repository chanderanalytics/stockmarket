#!/usr/bin/env Rscript
# mmtm_preparedata.R
# This script loads and prepares the base data, then calculates all technical indicators.
# The resulting data.table (dt) and companies data will be saved for mmtm_runscenarios.R.

source("data_ingestion/Rscripts/0_setup_renv.R")

# 1.1 Configure logging system
# ----------------------------------------------------------------------------
# Create log directory if it doesn't exist
if (!dir.exists("log")) {
  dir.create("log", recursive = TRUE)
}

log_file <- file.path("log", sprintf("mmtm_preparedata_%s.log", 
                                   format(Sys.time(), "%Y%m%d_%H%M%S")))
file.create(log_file)

log_message <- function(msg, level = "INFO") {
  if (length(msg) > 1) {
    msg <- paste(msg, collapse = " ")
  }
  
  if (level == "INFO" && any(grepl("company", tolower(msg)))) {
    # return() # Temporarily disabled for debugging
  }
  
  log_line <- sprintf("[%s] [%s] %s\n", 
                     format(Sys.time(), "%Y-%m-%d %H:%M:%S"), 
                     level, 
                     msg)
  
  if (level %in% c("ERROR", "WARN", "INFO")) {
    cat(log_line)
  }
  
  if (exists("log_file")) {
    cat(log_line, file = log_file, append = TRUE)
  }
  flush.console()
}

timer <- function(expr, message_text = "") {
  start <- Sys.time()
  log_message(paste0("START: ", message_text))
  res <- eval(expr)
  elapsed <- round(as.numeric(difftime(Sys.time(), start, units = "secs")), 2)
  log_message(paste0("COMPLETE: ", message_text, " (", elapsed, "s)"))
  res
}

# Try to source enriched indicators module if present
if (file.exists("data_ingestion/Rscripts/s2.2_calculate_indicators_module.R")) {
  tryCatch({
    source("data_ingestion/Rscripts/s2.2_calculate_indicators_module.R", local = FALSE)
    log_message("Loaded calculate_indicators_enriched module")
  }, error = function(e) {
    log_message(sprintf("Failed to load calculate_indicators_enriched: %s", e$message), "WARN")
  })
}


# 2.2 Argument Parsing (simplified for prepare data)
# ----------------------------------------------------------------------------
#' Parse Command Line Arguments
#' 
#' Parses command line arguments to get reference date and limit_companies.
#' @return List containing script parameters
parse_arguments <- function() {
 args <- commandArgs(trailingOnly = TRUE)
 
 # Default values
 params <- list(
  ref_date = Sys.Date(),
  limit_companies = NULL
 )
 
 # Parse reference date if provided
 if (length(args) > 0) {
  ref_date <- tryCatch(
   as.Date(args[1]),
   error = function(e) {
    log_message(sprintf("Invalid date format: %s. Using current date.", args[1]), "WARN")
    return(Sys.Date())
   }
  )
  params$ref_date <- ref_date
 }
 
 # Parse additional flags
 if (length(args) > 1) {
  limit_arg <- grep("^--limit_companies=", args, value = TRUE)
  if (length(limit_arg) == 1) {
   params$limit_companies <- as.integer(sub("^--limit_companies=", "", limit_arg))
   if (is.na(params$limit_companies) || params$limit_companies <= 0) {
    log_message(sprintf("Invalid limit_companies value: %s. Ignoring limit.", sub("^--limit_companies=", "", limit_arg)), "WARN")
    params$limit_companies <- NULL
   }
  }
 }
 
 return(params)
}

# Parse command line arguments
params <- parse_arguments()
ref_date <- params$ref_date

# Create data directory if it doesn't exist
if (!dir.exists("data")) {
  dir.create("data", recursive = TRUE)
  log_message("Created data directory for intermediate files.")
}

# ============================================================================
# 3. DATABASE FUNCTIONS
# ============================================================================

#' Establish Database Connection
#' 
#' Creates a connection to the PostgreSQL database using environment variables.
#' @return A database connection object or NULL if connection fails or
#'     environment variables are not set.
#' @details
#' Required environment variables:
#' - PGHOST: Database hostname
#' - PGPORT: Database port
#' - PGDATABASE: Database name
#' - PGUSER: Database username
#' - PGPASSWORD: Database password
#' 
#' @examples
#' # Set environment variables first:
#' # Sys.setenv(PGHOST="localhost", PGPORT=5432, PGDATABASE="mydb",
#' #      PGUSER="user", PGPASSWORD="password")
#' con <- get_db_con()
#' if (!is.null(con)) {
#'  # Use the connection
#'  DBI::dbDisconnect(con)
#' }
get_db_con <- function() {
 # 4.1 Check for required environment variables
 required_vars <- c("PGHOST", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD")
 if (all(sapply(required_vars, Sys.getenv) != "")) {
  # 4.2 Attempt to establish connection
  tryCatch({
   con <- DBI::dbConnect(
    RPostgres::Postgres(),
    host = Sys.getenv("PGHOST"),
    port = as.integer(Sys.getenv("PGPORT")),
    dbname = Sys.getenv("PGDATABASE"),
    user = Sys.getenv("PGUSER"),
    password = Sys.getenv("PGPASSWORD")
   )
   log_message("Successfully connected to the database")
   return(con)
  }, error = function(e) {
   log_message(sprintf("Database connection failed: %s", e$message), "WARN")
   return(NULL)
  })
 } else {
  # 4.3 Fallback to local files if DB connection not available
  log_message("Database connection variables not set. Using local files.", "WARN")
  return(NULL)
 }
}

# ============================================================================
# 4. DATA LOADING AND PREPARATION FUNCTIONS
# ============================================================================

#' Load and Prepare Data
#' 
#' Loads company and price data from the database or CSV, merges them,
#' and performs initial data validation and filtering.
#' @param con Database connection object (can be NULL).
#' @param ref_date Reference date for data filtering.
#' @param limit_companies Optional integer to limit the number of companies loaded.
#' @return A list containing the merged data.table (dt) and the companies data.table.
load_and_prepare_data <- function(con, ref_date, limit_companies) {
 log_message("Loading data...")
 dt <- data.table() # Initialize dt here
 companies <- data.table() # Initialize companies here
 
 # Try to load from database first
 if (!is.null(con)) {
  tryCatch({
   log_message("Loading companies and prices from DB")
   
   # Load Companies (potentially limited)
   log_message("Loading companies from database...")
   query <- "SELECT * FROM companies ORDER BY id"
   if (!is.null(limit_companies)) {
    query <- paste0(query, sprintf(" LIMIT %d", limit_companies))
    log_message(sprintf("Limiting to %d companies for testing.", limit_companies))
   }
   companies <- data.table::as.data.table(DBI::dbGetQuery(con, query))
   if ("id" %in% names(companies) && !"company_id" %in% names(companies)) {
    data.table::setnames(companies, "id", "company_id")
   }
   log_message(sprintf("Loaded %d companies", nrow(companies)))
   log_message(sprintf("DEBUG (post-DB load): names(companies) = %s", paste(names(companies), collapse = ", ")), "DEBUG")
   log_message(sprintf("DEBUG (post-DB load): class(companies$company_id) = %s", class(companies$company_id)), "DEBUG")
   log_message(sprintf("DEBUG (post-DB load): head(companies$company_id) = %s", paste(head(companies$company_id), collapse = ", ")), "DEBUG")
   
   if (nrow(companies) == 0) {
    log_message("No companies found. Exiting.", "ERROR")
    stop("No companies found.")
   }
   
   # Load prices with date filtering
   log_message("Loading prices from database (prices_v2_compatible view)...")
   log_message(sprintf("DEBUG (pre-company_ids_str): nrow(companies) = %d", nrow(companies)), "DEBUG")
   if (nrow(companies) > 0) {
     log_message(sprintf("DEBUG (pre-company_ids_str): names(companies) = %s", paste(names(companies), collapse = ", ")), "DEBUG")
     log_message(sprintf("DEBUG (pre-company_ids_str): class(companies$company_id) = %s", class(companies$company_id)), "DEBUG")
     log_message(sprintf("DEBUG (pre-company_ids_str): length(companies$company_id) = %d", length(companies$company_id)), "DEBUG")
     if (length(companies$company_id) > 0) {
       log_message(sprintf("DEBUG (pre-company_ids_str): Sample company_ids: %s", paste(head(companies$company_id), collapse = ", ")), "DEBUG")
     } else {
       log_message("DEBUG (pre-company_ids_str): companies$company_id is empty.", "DEBUG")
     }
   } else {
     log_message("DEBUG (pre-company_ids_str): companies data.table is empty.", "DEBUG")
   }
   # Prepare company_ids for SQL IN clause
   company_ids_str <- if (nrow(companies) > 0) {
     paste0("('", paste(companies$company_id, collapse = "','"), "')")
   } else {
     log_message("No companies loaded, using dummy company_id for price query to prevent SQL error.", "WARN")
     "('DUMMY')" # Use a dummy value to prevent SQL error for empty IN clause
   }
   
   # Query to get all columns from prices_v2_compatible and map total_traded_quantity to volume
   query <- sprintf(
    "SELECT 
       p.*, 
       p.total_traded_quantity AS volume 
     FROM prices_v2_compatible p 
     WHERE p.date <= '%s' 
     AND p.company_id IN %s 
     ORDER BY p.company_id, p.date",
    format(ref_date, "%Y-%m-%d"),
    company_ids_str
   )
   log_message(sprintf("Executing query for prices: %s", query))
   
   prices <- data.table::as.data.table(DBI::dbGetQuery(con, query))
   log_message(sprintf("Fetched %d price records from prices_v2_compatible for %d companies up to %s", 
                       nrow(prices), length(unique(prices$company_id)), format(ref_date, "%Y-%m-%d")))
   
  }, error = function(e) {
   log_message(sprintf("Error loading from database: %s", e$message), "ERROR")
   con <- NULL # Force fallback to CSV
  })
 }
 
 
 # Data Preparation and Merging
 log_message("Preparing and merging data...")
 
 tryCatch({
  # Standardize column names
  if ("id" %in% names(companies) && !"company_id" %in% names(companies)) {
   data.table::setnames(companies, "id", "company_id")
  }
  
  # Ensure data.table format
  if (!is.data.table(companies)) companies <- as.data.table(companies)
  if (!is.data.table(prices)) prices <- as.data.table(prices)
  
  # Convert date columns to Date type
  if ("date" %in% names(prices) && !inherits(prices$date, "Date")) {
   prices[, date := as.Date(date)]
  }
  
  # Filter prices to only include last 2 years from reference date
  two_years_ago <- ref_date - 730 # 365 * 2 days
  prices <- prices[date >= two_years_ago]
  log_message(sprintf("Filtered prices to %d rows from last 2 years", nrow(prices)))
  
  # Check for required columns in companies
  if (!"company_id" %in% names(companies)) {
   stop("companies must contain 'company_id' column")
  }
  
  # Check for required columns in prices
  price_cols <- c("company_id", "date", "open", "high", "low", "close", "volume")
  missing_price_cols <- setdiff(price_cols, names(prices))
  if (length(missing_price_cols) > 0) {
   stop(sprintf("Missing required columns in prices: %s", 
         paste(missing_price_cols, collapse = ", ")))
  }
  
  # Ensure no duplicate company_id in companies
  if (any(duplicated(companies$company_id))) {
   log_message("Warning: Duplicate company_id found in companies table", "WARN")
   companies <- unique(companies, by = "company_id")
  }
  
  # Ensure prices are ordered
  setorder(prices, company_id, date)
  
  # Merge companies and prices
  log_message("Merging companies and prices...")
  
  # First, ensure we only keep necessary columns from companies
  company_cols <- c("company_id", "name", "bse_code", "nse_code", "industry")
  company_cols <- intersect(company_cols, names(companies))
  
  # Select only required columns from companies
  companies_subset <- companies[, ..company_cols]
  
  # If companies also has a volume column, explicitly select which one to keep
  if ("volume" %in% names(companies_subset)) {
   log_message("Found volume column in companies table - using volume from prices table", "INFO")
   companies_subset[, volume := NULL] # Remove volume from companies
  }
  
  # Merge with prices using only company_id as the key
  log_message("Merging companies with price data...")
  dt <- merge(
   companies_subset,
   prices,
   by = "company_id",
   all.x = TRUE,
   allow.cartesian = TRUE
  )
  
  # Clean up any duplicate volume columns
  if ("volume.x" %in% names(dt) && "volume.y" %in% names(dt)) {
   log_message("Cleaning up duplicate volume columns - using volume from prices", "INFO")
   dt[, volume := volume.y]
   dt[, c("volume.x", "volume.y") := NULL]
  }
  
  # Verify we have the expected volume column
  if (!"volume" %in% names(dt)) {
   stop("Volume column not found in merged data")
  }
  
  # Check if merge was successful
  if (nrow(dt) == 0) {
   stop("Merge resulted in 0 rows. Check if company_id matches between tables.")
  }
  
  # Ensure date is Date type after merge
  if (!inherits(dt$date, "Date")) {
   dt[, date := as.Date(date)]
  }
  
  # Order the final dataset
  setorder(dt, company_id, date)
  
  # Log merge results
  log_message(sprintf("Merge complete: %d rows, %d columns", nrow(dt), ncol(dt)))
  log_message(sprintf("Date range: %s to %s", 
            min(dt$date, na.rm = TRUE), 
            max(dt$date, na.rm = TRUE)))
  log_message(sprintf("Unique companies: %d", uniqueN(dt$company_id)))
  
 }, error = function(e) {
  log_message(sprintf("Error during data preparation: %s", e$message), "ERROR")
  stop("Failed to prepare data. See logs for details.")
 })
 
 # Data Validation
 log_message("Validating data structure...")
 required_cols <- c("company_id", "date", "open", "high", "low", "close", "volume")
 missing_cols <- setdiff(required_cols, names(dt))
 if (length(missing_cols) > 0) {
  log_message(sprintf("Missing required columns: %s", paste(missing_cols, collapse = ", ")), "ERROR")
  stop("Input data is missing required price/volume columns")
 }
 
 return(list(dt = dt, companies = companies))
}

#' Calculate Technical Indicators
#' 
#' Applies various technical indicators to the price data for momentum analysis.
#' @param dt data.table containing OHLCV data with columns: date, open, high, low, close, volume
#' @return data.table with added technical indicators
#' @details
#' This function delegates all indicator calculations to calculate_indicators_enriched in calculate_indicators_module.R
calculate_indicators <- function(dt) {
  log_message("Delegating indicator calculations to calculate_indicators_enriched...")
  if (exists("calculate_indicators_enriched") && is.function(calculate_indicators_enriched)) {
    return(calculate_indicators_enriched(dt))
  } else {
    log_message("Error: calculate_indicators_enriched function not found. Skipping indicator calculations.", "ERROR")
    return(dt)
  }
}

# ============================================================================
# 5. MAIN EXECUTION - PREPARE DATA
# ============================================================================

#' Main Execution Function for Data Preparation
#' 
#' Orchestrates the data loading, preparation, and indicator calculation pipeline.
#' Saves the intermediate data for subsequent scenario runs.
#' @return Invisible NULL
main_prepare_data <- function() {
  log_message("Momentum cycle signal generation - Prepare Data (v2) starting")
  start_time <- Sys.time()
  
  # Debug: Print session info
  log_message("Session Info:")
  log_message(sessionInfo()$R.version$version.string)
  log_message(sprintf("Working directory: %s", getwd()))
  
  # 3.1 Database Connection
  con <- NULL
  tryCatch({
    con <- get_db_con()
    if (is.null(con)) {
      stop("Failed to establish database connection")
    }
    log_message("Successfully connected to the database")
  }, error = function(e) {
    log_message(sprintf("FATAL: Database connection error: %s", e$message), "ERROR")
    stop(e)  # Re-throw to stop execution
  })
  
  # 3.2 Data Loading and Initial Preparation
  tryCatch({
    data_list <- load_and_prepare_data(con, ref_date, params$limit_companies)
    if (is.null(data_list$dt) || nrow(data_list$dt) == 0) {
      stop("No data returned from load_and_prepare_data")
    }
    dt_base <- data_list$dt
    companies_base <- data_list$companies
  }, error = function(e) {
    log_message(sprintf("FATAL: Data loading failed: %s", e$message), "ERROR")
    stop(e)
  })
  
  # 3.3 Calculate Indicators on the Base Dataset
  log_message("Calculating all technical indicators (this may take a while)...")
  dt_indicators <- timer({ calculate_indicators(dt_base) }, "Indicator Calculation")
  log_message(sprintf("Indicators calculated. Total columns: %d", ncol(dt_indicators)))
  
  # 3.4 Save the intermediate datasets as CSV files
  if (!dir.exists("output/mmtm")) {
    dir.create("output/mmtm", recursive = TRUE)
  }
  
  # Save main data to the location s3 expects
  data_file <- sprintf("output/mmtm/prepared_data_%s.csv", format(ref_date, "%Y-%m-%d"))
  log_message(sprintf("Saving intermediate data to %s", data_file))
  data.table::fwrite(dt_indicators, file = data_file)
  
  # Save companies data
  companies_file <- "data/mmtm_companies_data.csv"
  log_message(sprintf("Saving companies data to %s", companies_file))
  data.table::fwrite(companies_base, file = companies_file)
  
  log_message("Intermediate datasets saved successfully as CSV files.")
  
  # Clean up DB connection
  if (!is.null(con)) {
    DBI::dbDisconnect(con)
    log_message("DB connection closed")
  }
  
  elapsed_total <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 2)
  log_message(paste("Total prepare data execution time:", elapsed_total, "seconds"))
  
  return(invisible(NULL))
}

# ============================================================================
# 6. SCRIPT EXECUTION
# ============================================================================

# 6.1 Main Execution Block
# ----------------------------------------------------------------------------
# Only execute if run as a script (not sourced)
if (identical(environment(), globalenv())) {
  tryCatch({
    # Execute Main Function
    main_prepare_data()
    
    # Final Status
    log_message("Script completed successfully", "SUCCESS")
  }, error = function(e) {
    error_msg <- if (is.null(e$message)) {
      if (inherits(e, "simpleError")) {
        as.character(e)
      } else {
        "Unknown error occurred"
      }
    } else {
      e$message
    }
    
    log_message(sprintf("Fatal error in execution: %s", error_msg), "ERROR")
    
    if (exists(".traceback")) {
      log_message("Stack trace:", "ERROR")
      log_message(utils::capture.output(print(.traceback())), "ERROR")
    }
    
    if (exists("con") && DBI::dbIsValid(con)) {
      tryCatch({
        DBI::dbDisconnect(con)
        log_message("Database connection closed due to error")
      }, error = function(e) {
        log_message(sprintf("Error closing database connection: %s", e$message), "ERROR")
      })
    }
    
    stop(simpleError(error_msg, call = sys.calls()[[1]]))
  })
} 