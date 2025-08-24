# Script to save trade analysis data to PostgreSQL database
# Uses environment variables for database connection
# Required environment variables:
# - PGHOST: Database host
# - PGPORT: Database port
# - PGDATABASE: Database name
# - PGUSER: Database username
# - PGPASSWORD: Database password

source("data_ingestion/Rscripts/0_setup_renv.R")



# Function to get database connection
get_db_con <- function() {
  # Check for required environment variables
  required_vars <- c("PGHOST", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD")
  if (all(sapply(required_vars, Sys.getenv) != "")) {
    # Attempt to establish connection
    tryCatch({
      con <- DBI::dbConnect(
        RPostgres::Postgres(),
        host = Sys.getenv("PGHOST"),
        port = as.integer(Sys.getenv("PGPORT")),
        dbname = Sys.getenv("PGDATABASE"),
        user = Sys.getenv("PGUSER"),
        password = Sys.getenv("PGPASSWORD")
      )
      message("Successfully connected to the database")
      return(con)
    }, error = function(e) {
      stop(sprintf("Database connection failed: %s", e$message))
    })
  } else {
    stop("Required database environment variables are not set")
  }
}

# Function to save data to database
save_to_database <- function() {
  # Check if required files exist
  required_files <- c(
    #"cleaned_trade_analysis.csv",
    "trade_details.csv",
    "performance_metrics.csv"
  )
  
  missing_files <- setdiff(required_files, list.files())
  if (length(missing_files) > 0) {
    stop("Missing required files: ", paste(missing_files, collapse = ", "))
  }
  
  # Get database connection
  con <- get_db_con()
  on.exit(dbDisconnect(con), add = TRUE)
  
  # Function to safely read and write table
  safe_write_table <- function(con, table_name, file) {
    message(sprintf("Reading %s...", file))
    df <- fread(file)
    
    message(sprintf("Saving %d rows to '%s' table...", nrow(df), table_name))
    DBI::dbWriteTable(con, table_name, df, overwrite = TRUE)
    
    # Create indexes for better query performance
    tryCatch({
      if (table_name == "trade_details") {
        dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_trade_company ON trade_details(company_id)")
        dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_trade_dates ON trade_details(entry_date, exit_date)")
      } else if (table_name == "performance_metrics") {
        dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_perf_company ON performance_metrics(company_id)")
      }
    }, error = function(e) {
      message(sprintf("Warning: Could not create indexes for %s: %s", table_name, e$message))
    })
  }
  
  # Save each file to database
  tryCatch({
    #safe_write_table(con, "cleaned_trade_analysis", "cleaned_trade_analysis.csv")
    safe_write_table(con, "trade_details", "trade_details.csv")
    safe_write_table(con, "performance_metrics", "performance_metrics.csv")
    
    message("\nSuccessfully saved all data to database: ", 
            Sys.getenv("PGHOST"), ":", Sys.getenv("PGPORT"), "/", 
            Sys.getenv("PGDATABASE"))
    
    # Success message without listing tables
    message("\nData successfully saved to database")
    
  }, error = function(e) {
    stop("Error saving to database: ", e$message)
  })
}

# Main execution
if (!interactive()) {
  tryCatch({
    message("Starting database save process...")
    save_to_database()
    message("Done!")
  }, error = function(e) {
    message(sprintf("Error: %s", e$message))
    quit(status = 1)
  })
}

# Export functions for use in other scripts
if (!exists("save_trade_analysis")) {
  save_trade_analysis <- function() {
    tryCatch({
      save_to_database()
      return(TRUE)
    }, error = function(e) {
      message(sprintf("Error saving trade analysis: %s", e$message))
      return(FALSE)
    })
  }
}
