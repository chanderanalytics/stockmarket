#!/usr/bin/env Rscript

# s5_create_tables_and_load.R
# Script to create database tables and load consolidated CSV data
# Created: 2025-12-30

# Load required packages
suppressPackageStartupMessages({
  library(data.table)
  library(stringr)
  library(glue)
  library(assertthat)
  library(DBI)
  library(RPostgres)
})

# Configuration
config <- list(
  # Database connection settings - modify these as needed
  db_config = list(
    host = "localhost",
    port = 5432,
    dbname = "stockmarket",
    user = "postgres",
    password = "your_password"
  ),
  # File paths
  consolidated_dir = "/Users/chanderbhushan/stockmkt/output/mmtm/consolidated",
  ref_date = "2025-12-29"
)

# Table creation SQL statements
create_table_sql <- list(
  performance_metrics = "
    CREATE TABLE IF NOT EXISTS performance_metrics (
      scenario VARCHAR(20) NOT NULL,
      reference_date DATE NOT NULL,
      company_id INT NOT NULL,
      company_name VARCHAR(100),
      total_trades INT,
      winning_trades INT,
      losing_trades INT,
      open_trades INT,
      win_rate DECIMAL(10, 2),
      avg_pnl DECIMAL(10, 2),
      avg_win DECIMAL(10, 2),
      avg_loss DECIMAL(10, 2),
      win_loss_ratio DECIMAL(10, 2),
      profit_factor DECIMAL(10, 2),
      max_drawdown DECIMAL(10, 2),
      recovery_factor DECIMAL(10, 2),
      sharpe_ratio DECIMAL(10, 2),
      sortino_ratio DECIMAL(10, 2),
      best_trade DECIMAL(10, 2),
      worst_trade DECIMAL(10, 2),
      avg_days_held DECIMAL(10, 2),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (scenario, company_id, reference_date)
    );
  ",
  
  trade_details = "
    CREATE TABLE IF NOT EXISTS trade_details (
      scenario VARCHAR(20) NOT NULL,
      reference_date DATE NOT NULL,
      trade_id BIGSERIAL PRIMARY KEY,
      company_id INT,
      company_name VARCHAR(100),
      entry_date DATE,
      entry_price DECIMAL(15, 2),
      exit_date DATE,
      exit_price DECIMAL(15, 2),
      pnl_percent DECIMAL(10, 2),
      pnl_amount DECIMAL(15, 2),
      days_held INT,
      exit_reason VARCHAR(50),
      max_drawdown DECIMAL(10, 2),
      max_runup DECIMAL(10, 2),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_trade_details_scenario ON trade_details(scenario);
    CREATE INDEX IF NOT EXISTS idx_trade_details_company ON trade_details(company_id);
    CREATE INDEX IF NOT EXISTS idx_trade_details_dates ON trade_details(entry_date, exit_date);
  ",
  
  atr_volatility = "
    CREATE TABLE IF NOT EXISTS atr_volatility_performance (
      scenario VARCHAR(20) NOT NULL,
      reference_date DATE NOT NULL,
      company_id INT NOT NULL,
      company_name VARCHAR(100),
      atr_14 DECIMAL(15, 2),
      atr_percent DECIMAL(10, 2),
      avg_true_range DECIMAL(15, 2),
      volatility_14d DECIMAL(10, 2),
      volatility_30d DECIMAL(10, 2),
      volatility_60d DECIMAL(10, 2),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (scenario, company_id, reference_date)
    );
  "
)

# Function to connect to database
connect_to_db <- function() {
  message("Connecting to database...")
  
  # Try to connect with the configured settings
  con <- tryCatch({
    dbConnect(
      RPostgres::Postgres(),
      host = config$db_config$host,
      port = config$db_config$port,
      dbname = config$db_config$dbname,
      user = config$db_config$user,
      password = config$db_config$password
    )
  }, error = function(e) {
    message("Database connection failed. Please check your configuration.")
    message("Error:", e$message)
    return(NULL)
  })
  
  if (is.null(con)) {
    stop("Could not connect to database")
  }
  
  message("Database connection successful!")
  return(con)
}

# Function to create tables
create_tables <- function(con) {
  message("Creating tables...")
  
  # Create each table
  for (table_name in names(create_table_sql)) {
    message(glue("Creating table: {table_name}"))
    dbExecute(con, create_table_sql[[table_name]])
    message(glue("Table {table_name} created successfully"))
  }
  
  message("All tables created successfully!")
}

# Function to load CSV data into database
load_csv_to_table <- function(con, csv_file, table_name) {
  message(glue("Loading {csv_file} into {table_name}..."))
  
  # Read the CSV file
  dt <- fread(csv_file)
  
  # Check if data exists
  if (nrow(dt) == 0) {
    message(glue("No data found in {csv_file}"))
    return(FALSE)
  }
  
  # Remove any existing data for this reference date
  if (table_name != "trade_details") {
    # For tables with primary key constraints, delete existing data
    delete_sql <- glue(
      "DELETE FROM {table_name} WHERE reference_date = '{config$ref_date}'"
    )
    dbExecute(con, delete_sql)
    message(glue("Cleared existing data for {config$ref_date}"))
  }
  
  # Load data into database
  tryCatch({
    dbWriteTable(con, table_name, dt, append = TRUE, row.names = FALSE)
    message(glue("Successfully loaded {nrow(dt)} rows into {table_name}"))
    return(TRUE)
  }, error = function(e) {
    message(glue("Error loading data into {table_name}: {e$message}"))
    return(FALSE)
  })
}

# Function to verify data loading
verify_data_loaded <- function(con, table_name) {
  message(glue("Verifying data in {table_name}..."))
  
  # Count rows for the reference date
  count_sql <- glue(
    "SELECT COUNT(*) as row_count FROM {table_name} WHERE reference_date = '{config$ref_date}'"
  )
  result <- dbGetQuery(con, count_sql)
  
  message(glue("Rows in {table_name} for {config$ref_date}: {result$row_count[1]}"))
  
  # Show sample data
  sample_sql <- glue(
    "SELECT * FROM {table_name} WHERE reference_date = '{config$ref_date}' LIMIT 3"
  )
  sample_data <- dbGetQuery(con, sample_sql)
  
  if (nrow(sample_data) > 0) {
    message("Sample data:")
    print(sample_data)
  }
}

# Function to create summary views
create_summary_views <- function(con) {
  message("Creating summary views...")
  
  # View for scenario performance summary
  view1_sql <- "
    CREATE OR REPLACE VIEW scenario_performance_summary AS
    SELECT 
      scenario,
      reference_date,
      COUNT(*) as total_companies,
      SUM(total_trades) as total_trades,
      AVG(win_rate) as avg_win_rate,
      AVG(avg_pnl) as avg_pnl,
      AVG(profit_factor) as avg_profit_factor,
      AVG(sharpe_ratio) as avg_sharpe_ratio,
      AVG(max_drawdown) as avg_max_drawdown
    FROM performance_metrics
    GROUP BY scenario, reference_date
    ORDER BY avg_pnl DESC;
  "
  dbExecute(con, view1_sql)
  message("Created scenario_performance_summary view")
  
  # View for trade statistics
  view2_sql <- "
    CREATE OR REPLACE VIEW trade_statistics_summary AS
    SELECT 
      scenario,
      reference_date,
      COUNT(*) as total_trades,
      AVG(pnl_percent) as avg_pnl_percent,
      AVG(days_held) as avg_days_held,
      COUNT(CASE WHEN pnl_percent > 0 THEN 1 END) as winning_trades,
      COUNT(CASE WHEN pnl_percent <= 0 THEN 1 END) as losing_trades,
      ROUND(COUNT(CASE WHEN pnl_percent > 0 THEN 1 END) * 100.0 / COUNT(*), 2) as win_rate
    FROM trade_details
    GROUP BY scenario, reference_date
    ORDER BY avg_pnl_percent DESC;
  "
  dbExecute(con, view2_sql)
  message("Created trade_statistics_summary view")
}

# Main function
main <- function() {
  message("Starting table creation and data loading...")
  
  # Check if consolidated files exist
  files_to_load <- list(
    performance_metrics = file.path(config$consolidated_dir, glue("consolidated_performance_metrics_{config$ref_date}.csv")),
    trade_details = file.path(config$consolidated_dir, glue("consolidated_trade_details_{config$ref_date}.csv")),
    atr_volatility = file.path(config$consolidated_dir, glue("consolidated_atr_volatility_{config$ref_date}.csv"))
  )
  
  # Verify files exist
  for (table_name in names(files_to_load)) {
    if (!file.exists(files_to_load[[table_name]])) {
      stop(glue("File not found: {files_to_load[[table_name]]}"))
    }
  }
  
  # Connect to database
  con <- connect_to_db()
  
  # Create tables
  create_tables(con)
  
  # Load data
  for (table_name in names(files_to_load)) {
    success <- load_csv_to_table(con, files_to_load[[table_name]], table_name)
    if (success) {
      verify_data_loaded(con, table_name)
    }
  }
  
  # Create summary views
  create_summary_views(con)
  
  # Close connection
  dbDisconnect(con)
  
  message("\n=== Process Complete ===")
  message("Tables created and data loaded successfully!")
  message("Summary views created for quick analysis.")
}

# Run the script
if (!interactive()) {
  main()
}
