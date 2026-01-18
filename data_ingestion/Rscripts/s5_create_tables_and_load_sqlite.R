#!/usr/bin/env Rscript

# s5_create_tables_and_load_sqlite.R
# Script to create SQLite database tables and load consolidated CSV data
# Created: 2025-12-30

# Load required packages
suppressPackageStartupMessages({
  library(data.table)
  library(stringr)
  library(glue)
  library(assertthat)
  library(DBI)
  library(RSQLite)
})

# Configuration
config <- list(
  # SQLite database file
  db_file = "/Users/chanderbhushan/stockmkt/output/mmtm/stockmarket.db",
  # File paths
  consolidated_dir = "/Users/chanderbhushan/stockmkt/output/mmtm/consolidated",
  ref_date = "2025-12-29"
)

# Table creation SQL statements
create_table_sql <- list(
  performance_metrics = "
    CREATE TABLE IF NOT EXISTS performance_metrics (
      scenario TEXT NOT NULL,
      reference_date TEXT NOT NULL,
      company_id INTEGER NOT NULL,
      company_name TEXT,
      total_trades INTEGER,
      winning_trades INTEGER,
      losing_trades INTEGER,
      open_trades INTEGER,
      win_rate REAL,
      avg_pnl REAL,
      avg_win REAL,
      avg_loss REAL,
      win_loss_ratio REAL,
      profit_factor REAL,
      max_drawdown REAL,
      recovery_factor REAL,
      sharpe_ratio REAL,
      sortino_ratio REAL,
      best_trade REAL,
      worst_trade REAL,
      avg_days_held REAL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (scenario, company_id, reference_date)
    );
  ",
  
  trade_details = "
    CREATE TABLE IF NOT EXISTS trade_details (
      scenario TEXT NOT NULL,
      reference_date TEXT NOT NULL,
      trade_id INTEGER PRIMARY KEY AUTOINCREMENT,
      company_id INTEGER,
      company_name TEXT,
      entry_date TEXT,
      entry_price REAL,
      exit_date TEXT,
      exit_price REAL,
      pnl_percent REAL,
      pnl_amount REAL,
      days_held INTEGER,
      exit_reason TEXT,
      max_drawdown REAL,
      max_runup REAL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_trade_details_scenario ON trade_details(scenario);
    CREATE INDEX IF NOT EXISTS idx_trade_details_company ON trade_details(company_id);
    CREATE INDEX IF NOT EXISTS idx_trade_details_dates ON trade_details(entry_date, exit_date);
  ",
  
  atr_volatility = "
    CREATE TABLE IF NOT EXISTS atr_volatility_performance (
      scenario TEXT NOT NULL,
      reference_date TEXT NOT NULL,
      company_id INTEGER NOT NULL,
      company_name TEXT,
      atr_14 REAL,
      atr_percent REAL,
      avg_true_range REAL,
      volatility_14d REAL,
      volatility_30d REAL,
      volatility_60d REAL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (scenario, company_id, reference_date)
    );
  "
)

# Function to connect to SQLite database
connect_to_db <- function() {
  message(glue("Connecting to SQLite database: {config$db_file}"))
  
  # Create database directory if it doesn't exist
  db_dir <- dirname(config$db_file)
  if (!dir.exists(db_dir)) {
    dir.create(db_dir, recursive = TRUE)
  }
  
  # Connect to database
  con <- dbConnect(RSQLite::SQLite(), config$db_file)
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
  } else {
    # For trade_details, clear all data since it doesn't have a primary key constraint
    delete_sql <- glue("DELETE FROM {table_name} WHERE reference_date = '{config$ref_date}'")
    dbExecute(con, delete_sql)
    message(glue("Cleared existing trade data for {config$ref_date}"))
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
    CREATE VIEW IF NOT EXISTS scenario_performance_summary AS
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
    CREATE VIEW IF NOT EXISTS trade_statistics_summary AS
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

# Function to run sample queries
run_sample_queries <- function(con) {
  message("\n=== Sample Queries ===")
  
  # Query 1: Top 5 scenarios by average P&L
  message("\nTop 5 scenarios by average P&L:")
  query1 <- "
    SELECT scenario, avg_pnl, avg_win_rate, total_trades
    FROM scenario_performance_summary
    ORDER BY avg_pnl DESC
    LIMIT 5;
  "
  result1 <- dbGetQuery(con, query1)
  print(result1)
  
  # Query 2: Scenario with highest win rate
  message("\nScenario with highest win rate:")
  query2 <- "
    SELECT scenario, avg_win_rate, avg_pnl, total_trades
    FROM scenario_performance_summary
    ORDER BY avg_win_rate DESC
    LIMIT 1;
  "
  result2 <- dbGetQuery(con, query2)
  print(result2)
  
  # Query 3: Total trades across all scenarios
  message("\nTotal trades across all scenarios:")
  query3 <- "
    SELECT SUM(total_trades) as grand_total_trades
    FROM scenario_performance_summary;
  "
  result3 <- dbGetQuery(con, query3)
  print(result3)
}

# Main function
main <- function() {
  message("Starting SQLite table creation and data loading...")
  
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
  
  # Run sample queries
  run_sample_queries(con)
  
  # Close connection
  dbDisconnect(con)
  
  message("\n=== Process Complete ===")
  message(glue("SQLite database created at: {config$db_file}"))
  message("Tables created and data loaded successfully!")
  message("Summary views created for quick analysis.")
}

# Run the script
if (!interactive()) {
  main()
}
