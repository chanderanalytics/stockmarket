# 8_indices_features.R

source("data_ingestion/Rscripts/0_setup_renv.R")

# Load libraries
library(DBI)
library(RPostgres)
library(data.table)
library(futile.logger)

test_n <- NA  # Set to NA to process all indices, or to a number for testing (e.g., 5)

# Set up logging
log_file <- sprintf("log/indices_features_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
flog.appender(appender.file(log_file))
flog.info("Starting indices features script")

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

# --- CONFIG ---
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("PGDATABASE"),
  host = Sys.getenv("PGHOST"),
  port = as.integer(Sys.getenv("PGPORT")),
  user = Sys.getenv("PGUSER"),
  password = Sys.getenv("PGPASSWORD")
)

indices <- as.data.table(dbReadTable(con, "indices"))
index_prices <- as.data.table(dbReadTable(con, "index_prices"))
 # No global 'today' selection; computations use each index's latest available date

# Parse required as-of date (YYYY-MM-DD) and optional test_n
args <- commandArgs(trailingOnly = TRUE)
as_of <- NA
if (length(args) >= 1 && grepl("^\\d{4}-\\d{2}-\\d{2}$", args[1])) {
  as_of <- as.Date(args[1])
  cat(sprintf("[INFO] Using as_of date: %s\n", as.character(as_of)))
}
# If second arg exists and is numeric, or if first arg is numeric with no as_of
if (length(args) >= 2 && !is.na(as.numeric(args[2]))) {
  test_n <- as.numeric(args[2])
  cat(sprintf("[INFO] Using test_n: %d\n", test_n))
} else if (is.na(as_of) && length(args) >= 1 && !is.na(as.numeric(args[1]))) {
  test_n <- as.numeric(args[1])
  cat(sprintf("[INFO] Using test_n: %d\n", test_n))
}

# Enforce as_of provided
if (is.na(as_of)) {
  flog.error("as_of date missing or invalid. Usage: Rscript 8_indices_features.R YYYY-MM-DD [optional_test_n]")
  stop("as_of date is required (YYYY-MM-DD)")
}

tryCatch({
  flog.info("Loading indices and index_prices tables from database...")
  
  # Load indices table
  indices_cols <- dbListFields(db_con, "indices")
  indices_query <- sprintf("SELECT %s FROM indices", paste(sprintf('"%s"', indices_cols), collapse = ", "))
  indices_dt <- as.data.table(dbGetQuery(db_con, indices_query))
  
  # Load index_prices table
  index_prices_dt <- as.data.table(dbGetQuery(db_con, "SELECT * FROM index_prices"))
  
  flog.info("Loaded %d indices and %d index price records", nrow(indices_dt), nrow(index_prices_dt))

  # Ensure types and normalized keys for joining
  index_prices_dt[, date := as.Date(date)]
  # Normalize join key `name` to avoid whitespace/case mismatches
  if ("name" %in% names(indices_dt)) indices_dt[, name := trimws(tolower(as.character(name)))]
  if ("name" %in% names(index_prices_dt)) index_prices_dt[, name := trimws(tolower(as.character(name)))]
  latest_date <- max(index_prices_dt$date, na.rm = TRUE)
  flog.info("Latest index price date: %s", as.character(latest_date))

  # Choose price column dynamically
  price_candidates <- c("close", "adj_close", "adjusted_close", "adjclose", "Close")
  price_col <- price_candidates[price_candidates %in% names(index_prices_dt)][1]
  if (is.na(price_col) || length(price_col) == 0) {
    stop(sprintf("No known price column found in index_prices: candidates=%s, available=%s",
                 paste(price_candidates, collapse=","), paste(names(index_prices_dt), collapse=",")))
  }

  # Define lags/periods (in trading days)
  lags <- c(1, 2, 3, 4, 5, 21, 63, 126, 252, 504, 756, 1260, 2520)  # 1d, 2d, 3d, 4d, 1w, 1m, 3m, 6m, 1y, 2y, 3y, 5y, 10y

  # Ensure ticker types are consistent if present
  if ("ticker" %in% names(index_prices_dt)) index_prices_dt[, ticker := as.character(ticker)]

  # Debug: check column names and data
  cat("Columns in indices_dt:\n")
  print(names(indices_dt))
  cat("Columns in index_prices_dt:\n")
  print(names(index_prices_dt))
  cat("Number of rows in indices_dt:", nrow(indices_dt), "\n")
  cat("Number of rows in index_prices_dt:", nrow(index_prices_dt), "\n")

  # Debug: check ID types and overlap
  cat("class(indices_dt$name):", class(indices_dt$name), "\n")
  cat("class(index_prices_dt$name):", class(index_prices_dt$name), "\n")
  cat("Number of indices in indices_dt:", length(unique(indices_dt$name)), "\n")
  cat("Number of indices in index_prices_dt:", length(unique(index_prices_dt$name)), "\n")
  cat("Number of overlapping names:", length(intersect(unique(indices_dt$name), unique(index_prices_dt$name))), "\n")

  # Find all index names by number of price records in index_prices_dt
  index_counts <- index_prices_dt[, .N, by = name][order(-N)]
  top_index_names <- index_counts[, name]  # Process all indices, not just the top N
  # Filter to only indices that have price data up to as_of
  names_with_data <- unique(index_prices_dt[date <= as_of, name])
  top_index_names <- top_index_names[top_index_names %in% names_with_data]
  if (!is.na(test_n) && !is.null(test_n)) {
    top_index_names <- top_index_names[1:min(test_n, length(top_index_names))]
  }

  flog.info("Processing %d indices with price data", length(top_index_names))

  # Main feature calculation for top_index_names
  features_list <- list()
  for (i in seq_along(top_index_names)) {
    index_name <- top_index_names[i]
    if (i %% 10 == 0) {
      flog.info("Processed %d/%d indices. Current index: %s", i, length(top_index_names), index_name)
    }
    if (length(index_name) != 1 || is.na(index_name) || index_name == "" || !(index_name %in% index_prices_dt$name)) {
      next  # Skip this index if name is missing or empty
    }
    
    dt <- index_prices_dt[name == index_name][order(date)]
    dt <- dt[date <= as_of]
    n_dt <- nrow(dt)
    # price_col determined above

    f <- list(name = index_name)
    
    # Get latest close price (use latest available date for this index, respecting as_of)
    if (!is.na(price_col) && n_dt > 0 && !is.na(dt[n_dt, get(price_col)])) {
      latest_close <- dt[n_dt, get(price_col)]
    } else {
      latest_close <- NA_real_
    }

    # Debug: print all dates and price column for a known index AFTER latest_close is computed
    if (index_name == "nifty 50") {
      cat("\nDEBUG: Nifty 50 all records (", price_col, "):\n", sep="")
      print(dt[, .(date, price = get(price_col))])
      
      # Debug: show calculation details for Nifty 50
      cat("\nDEBUG: Nifty 50 calculation details:\n")
      cat("Latest close:", latest_close, "\n")
      cat("Latest date:", dt[n_dt, date], "\n")
      # Reference date is the latest available date in this index's series
      cat("Total records:", n_dt, "\n")
      
      # Show calculation for 1d, 2d, 5d returns
      for (lag in c(1, 2, 5)) {
        if (n_dt >= lag) {
          past_close <- dt[n_dt - lag, get(price_col)]
          past_date <- dt[n_dt - lag, date]
          return_val <- 100 * (latest_close - past_close) / past_close
          cat(sprintf("%dd return: %.4f%% (from %s close: %.2f to %s close: %.2f)\n", 
                     lag, return_val, past_date, past_close, dt[n_dt, date], latest_close))
        } else {
          cat(sprintf("%dd return: NA (insufficient data)\n", lag))
        }
      }
    }
    
    f[["latest_close"]] <- latest_close
    
    for (lag in lags) {
      pchg_col <- paste0("pchg_", lag, "d")
      if (!is.na(price_col) && n_dt >= lag) {
        if (lag == 1) {
          if (!is.na(price_col) && n_dt >= 2) {
            past_close <- dt[n_dt - 1, get(price_col)]
            f[[pchg_col]] <- 100 * (latest_close - past_close) / past_close
          } else {
            f[[pchg_col]] <- NA_real_
          }
        } else {
          start_idx <- n_dt - lag + 1
          if (start_idx >= 1) {
            past_close <- dt[n_dt - lag, get(price_col)]
            f[[pchg_col]] <- 100 * (latest_close - past_close) / past_close
          } else {
            f[[pchg_col]] <- NA_real_
          }
        }
      } else {
        f[[pchg_col]] <- NA_real_
      }
    }
    features_list[[i]] <- as.data.table(f)
  }
  
  features_dt <- rbindlist(features_list, fill = TRUE)
  flog.info("Feature calculation complete for %d indices", length(features_list))

  # Replace NA/nulls in return columns only (not latest_close)
  return_cols <- grep("^pchg_", names(features_dt), value = TRUE)
  for (col in return_cols) {
    features_dt[is.na(get(col)), (col) := 9999]
  }
  flog.info("NA/nulls replaced with 9999 in return columns only")

  # Debug: check for NA values
  na_counts <- sapply(features_dt, function(x) sum(is.na(x)))
  cat("NA counts in features_dt:\n")
  print(na_counts)

  # Debug: print distinct values in pchg columns
  cat("\nDEBUG: Count of distinct values in pchg columns:\n")
  cat("Total rows in features_dt:", nrow(features_dt), "\n")
  pchg_cols <- grep("^pchg_", names(features_dt), value = TRUE)
  for (col in pchg_cols) {
    distinct_count <- length(unique(features_dt[[col]]))
    cat(sprintf("%s: %d distinct values\n", col, distinct_count))
  }
  
  # Debug: show actual distinct values for pchg_2520d
  cat("\nDEBUG: Distinct values in pchg_2520d:\n")
  print(unique(features_dt$pchg_2520d))
  
  # Debug: show actual distinct values for pchg_1d and pchg_5d
  cat("\nDEBUG: Distinct values in pchg_1d:\n")
  print(unique(features_dt$pchg_1d))
  cat("\nDEBUG: Distinct values in pchg_5d:\n")
  print(unique(features_dt$pchg_5d))

  # Build daily snapshot for indices_with_features (include ALL index_prices columns + returns)
  ref_date <- as_of
  # Latest row per index up to ref_date
  latest_rows_dt <- index_prices_dt[date <= ref_date]
  setorder(latest_rows_dt, name, date)
  latest_rows_dt <- latest_rows_dt[, .SD[.N], by = name]

  # Prepare returns from features_dt (rename pchg_* -> return_*)
  returns_dt <- copy(features_dt)
  setnames(returns_dt, old = grep("^pchg_", names(returns_dt), value = TRUE),
           new = sub("^pchg_", "return_", grep("^pchg_", names(returns_dt), value = TRUE)))
  required_returns <- c("return_1d","return_2d","return_3d","return_4d","return_5d",
                        "return_21d","return_63d","return_126d","return_252d",
                        "return_504d","return_756d","return_1260d","return_2520d")
  for (rc in required_returns) if (!rc %in% names(returns_dt)) returns_dt[, (rc) := NA_real_]
  returns_dt <- returns_dt[, c("name", required_returns), with = FALSE]

  # Drop any existing return_* columns from latest_rows_dt to avoid name collisions
  existing_ret_in_base <- grep('^return_', names(latest_rows_dt), value = TRUE)
  if (length(existing_ret_in_base) > 0) latest_rows_dt[, (existing_ret_in_base) := NULL]
  # Merge: all base columns from index_prices latest row + returns
  snapshot_full_dt <- merge(latest_rows_dt, returns_dt, by = "name", all.x = TRUE)
  snapshot_full_dt[, as_of_date := ref_date]
  # Reorder columns: id..index_prices cols..returns..as_of_date (only those that exist)
  base_cols <- names(latest_rows_dt)
  existing_returns <- intersect(required_returns, names(snapshot_full_dt))
  setcolorder(snapshot_full_dt, c(base_cols, existing_returns, "as_of_date"))

  # Create table if not exists with full schema (use legacy table name)
  dbExecute(db_con, "CREATE TABLE IF NOT EXISTS indices_with_features (\n    id bigint,\n    name text,\n    ticker text,\n    region text,\n    description text,\n    date date,\n    open numeric,\n    high numeric,\n    low numeric,\n    close numeric,\n    volume numeric,\n    last_modified timestamp,\n    return_1d numeric,\n    return_2d numeric,\n    return_3d numeric,\n    return_4d numeric,\n    return_5d numeric,\n    return_21d numeric,\n    return_63d numeric,\n    return_126d numeric,\n    return_252d numeric,\n    return_504d numeric,\n    return_756d numeric,\n    return_1260d numeric,\n    return_2520d numeric,\n    as_of_date date\n  )")

  # Ensure table contains ONLY this as_of snapshot
  dbExecute(db_con, "TRUNCATE TABLE indices_with_features")
  dbWriteTable(db_con, "indices_with_features", as.data.frame(snapshot_full_dt), append = TRUE)
  flog.info("Replaced indices_with_features with %d rows for as_of_date=%s", nrow(snapshot_full_dt), as.character(ref_date))

  # Export CSV of the snapshot
  if (!dir.exists("output")) dir.create("output")
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  output_file <- sprintf("output/indices_with_features_%s_%s.csv", format(ref_date, "%Y%m%d"), timestamp)
  fwrite(snapshot_full_dt, output_file)
  flog.info("Exported snapshot to %s", output_file)

  # Disconnect
  dbDisconnect(db_con)
  flog.info("Disconnected from database. Script complete.")

}, error = function(e) {
  flog.error("Error: %s", e$message)
  dbDisconnect(db_con)
  stop(e)
}) 

renv::snapshot() 