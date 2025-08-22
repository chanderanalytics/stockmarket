#!/usr/bin/env Rscript
# momentum_cycle_signals_v2.R
# Cleaned, runnable version of your momentum cycle pipeline.
# Dependencies: data.table, DBI, RPostgres (optional for DB write), TTR
# Usage: set PG* env vars for DB write, or let script run and only produce CSV.

source("data_ingestion/Rscripts/0_setup_renv.R")

# 1.1 Configure logging system
# ----------------------------------------------------------------------------
# Create log directory if it doesn't exist
if (!dir.exists("log")) {
 dir.create("log", recursive = TRUE)
}

# Create a timestamped log file
log_file <- file.path("log", sprintf("momentum_refined_%s.log", 
format(Sys.time(), "%Y%m%d_%H%M%S")))
file.create(log_file)

# 1.2 Logging Functions
# ----------------------------------------------------------------------------
#' Enhanced Logging Function
#' 
#' Writes log messages to both console and log file with timestamp and log level.
#' @param msg Character string containing the log message
#' @param level Character string indicating log level (INFO, WARN, ERROR, DEBUG)
#' @return None (writes to console and log file)
#' @examples
#' log_message("Starting analysis", "INFO")
log_message <- function(msg, level = "INFO") {
  # Handle vector inputs by collapsing to a single string
  if (length(msg) > 1) {
    msg <- paste(msg, collapse = " ")
  }
  
  # Skip verbose company-level logs
  if (level == "INFO" && any(grepl("company", tolower(msg)))) {
    return()
  }
  
  # Format the log message
  log_line <- sprintf("[%s] [%s] %s\n", 
                     format(Sys.time(), "%Y-%m-%d %H:%M:%S"), 
                     level, 
                     msg)
  
  # Write to console
  if (level %in% c("ERROR", "WARN", "INFO")) {
    cat(log_line)
  }
  
  # Append to log file if it exists
  if (exists("log_file")) {
    cat(log_line, file = log_file, append = TRUE)
  }
  
  # Flush to ensure it's written
  flush.console()
}

# ============================================================================
# 2. UTILITY FUNCTIONS
# ============================================================================

# Function to check if a stock is close to a stage (missing only one rule)
is_close_to_stage <- function(dt, target_stage) {
 # Define the rules for each stage
 stage_rules <- list(
  # Stage 0 rules
  '0' = c('LOW_VOL', 'TIGHT_RANGE_3DAY', 'VOL_DRYUP'),
  # Stage 1 rules
  '1' = c('PRICE_BREAKOUT', 'VOL_CONFIRM', 'MOMENTUM'),
  # Stage 2 rules
  '2' = c('ABOVE_MA21', 'MA_CROSS', 'REL_STRENGTH', 'MOMENTUM'),
  # Stage 3 rules
  '3' = c('ABOVE_MA126', 'MA_STACK', 'STRONG_MOM', 'LOW_DRAWDOWN'),
  # Stage 4 rules
  '4' = c('OVEREXTENDED', 'DIVERGENCE', 'CLIMAX_VOL'),
  # Stage 5 rules
  '5' = c('PRICE_BELOW_MA21', 'VOLUME_DECLINE', 'MOMENTUM_DOWN')
 )
 
 # Get rules for the target stage
 rules <- stage_rules[[as.character(target_stage)]]
 if (is.null(rules) || length(rules) == 0) {
  return(rep(FALSE, nrow(dt)))
 }
 
 # Check which rules exist in the data
 existing_rules <- intersect(rules, names(dt))
 if (length(existing_rules) == 0) {
  return(rep(FALSE, nrow(dt)))
 }
 
 # Check if all or all but one rule is met
 rules_met <- rowSums(dt[, ..existing_rules] == 1, na.rm = TRUE)
 total_rules <- length(existing_rules)
 return(rules_met >= pmax(1, total_rules - 1))
}

# Function to evaluate close-to-stage conditions
evaluate_partial_signals <- function(dt) {
 # Add close-to-stage flags for each stage (0-5)
 for (s in 0:5) {
  dt[, paste0('close_to_stage_', s) := is_close_to_stage(.SD, s)]
 }
 
 # A stock can be close to any stage it's not currently in
 dt[, close_to_any_stage := {
  result <- rep(NA_integer_, .N)
  for (s in 0:5) {
   # Only mark as close to stage s if not already in stage s
   result[is.na(result) & stage_ff != s & get(paste0('close_to_stage_', s))] <- s
  }
  result
 }]
 
 # Also track which stage the stock is close to (for next stage only)
 dt[, close_to_next_stage := {
  result <- rep(FALSE, .N)
  for (s in 0:4) { # Stage 5 doesn't have a next stage
   result[stage_ff %in% s & get(paste0('close_to_stage_', s + 1)) == 1] <- TRUE
  }
  result
 }]
 
 # Clean up temporary columns
 for (s in 0:5) {
  dt[, (paste0('close_to_stage_', s)) := NULL]
 }
 
 return(dt)
}

# 2.1 Timer Function
# ----------------------------------------------------------------------------
#' Execution Timer
#' 
#' Times the execution of an expression and logs the duration.
#' @param expr Expression to evaluate
#' @param message_text Description of the operation being timed
#' @return Result of the evaluated expression
#' @examples
#' result <- timer({
#'  # Some time-consuming operation
#'  Sys.sleep(1)
#' }, "Processing data")
timer <- function(expr, message_text = "") {
 start <- Sys.time()
 log_message(paste0("START: ", message_text))
 res <- eval(expr)
 elapsed <- round(as.numeric(difftime(Sys.time(), start, units = "secs")), 2)
 log_message(paste0("COMPLETE: ", message_text, " (", elapsed, "s)"))
 res
}

# 2.2 Argument Parsing
# ----------------------------------------------------------------------------
#' Parse Command Line Arguments
#' 
#' Parses command line arguments to get reference date and other parameters.
#' @return List containing script parameters
parse_arguments <- function() {
 args <- commandArgs(trailingOnly = TRUE)
 
 # Default values
 params <- list(
  ref_date = Sys.Date(),
  output_dir = "output",
  debug_mode = FALSE
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
  params$debug_mode <- "--debug" %in% args
 }
 
 return(params)
}

# Parse command line arguments
params <- parse_arguments()
ref_date <- params$ref_date

# ============================================================================
# 3. DATA VALIDATION
# ============================================================================

#' Validate Price Data
#' 
#' Checks if the price data meets minimum requirements for analysis.
#' @param dt data.table containing price data
#' @return Logical indicating if data is valid
validate_price_data <- function(dt) {
 required_cols <- c("date", "open", "high", "low", "close", "volume", "company_id")
 
 # Check for required columns
 missing_cols <- setdiff(required_cols, names(dt))
 if (length(missing_cols) > 0) {
  log_message(sprintf("Missing required columns: %s", paste(missing_cols, collapse = ", ")), "ERROR")
  return(FALSE)
 }
 
 # Check for sufficient data points
 if (nrow(dt) < 63) {
  log_message("Insufficient data points (need at least 63 for indicators)", "WARN")
  return(FALSE)
 }
 
 return(TRUE)
}

log_message(sprintf("Reference date set to: %s", ref_date))

# --- Stage definitions with rules and optimal holding periods
stage_defs <- list(
 "0" = list(stage = 0, name = "SETUP", rules = c("LOW_VOL", "TIGHT_RANGE_3DAY", "VOL_DRYUP"), optimal_days = 8),
 "1" = list(stage = 1, name = "BREAKOUT", rules = c("PRICE_BREAKOUT", "VOL_CONFIRM", "MOMENTUM"), optimal_days = 14),
 "2" = list(stage = 2, name = "EARLY_MOM", rules = c("ABOVE_MA21", "MA_CROSS", "REL_STRENGTH", "MOMENTUM"), optimal_days = 28),
 "3" = list(stage = 3, name = "SUSTAINED", rules = c("ABOVE_MA126", "MA_STACK", "STRONG_MOM", "LOW_DRAWDOWN"), optimal_days = 42),
 "4" = list(stage = 4, name = "EXTENDED", rules = c("OVEREXTENDED", "DIVERGENCE", "CLIMAX_VOL"), optimal_days = 5),
 "5" = list(stage = 5, name = "DISTRIBUTION", rules = c("PRICE_BELOW_MA21", "VOLUME_DECLINE", "MOMENTUM_DOWN"), optimal_days = 3)
)

# ============================================================================
# 4. DATABASE FUNCTIONS
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

# --- Helper: rolling percentile (simple but correct) ------------------------
# For a numeric vector x and window n, returns percentile of current value in last n values.
roll_percentile <- function(x, n) {
 nlen <- length(x)
 out <- rep(NA_real_, nlen)
 if (nlen < n) return(out)
 for (i in seq_len(nlen)) {
  if (i >= n) {
   w <- x[(i - n + 1):i]
   if (!all(is.na(w))) out[i] <- ecdf(w)(x[i])
  }
 }
 out
}

# --- Main pipeline functions -----------------------------------------------

# ============================================================================
# 5. CORE ANALYSIS FUNCTIONS
# ============================================================================

# 5.1 Technical Indicators
# ----------------------------------------------------------------------------

#' Calculate Technical Indicators
#' 
#' Applies various technical indicators to the price data for momentum analysis.
#' @param dt data.table containing OHLCV data with columns: date, open, high, low, close, volume
#' @return data.table with added technical indicators
#' @details
#' This function calculates the following indicators:
#' - Moving Averages (21, 50, 63, 126, 252 days)
#' - RSI (14-period)
#' - ADX (14-period)
#' - Volume metrics
#' - Volatility measures
#' - Range analysis
calculate_indicators <- function(dt) {
 # 5.1.1 Input Validation
 if (!is.data.table(dt)) {
  log_message("Converting input to data.table", "DEBUG")
  dt <- as.data.table(dt)
 }
 
 # 5.1.2 Data Quality Checks
 required_cols <- c("date", "open", "high", "low", "close", "volume")
 if (!all(required_cols %in% names(dt))) {
  stop("Input data is missing required price/volume columns")
 }
 
 log_message("Starting technical indicator calculations...")
 
 # 5.1.3 Data Preparation
 # Ensure proper ordering by company and date
 data.table::setorder(dt, company_id, date)
 
 # 5.1.4 Calculate Returns
 # Calculate various return periods for momentum analysis
 
 # Debug info
 log_message(sprintf("Number of rows: %d", nrow(dt)))
 
 # Check if required columns exist
 req_cols <- c("company_id", "date", "close")
 if (!all(req_cols %in% names(dt))) {
  stop(sprintf("Missing required columns. Need: %s, Have: %s", 
        paste0(req_cols, collapse = ", "),
        paste0(names(dt), collapse = ", ")))
 }
 
 # Basic returns - calculate one at a time for better error isolation
 log_message("Starting return calculations...")
 
 # a) 1-day returns
 log_message(sprintf(" - Calculating 1-day returns for %d companies...", dt[, uniqueN(company_id)]))
 
 # Calculate 1-day returns if not already present
 if (!"return_1d" %in% names(dt)) {
  dt[, return_1d := {
   (close - shift(close, type = "lag")) / shift(close, type = "lag")
  }, by = company_id]
 }
 
 log_message("  1-day returns calculated")
 
 # b) 5-day returns
 log_message(sprintf(" - Calculating 5-day returns for %d companies...", dt[, uniqueN(company_id)]))
 dt[, return_5d := close / shift(close, 5, type = "lag") - 1, by = company_id]
 log_message("  5-day returns calculated")
 
 # c) 21-day returns
 log_message(sprintf(" - Calculating 21-day returns for %d companies...", dt[, uniqueN(company_id)]))
 dt[, return_21d := close / shift(close, 21, type = "lag") - 1, by = company_id]
 log_message("  21-day returns calculated")
 
 # d) 63-day returns
 log_message(sprintf(" - Calculating 63-day returns for %d companies...", dt[, uniqueN(company_id)]))
 dt[, return_63d := close / shift(close, 63, type = "lag") - 1, by = company_id]
 log_message("  63-day returns calculated")
 
 # e) Moving averages (consistent names)
 log_message("Calculating moving averages...")
 dt[, `:=`(
  ma_5  = frollmean(close, 5,  align = "right"),
  ma_21 = frollmean(close, 21, align = "right"),
  ma_50 = frollmean(close, 50, align = "right"),
  ma_63 = frollmean(close, 63, align = "right"),
  ma_126 = frollmean(close, 126, align = "right"),
  ma_252 = frollmean(close, 252, align = "right")
 ), by = company_id]
 
 # f) True Range (TR) calculation
 dt[, `:=`(
  tr = pmax(high - low, 
       abs(high - shift(close, 1, type = "lag")), 
       abs(low - shift(close, 1, type = "lag")), 
       na.rm = TRUE)
 ), by = company_id]
 
 # g) 14-day ATR calculation with error handling
 dt[, atr := {
  tryCatch({
   frollmean(tr, 14, align = "right", fill = NA, na.rm = TRUE)
  }, error = function(e) {
   log_message(paste0("Error calculating ATR: ", e$message))
   rep(NA_real_, .N)
  })
 }, by = company_id]
 log_message("  Moving averages calculated")
 
 # h) High/Low windows and swings
 log_message("Calculating high/low windows...")
 dt[, `:=`(
  high_21d = frollapply(high, 21, max, align = "right", fill = NA),
  low_21d = frollapply(low, 21, min, align = "right", fill = NA),
  high_5d = frollapply(high, 5, max, align = "right", fill = NA),
  low_5d  = frollapply(low, 5, min, align = "right", fill = NA)
 ), by = company_id]
 log_message("  High/Low windows calculated")
 
 # i) Volume rolling averages
 log_message("Calculating volume metrics...")
 dt[, `:=`(
  vol_8d_avg = frollmean(volume, 8, align = "right"),
  vol_21d_avg = frollmean(volume, 21, align = "right"),
  vol_63d_avg = frollmean(volume, 63, align = "right"),
  volume_ratio = frollmean(volume, 8, align = "right") / (frollmean(volume, 21, align = "right") + 1e-9)
 ), by = company_id]
 log_message("  Volume metrics calculated")
 
 # j) RSI (14-day) calculation
 log_message("Calculating RSI...")
 dt[, rsi := {
  if (.N >= 15) { # Need at least 15 data points for 14-day RSI
   tryCatch({
    TTR::RSI(close, n = 14)
   }, error = function(e) {
    log_message(paste0("Error calculating RSI for company ", first(company_id), ": ", e$message))
    rep(NA_real_, .N)
   })
  } else {
   rep(NA_real_, .N)
  }
 }, by = company_id]
 log_message("  RSI calculated")
 
 # k) ADX (14-day) calculation - simplified version
 log_message("Calculating ADX...")
 dt[, adx := {
  # Initialize result with NAs
  result <- rep(NA_real_, .N)
  
  # Only proceed if we have enough data
  if (.N >= 28) {
   # Calculate ADX directly, letting TTR handle the windowing
   tryCatch({
    adx_result <- TTR::ADX(cbind(high, low, close), n = 14)
    
    # If we got a result, extract the ADX column (case-insensitive match)
    if (!is.null(adx_result) && nrow(adx_result) > 0) {
     adx_col <- grep("^ADX", colnames(adx_result), value = TRUE, ignore.case = TRUE)[1]
     if (!is.na(adx_col) && adx_col %in% colnames(adx_result)) {
      # Copy the ADX values to our result, preserving NAs at the start
      start_idx <- .N - nrow(adx_result) + 1
      if (start_idx > 0) {
       result[start_idx:.N] <- adx_result[[adx_col]]
      }
     }
    }
   }, error = function(e) {
    # Suppress error messages for now to avoid log spam
    NULL
   })
  }
  
  result
 }, by = company_id]
 log_message("  ADX calculated")
 
 # l) Range metrics calculation
 log_message("Calculating range metrics...")
 dt[, `:=`(
  range_5d = high_5d - low_5d,
  range_21d = high_21d - low_21d
 )]
 
 # m) Range contraction (5-day range as % of 21-day range)
 dt[, range_contraction := {
  # Avoid division by zero or very small numbers
  safe_denominator <- pmax(range_21d, 1e-9)
  range_5d / safe_denominator
 }]
 
 # n) Volume metrics calculation
 log_message("Calculating volume metrics...")
 dt[, `:=`(
  vol_21d = frollmean(volume, 21, align = "right"),
  vol_63d_avg = frollmean(volume, 63, align = "right"),
  volume_ratio = frollmean(volume, 8, align = "right") / 
         (frollmean(volume, 21, align = "right") + 1e-9)
 ), by = company_id]
 
 # o) Volume delta (buying vs selling pressure)
 dt[, `:=`(
  buy_volume = ifelse(close > open, volume, 0),
  sell_volume = ifelse(close < open, volume, 0)
 )]
 
 dt[, volume_delta := {
  buy_vol = frollmean(buy_volume, 5, align = "right")
  sell_vol = frollmean(sell_volume, 5, align = "right")
  (buy_vol - sell_vol) / (buy_vol + sell_vol + 1e-9)
 }, by = company_id]
 
 # p) Accumulation day (high volume up day)
 dt[, accumulation_day := {
  vol_above_avg = volume > (frollmean(volume, 21, align = "right") * 1.5)
  price_up = close > open
  vol_above_avg & price_up
 }]
 
 # q) Buying pressure (percent of up volume)
 dt[, buying_pressure := {
  up_vol = frollsum(ifelse(close > open, volume, 0), 21, align = "right")
  total_vol = frollsum(volume, 21, align = "right")
  up_vol / (total_vol + 1e-9)
 }, by = company_id]
 
 # r) Absorption (large volume without price movement)
 dt[, absorption := {
  price_range = (high - low) / (shift(close, 1, type = "lag") + 1e-9)
  vol_ratio = volume / (frollmean(volume, 21, align = "right") + 1e-9)
  (vol_ratio > 1.5) & (price_range < 0.02)
 }]
 
 # s) Smart money score calculation (simplified)
 dt[, smart_money_score := {
  score <- 50 # Base score
  
  # Add points for accumulation patterns
  if (any(accumulation_day, na.rm = TRUE)) {
   score <- score + 10
  }
  
  # Add points for buying pressure
  if (any(buying_pressure > 0.6, na.rm = TRUE)) {
   score <- score + 10
  }
  
  # Add points for absorption
  if (any(absorption, na.rm = TRUE)) {
   score <- score + 10
  }
  
  # Cap score at 100
  pmin(score, 100)
 }, by = company_id]
 
 log_message("  Volume metrics calculated")
 
 # t) Volatility metrics calculation
 log_message("Calculating volatility metrics...")
 
 # Calculate 5-day volatility
 dt[, vol_5d := {
  if (.N >= 5) {
   mean5 <- frollmean(return_1d, 5, align = "right")
   mean_sq5 <- frollmean(return_1d^2, 5, align = "right")
   sqrt(pmax(mean_sq5 - mean5^2, 0, na.rm = TRUE)) * sqrt(252)
  } else {
   NA_real_
  }
 }, by = company_id]
 
 # Calculate 21-day volatility
 dt[, vol_21d := {
  if (.N >= 21) {
   mean21 <- frollmean(return_1d, 21, align = "right")
   mean_sq21 <- frollmean(return_1d^2, 21, align = "right")
   sqrt(pmax(mean_sq21 - mean21^2, 0, na.rm = TRUE)) * sqrt(252)
  } else {
   NA_real_
  }
 }, by = company_id]
 log_message("  Volatility metrics calculated")
 
 # Tight range & range contraction - Already optimized
 log_message("Calculating range metrics...")
 dt[, is_tight_range := {
  range_5d <- high_5d - low_5d
  range_contraction <- fifelse(!is.na(range_5d) & !is.na(ma_21) & ma_21 > 0, 
               range_5d / ma_21, NA_real_)
  !is.na(range_contraction) & range_contraction < 0.05
 }]
 log_message("  Range metrics calculated")
 # consecutive tight days
 dt[, tight_range_count := {
  r <- rle(is_tight_range)
  if (length(r$lengths) == 0) return(integer(0))
  rep(seq_along(r$lengths), r$lengths) * r$values # careful transform
 }, by = company_id]
 # simpler approach
 dt[, tight_range_count := {
  # Vectorized approach using rleid and sequence
  r <- rle(is_tight_range & !is.na(is_tight_range))
  if (length(r$lengths) == 0) return(integer(0))
  
  # Create sequence numbers for each run of TRUE values
  seqs <- sequence(r$lengths)
  # Multiply by the values to zero out the FALSE runs
  seqs * rep(r$values, r$lengths)
 }, by = company_id]
 
 # 3-day tight range condition
 log_message("Calculating 3-day tight range...")
 dt[, is_3day_tight := {
  if (.N >= 3) {
   # Look for at least 3 consecutive days of tight range
   frollsum(is_tight_range, 3, align = "right") >= 3
  } else {
   FALSE
  }
 }, by = company_id]
 log_message("  3-day tight range calculated")

 # Overextension from moving average
 log_message("Calculating price overextension...")
 dt[, overextension := (close / ma_21 - 1)]
 log_message("  Price overextension calculated")
 
 # Drawdown from recent high (63-day lookback)
 log_message("Calculating drawdown metrics...")
 
 # Debug: Check data availability
 log_message(sprintf(" Total companies: %d", length(unique(dt$company_id))))
 
 # Calculate drawdown with robust NA handling
 log_message("Calculating 63-day drawdown...")
 dt[, drawdown := {
  # Initialize with NAs
  result <- rep(NA_real_, .N)
  
  # Only process if we have enough data (at least 5 days)
  if (.N >= 5) {
   # Get valid close prices and their indices
   valid_close <- !is.na(close) & close > 0
   valid_prices <- close[valid_close]
   valid_indices <- which(valid_close)
   
   # Define window size (63 days or available data)
   window_size <- min(63, length(valid_prices))
   
   if (length(valid_prices) >= window_size) {
    # Calculate drawdown for each window
    dd_values <- sapply(1:(length(valid_prices) - window_size + 1), function(i) {
     window_prices <- valid_prices[i:(i + window_size - 1)]
     if (any(is.na(window_prices)) || length(window_prices) < 2) return(NA_real_)
     
     # Calculate returns
     returns <- diff(window_prices) / window_prices[-length(window_prices)]
     if (any(is.na(returns)) || length(returns) == 0) return(NA_real_)
     
     # Calculate cumulative returns
     cum_returns <- cumprod(1 + returns)
     
     # Calculate max drawdown in this window
     max_dd <- min(cum_returns / cummax(cum_returns) - 1, na.rm = TRUE)
     
     # Ensure finite value
     if (is.finite(max_dd)) max_dd else NA_real_
    })
    
    # Map back to original indices with NAs for the initial window
    if (length(dd_values) > 0) {
     start_idx <- valid_indices[1] + window_size - 1
     end_idx <- valid_indices[length(valid_indices)]
     result[start_idx:end_idx] <- dd_values[1:min(length(dd_values), length(start_idx:end_idx))]
    }
   }
  }
  
  result
 }, by = company_id]
 
 log_message(sprintf(" Drawdown calculation complete. Total NA values: %.1f%%", 
          mean(is.na(dt$drawdown)) * 100))
 
 log_message(sprintf(" Drawdown calculation complete. Total NA values: %.1f%%", 
          mean(is.na(dt$drawdown)) * 100))
 
 # Volume momentum - Optimized
 log_message("Calculating volume momentum...")
 dt[, vol_momentum := {
  if (.N >= 5) {
   # Vectorized linear regression slope calculation
   x <- 1:5
   x_bar <- mean(x)
   y_bar <- frollmean(volume, 5, align = "right")
   xy_bar <- frollmean(volume * x, 5, align = "right")
   x_sq_bar <- mean(x^2)
   momentum <- (xy_bar - x_bar * y_bar) / (x_sq_bar - x_bar^2 + 1e-9)
   # Clean up any non-finite values
   ifelse(is.finite(momentum), momentum, NA_real_)
  } else {
   NA_real_
  }
 }, by = company_id]
 log_message("  Volume momentum calculated")
 # Optimized buying pressure and volume metrics
 # Accumulation day
 dt[, accumulation_day := (close > open) & (close > (high + low) / 2) & (volume > 1.5 * vol_21d_avg) & (close > ma_50)]
 
 # Buying pressure (5-day price change %)
 dt[, buying_pressure := {
  if (.N >= 5) {
   (close / shift(close, 4, type = "lag") - 1) * 100
  } else {
   NA_real_
  }
 }, by = company_id]
 
 # Absorption
 dt[, absorption := (abs(close - open) / (pmax(high - low, 1e-9)) < 0.3) & (volume > 1.5 * vol_21d_avg)]
 
 # Volume delta calculation
 dt[, buy_vol := volume * (close > open) + volume * 0.5 * (close == open)]
 dt[, sell_vol := volume * (close < open) + volume * 0.5 * (close == open)]
 
 dt[, volume_delta := {
  if (.N >= 5) {
   buy_sum <- frollsum(buy_vol, 5, align = "right")
   sell_sum <- frollsum(sell_vol, 5, align = "right")
   vol_sum <- frollsum(volume, 5, align = "right")
   (buy_sum - sell_sum) / (vol_sum + 1e-9)
  } else {
   NA_real_
  }
 }, by = company_id]
 
 # u) Block trades detection
 log_message("Calculating block trades...")
 dt[, block_trade := volume > 5 * frollmean(volume, 63, align = "right"), by = company_id]
 log_message("  Block trades calculated")
 
 # v) Institutional support (temporarily disabled)
 log_message("Skipping institutional support calculation (temporarily disabled)")
 
 # w) Progress tracking setup
 all_companies <- unique(dt$company_id)
 total_companies <- length(all_companies)
 log_message(sprintf(" - Setting institutional support to FALSE for %d companies...", total_companies))
 
 # x) Company processing progress
 log_message(" - Setting institutional_support to FALSE for all companies...")
 
 # Initialize institutional_support column with FALSE for all rows
 dt[, institutional_support := FALSE]
 
 # Log progress for each company (every 100 companies)
 for (i in seq_along(all_companies)) {
  if (i %% 100 == 0 || i == 1 || i == total_companies) {
   log_message(sprintf("  Processed %d/%d companies (ID: %s)", 
            i, total_companies, all_companies[i]))
  }
 }
 
 log_message("  Institutional support set to FALSE for all companies")
 
 # y) Institutional support calculation (commented out for now)
 # log_message("Calculating institutional support levels...")
 # start_time <- Sys.time()
 # 
 #  # y.1) Get total companies for progress tracking
 # all_companies <- unique(dt$company_id)
 # total_companies <- length(all_companies)
 # log_message(sprintf(" - Processing %d companies...", total_companies))
 # 
 #  # y.2) Pre-compute rounded prices
 # dt[, vol_price := round(close * 2) / 2]
 # 
 # # Process with progress logging
 # dt[, {
 #  # Log progress every 100 companies
 #  # y.3.1) Log progress
 #  current_company <- .BY[[1]]
 #  company_idx <- which(all_companies == current_company)[1]
 #  
 #  if (company_idx %% 100 == 0) {
 #   log_message(sprintf("  Processing company %d/%d (ID: %s)", 
 #            company_idx, total_companies, current_company))
 #  }
 #  
 #  if (.N >= 6) {
 #   unique_dates <- unique(date)
 #   support_lookup <- setNames(
 #    lapply(unique_dates, function(d) {
 #     window_data <- .SD[between(date, d - 63, d)]
 #     if (nrow(window_data) >= 5) {
 #      vol_dist <- window_data[, .(total_v = sum(volume, na.rm = TRUE)), by = vol_price]
 #      if (nrow(vol_dist) > 0) {
 #       setorderv(vol_dist, "total_v", order = -1L)
 #       top_prices <- vol_dist[1:min(3, .N), vol_price]
 #       current_close <- window_data[.N, close]
 #       any(abs(current_close - top_prices) / current_close < 0.01, na.rm = TRUE)
 #      } else FALSE
 #     } else FALSE
 #    }),
 #    as.character(unique_dates)
 #   )
 #   unlist(support_lookup[as.character(date)])
 #  } else rep(FALSE, .N)
 # }, by = company_id]
 # 
 # # Clean up
 # dt[, vol_price := NULL]
 # log_message(sprintf("  Institutional support calculated in %.1f seconds", 
 #          as.numeric(difftime(Sys.time(), start_time, units = "secs"))))
 # dt[, institutional_support := as.logical(institutional_support)]
 
 # Risk metrics - optimized calculation
 log_message("Calculating risk metrics...")
 
 # Calculate all risk metrics in a single pass with improved error handling
 log_message(" - Calculating rolling statistics with enhanced stability...")
 
 # Initialize columns with NA and set appropriate types
 dt[, `:=`(
   var_1d = NA_real_,
   max_drawdown_252d = NA_real_,
   sharpe_ratio = NA_real_,
   var_calc_status = NA_character_  # Track calculation status
 )]
 
 # Check for required columns
 required_cols <- c("company_id", "return_1d", "close")
 missing_cols <- setdiff(required_cols, names(dt))
 
 if (length(missing_cols) > 0) {
  log_message(sprintf("Warning: Missing required columns for risk metrics: %s", 
                     paste(missing_cols, collapse = ", ")), "WARN")
  # Initialize missing columns with NA if they don't exist
  for (col in missing_cols) {
   dt[, (col) := NA_real_]
  }
 }
 
 # Calculate for companies with enough data points (minimum 21 days)
 valid_companies <- dt[, {
   valid_days <- sum(!is.na(return_1d) & is.finite(return_1d))
   list(valid = valid_days >= 21, count = .N, valid_days = valid_days)
 }, by = company_id][valid == TRUE, company_id]
 
 if (length(valid_companies) > 0) {
  log_message(sprintf(" - Processing risk metrics for %d companies with sufficient data", length(valid_companies)))
  
  # Process in chunks to avoid memory issues
  chunk_size <- 200  # Reduced chunk size for better memory management
  num_chunks <- ceiling(length(valid_companies) / chunk_size)
  
  for (i in 1:num_chunks) {
   start_idx <- (i - 1) * chunk_size + 1
   end_idx <- min(i * chunk_size, length(valid_companies))
   current_companies <- valid_companies[start_idx:end_idx]
   
   dt[company_id %in% current_companies, {
     # Initialize result vectors
     var_1d_val <- rep(NA_real_, .N)
     sharpe_val <- rep(NA_real_, .N)
     max_dd <- rep(NA_real_, .N)
     status <- "insufficient_data"
     
     tryCatch({
       # Only proceed if we have enough valid returns
       valid_returns <- !is.na(return_1d) & is.finite(return_1d)
       if (sum(valid_returns) >= 21) {
         # 21-day rolling window for VaR and Sharpe with improved stability
         roll_mean <- frollmean(return_1d, 21, align = "right", na.rm = TRUE)
         roll_mean_sq <- frollmean(return_1d^2, 21, align = "right", na.rm = TRUE)
         
         # Calculate variance with numerical stability
         variance <- pmax(0, roll_mean_sq - roll_mean^2)
         roll_sd <- sqrt(variance)
         
         # Value at Risk (5% quantile) with bounds checking
         var_1d_val <- roll_mean + qnorm(0.05) * roll_sd
         
         # Sharpe Ratio (annualized) with protection against division by zero
         sharpe_val <- ifelse(roll_sd > 1e-9, 
                              roll_mean / roll_sd * sqrt(252), 
                              sign(roll_mean) * Inf)
         
         # Cap extreme values
         sharpe_val <- pmin(pmax(sharpe_val, -10), 10)
         
         # Calculate max drawdown with minimum 21 trading days
         if (.N >= 21) {
           # Calculate running maximum over 252-day window (or available data)
           roll_max <- frollapply(close, min(.N, 252), max, align = "right", na.rm = TRUE)
           
           # Calculate drawdown from peak with protection against zero/negative prices
           valid_prices <- !is.na(close) & close > 0 & !is.na(roll_max) & roll_max > 0
           drawdown <- rep(NA_real_, .N)
           drawdown[valid_prices] <- (close[valid_prices] - roll_max[valid_prices]) / roll_max[valid_prices]
           
           # Get minimum drawdown in the window (max drawdown)
           max_dd <- frollapply(drawdown, min(.N, 252), min, align = "right", na.rm = FALSE)
           
           # Ensure we have at least 21 non-NA values
           if (sum(!is.na(max_dd)) < 21) {
             max_dd <- rep(NA_real_, .N)
           }
         }
         
         # Ensure values are within expected ranges
         max_dd <- pmin(pmax(max_dd, -1), 0, na.rm = FALSE)
         status <- "success"
       }
     }, error = function(e) {
       log_message(sprintf("Error calculating risk metrics for company %s: %s", 
                          .BY$company_id, e$message), "ERROR")
       status <<- paste0("error: ", conditionMessage(e))
     })
     
     # Return results
     .(
       var_1d = var_1d_val,
       max_drawdown_252d = max_dd,
       sharpe_ratio = sharpe_val,
       var_calc_status = status
     )
   }, by = company_id]
   
   # Log progress
   if (i %% 5 == 0 || i == num_chunks) {
     # Calculate success rate for this chunk
     chunk_stats <- dt[company_id %in% current_companies, 
                      .(success = sum(var_calc_status == "success", na.rm = TRUE),
                        total = .N), 
                      by = company_id]
     
     log_message(sprintf("  Processed chunk %d/%d - Success: %d/%d (%.1f%%)", 
                        i, num_chunks,
                        sum(chunk_stats$success), 
                        sum(chunk_stats$total),
                        sum(chunk_stats$success) / sum(chunk_stats$total) * 100))
   }
  }
 } else {
  log_message(" - No companies have sufficient data for risk metrics calculation")
 }
 
 log_message("  Risk metrics calculated")
 
 # Position sizing - optimized Kelly fraction
 log_message("Calculating position sizing...")
 
 # Function to calculate Kelly fraction for a single company
 calculate_kelly <- function(rr) {
  # Only calculate if we have enough data
  if (length(rr) >= 21) {
   # Vectorized win/loss calculations
   wins <- sum(rr > 0, na.rm = TRUE)
   total <- sum(!is.na(rr))
   
   if (wins > 0 && total >= 21) {
    win_rate <- wins / total
    
    # Calculate average win/loss
    win_mask <- rr > 0 & !is.na(rr)
    loss_mask <- rr < 0 & !is.na(rr)
    
    if (sum(win_mask) > 0 && sum(loss_mask) > 0) {
     avg_win <- mean(rr[win_mask])
     avg_loss <- -mean(rr[loss_mask])
     
     # Calculate Kelly fraction with bounds checking
     if (avg_loss > 0) {
      win_ratio <- avg_win / avg_loss
      kelly <- ((win_rate * (win_ratio + 1)) - 1) / win_ratio
      # Cap Kelly at 1.0 and floor at 0.0
      return(pmax(0, pmin(1, kelly)))
     }
    }
   }
  }
  return(NA_real_)
 }
 
 # s) Kelly fraction calculation
 dt[, kelly_fraction := {
  rr <- return_1d
  kf <- calculate_kelly(rr)
  rep(ifelse(is.na(kf), 0.1, kf), .N) # Default to 10% if calculation failed
 }, by = company_id]
 
 # t) Clean up any remaining NAs (default to 10% if calculation failed)
 dt[is.na(kelly_fraction), kelly_fraction := 0.1] # Default to 10% if calculation failed
 
 # u) Update risk score to use existing metrics
 log_message("Updating risk score with existing metrics...")
 
 # v) Smart money score calculation
 log_message("Calculating smart money score...")
 
 # w) Calculate composite risk score (0-100, higher = lower risk)
 log_message("Calculating composite risk score...")
 
 # First, check if required columns exist and have data
 required_cols <- c("vol_21d", "max_drawdown_252d", "var_1d", "sharpe_ratio", "volume", "close")
 missing_cols <- setdiff(required_cols, names(dt))
 
 if (length(missing_cols) > 0) {
  log_message(sprintf("Warning: Missing required columns for risk score: %s", 
           paste(missing_cols, collapse = ", ")), "WARNING")
 }
 
 # Function to safely calculate ECDF with NA handling
 safe_ecdf <- function(x) {
  if (all(is.na(x))) return(rep(NA_real_, length(x)))
  x_ecdf <- ecdf(na.omit(x))
  result <- rep(NA_real_, length(x))
  result[!is.na(x)] <- x_ecdf(x[!is.na(x)])
  return(result * 100) # Convert to 0-100 scale
 }
 
 dt[, risk_score := {
   # Debug: Count non-NA values for each component
   non_na_counts <- c(
    vol_21d = sum(!is.na(vol_21d)),
    max_drawdown = sum(!is.na(max_drawdown_252d)),
    var_1d = sum(!is.na(var_1d)),
    sharpe = sum(!is.na(sharpe_ratio)),
    volume = sum(!is.na(volume)),
    close = sum(!is.na(close))
   )
   
   if (any(non_na_counts == 0)) {
    log_message(sprintf(" Company %s: Missing data - %s", 
             first(company_id),
             paste(names(non_na_counts)[non_na_counts == 0], collapse = ", ")), 
         "DEBUG")
   }
   
   # 1. Calculate component scores (0-100 scale, higher = riskier)
   vol_risk <- safe_ecdf(vol_21d)  # Higher vol = higher risk
   
   # Handle max drawdown risk
   dd_risk <- if (all(is.na(max_drawdown_252d))) {
    rep(NA_real_, .N)
   } else {
    safe_ecdf(abs(max_drawdown_252d))  # Higher drawdown = higher risk
   }
   
   # Value at Risk
   var_risk <- safe_ecdf(abs(var_1d))  # Higher VaR = higher risk
   
   # Risk-Adjusted Return (Sharpe Ratio)
   sharpe_risk <- if (all(is.na(sharpe_ratio))) {
    rep(NA_real_, .N)
   } else {
    100 - safe_ecdf(sharpe_ratio)  # Higher Sharpe = lower risk
   }
   
   # Volume Stability (CV of 21-day volume)
   vol_sd <- frollapply(volume, 21, sd, na.rm = TRUE, align = "right")
   vol_mean <- frollmean(volume, 21, na.rm = TRUE, align = "right")
   vol_cv <- ifelse(vol_mean > 0, vol_sd / vol_mean * 100, 0)
   volume_stability <- safe_ecdf(vol_cv)  # Higher CV = higher risk
   
   # Price Stability (CV of 21-day close prices)
   price_sd <- frollapply(close, 21, sd, na.rm = TRUE, align = "right")
   price_mean <- frollmean(close, 21, na.rm = TRUE, align = "right")
   price_cv <- ifelse(price_mean > 0, price_sd / price_mean * 100, 0)
   price_stability <- safe_ecdf(price_cv)  # Higher CV = higher risk
   
   # 2. Define component weights
   weights <- c(
    vol_risk = 0.20,          # 20%
    dd_risk = 0.20,           # 20%
    var_risk = 0.20,          # 20%
    sharpe_risk = 0.15,       # 15%
    volume_stability = 0.15,  # 15%
    price_stability = 0.10    # 10%
   )
   
   # 3. Create component matrix
   component_values <- data.table(
    vol_risk,
    dd_risk,
    var_risk,
    sharpe_risk,
    volume_stability,
    price_stability
   )
   
   # 4. Calculate weighted score with proper NA handling
   # Initialize with NA
   risk_score <- rep(NA_real_, .N)
   
   # For each row, calculate weighted average of available components
   for (i in 1:.N) {
    row_components <- as.numeric(component_values[i])
    row_weights <- weights[!is.na(row_components)]
    row_values <- row_components[!is.na(row_components)]
    
    if (length(row_values) > 0) {
     # Calculate weighted average, normalizing by sum of available weights
     risk_score[i] <- sum(row_values * row_weights) / sum(row_weights) * 100
    }
   }
   
   # 5. Ensure score is within 0-100 range and round
   risk_score <- pmin(pmax(risk_score, 0), 100)
   round(risk_score, 1)
  }, by = .(company_id)]
 
 # w) Risk Categories
 dt[, risk_category := cut(risk_score,
             breaks = c(0, 20, 40, 60, 80, 100),
             labels = c("Very High", "High", "Medium", "Low", "Very Low"),
             include.lowest = TRUE)]
 
 log_message("Risk score calculation completed")
 dt[, smart_money_score := pmin(100, 50 + 10 * as.integer(accumulation_day) +
                5 * as.integer(absorption) + 5 * pmin(1, buying_pressure / 2)), by = company_id]
 
 # v) Clean up temporary columns
 log_message("Cleaning up temporary columns...")
 dt[, c("vol_price", "buy_volume", "sell_volume", "running_max") := NULL]
 
 log_message(" Indicator calculations complete")
 return(dt)
}

# 5.2 Rule Evaluation
# ----------------------------------------------------------------------------

#' Evaluate Trading Rules
#' 
#' Applies trading rules to identify potential entry and exit points.
#' @param dt data.table with price and indicator data
#' @return data.table with rule evaluation results
#' @details
#' Implements a multi-stage rule system:
#' - Stage 0: Low volatility and tight range conditions
#' - Stage 1: Initial breakout conditions
#' - Stage 2: Trend confirmation
#' - Stage 3: Strong trend conditions
#' - Stage 4: Overextension and divergence
evaluate_rules <- function(dt) {
 log_message("Evaluating trading rules...")
 
 # 5.2.1 Stage 0: Low Volatility & Tight Range
 # Conditions indicating potential upcoming moves
 dt[, `:=`(
  LOW_VOL = as.integer(vol_21d < quantile(vol_21d, 0.2, na.rm = TRUE)),
  TIGHT_RANGE_1DAY = as.integer(is_tight_range),
  TIGHT_RANGE_3DAY = as.integer(is_3day_tight),
  VOL_DRYUP = as.integer((volume_ratio < 0.8) & (vol_8d_avg < vol_63d_avg))
 ), by = company_id]
 
 # 5.2.2 Stage 1: Initial Breakout Conditions
 dt[, `:=`(
  PRICE_BREAKOUT = as.integer(close > 0.99 * high_21d),  # Within 1% of 21-day high
  VOL_CONFIRM = as.integer(volume > 1.2 * vol_21d_avg),   # Reduced from 1.5x to 1.2x
  MOMENTUM = as.integer(return_5d > 0.02)                 # Reduced from 3% to 2%
 )]
 
 # 5.2.3 Stage 2: Trend Confirmation
 dt[, `:=`(
  ABOVE_MA21 = as.integer(close > ma_21),
  MA_CROSS = as.integer(ma_21 > ma_63),
  REL_STRENGTH = as.integer(return_21d > 0.10)
 )]
 
 # 5.2.4 Stage 3: Strong Trend Conditions
 dt[, `:=`(
  ABOVE_MA126 = as.integer(close > ma_126),
  MA_STACK = as.integer(ma_21 > ma_63 & ma_63 > ma_126),
  STRONG_MOM = as.integer(return_63d > 0.20),
  LOW_DRAWDOWN = as.integer(drawdown > -0.10)
 )]
 
 # 5.2.5 Stage 4: Overextension & Divergence
 dt[, `:=`(
  OVEREXTENDED = as.integer(overextension > 0.075),                 # Reduced from 10% to 7.5%
  DIVERGENCE = as.integer(return_5d < 0.03 & return_63d > -0.08),   # Even more lenient divergence
  CLIMAX_VOL = as.integer(volume > 1.5 * vol_63d_avg)               # Reduced from 1.8x to 1.5x
 )]
 
 # 5.2.6 Stage 5: Distribution
 dt[, `:=`(
  PRICE_BELOW_MA21 = as.integer(close < ma_21),
  VOLUME_DECLINE = as.integer(volume < shift(vol_21d_avg, 1, type = "lag") * 0.8),
  MOMENTUM_DOWN = as.integer(return_21d < 0)
 )]
 
 return(dt)
}

# 5.3 Stage Assignment
# ----------------------------------------------------------------------------

# Helper function to check if a stock is close to a stage (missing only one rule)
# @param dt data.table with rule evaluation results
# @param target_stage Integer (0-5) representing the stage to check
# @return Logical vector indicating if each row is close to the target stage
is_close_to_stage <- function(dt, target_stage) {
 # Define the rules for each stage
 stage_rules <- list(
  # Stage 0 rules
  '0' = c('LOW_VOL', 'TIGHT_RANGE_3DAY', 'VOL_DRYUP'),
  # Stage 1 rules
  '1' = c('PRICE_BREAKOUT', 'VOL_CONFIRM', 'MOMENTUM'),
  # Stage 2 rules
  '2' = c('ABOVE_MA21', 'MA_CROSS', 'REL_STRENGTH', 'MOMENTUM'),
  # Stage 3 rules
  '3' = c('ABOVE_MA126', 'MA_STACK', 'STRONG_MOM', 'LOW_DRAWDOWN'),
  # Stage 4 rules
  '4' = c('OVEREXTENDED', 'DIVERGENCE', 'CLIMAX_VOL'),
  # Stage 5 rules
  '5' = c('PRICE_BELOW_MA21', 'VOLUME_DECLINE', 'MOMENTUM_DOWN')
 )
 
 # Get rules for the target stage
 rules <- stage_rules[[as.character(target_stage)]]
 if (is.null(rules) || length(rules) == 0) {
  return(rep(FALSE, nrow(dt)))
 }
 
 # Check which rules exist in the data
 existing_rules <- intersect(rules, names(dt))
 if (length(existing_rules) == 0) {
  return(rep(FALSE, nrow(dt)))
 }
 
 # Check if all or all but one rule is met
 rules_met <- rowSums(dt[, ..existing_rules] == 1, na.rm = TRUE)
 total_rules <- length(existing_rules)
 return(rules_met >= pmax(1, total_rules - 1))
}

# Function to calculate stage scores based on underlying metrics
# @param dt data.table with price and indicator data
# @return data.table with added stage score columns (stage_0_score through stage_5_score)
calculate_stage_scores <- function(dt) {
 log_message("Calculating stage scores...", "DEBUG")
 
 # Initialize score columns
 for (s in 0:5) {
  dt[, (paste0('stage_', s, '_score')) := 0]
 }
 
 # Stage 0: Setup (Low Volatility & Consolidation)
 if (all(c('vol_8d_avg', 'vol_63d_avg', 'high', 'low', 'atr', 'volume', 'vol_21d_avg') %in% names(dt))) {
  dt[, stage_0_score := {
   # Normalize volume ratio (lower is better for setup)
   vol_ratio_norm <- pmin(1, pmax(0, 1 - (vol_8d_avg / pmax(vol_63d_avg, 1e-6))))
   
   # Tight range score (1 - normalized range)
   range_norm <- pmin(1, (high - low) / (atr * 0.1)) # Smaller range/ATR is better
   tight_range_score <- 1 - range_norm
   
   # Volume dry-up score (lower volume is better)
   vol_dryup_score <- pmin(1, pmax(0, 1 - (volume / pmax(vol_21d_avg, 1e-6))))
   
   # Weighted average of components
   (vol_ratio_norm * 0.4 + tight_range_score * 0.4 + vol_dryup_score * 0.2) * 100
  }]
 } else {
  log_message("Missing required columns for stage 0 score calculation", "WARN")
 }
 
 # Stage 1: Breakout
 if (all(c('close', 'high_21d', 'volume', 'vol_21d_avg') %in% names(dt))) {
  dt[, stage_1_score := {
   # Price breakout strength (how far above high_21d)
   # Changed: Allow prices within 1% of high_21d to count for breakout
   breakout_strength <- pmin(1, pmax(0, (close - (high_21d * 0.99)) / (close * 0.05)))
   
   # Volume confirmation (higher volume is better)
   # Changed: Reduced volume requirement from 1.5x to 1.2x
   vol_confirmation <- pmin(1, volume / pmax(vol_21d_avg * 1.2, 1e-6))
   
   # Momentum (recent price movement)
   # Changed: Reduced threshold from 5% to 3% for 5-day return
   momentum_score <- pmin(1, pmax(0, (close / shift(close, 5) - 1) / 0.03))
   
   # Weighted average
   (breakout_strength * 0.5 + vol_confirmation * 0.3 + momentum_score * 0.2) * 100
  }]
 } else {
  log_message("Missing required columns for stage 1 score calculation", "WARN")
 }
 
 # Stage 2: Early Momentum
 if (all(c('close', 'ma_21', 'return_21d') %in% names(dt))) {
  dt[, stage_2_score := {
   # Above MA21 (distance from MA21)
   ma21_score <- pmin(1, pmax(0, (close / ma_21 - 1) / 0.05))
   
   # MA cross (recent crossover)
   ma_cross_score <- as.numeric(ma_21 > shift(ma_21, 5)) * 0.5 + 0.5
   
   # Relative strength (vs market/index)
   rel_strength <- pmin(1, pmax(0, (return_21d - 0.05) / 0.15))
   
   # Momentum (21-day return)
   momentum_score <- pmin(1, pmax(0, (close / shift(close, 21) - 1) / 0.10))
   
   # Weighted average
   (ma21_score * 0.3 + ma_cross_score * 0.2 + rel_strength * 0.3 + momentum_score * 0.2) * 100
  }]
 } else {
  log_message("Missing required columns for stage 2 score calculation", "WARN")
 }
 
 # Stage 3: Strong Trend
 if (all(c('close', 'ma_21', 'ma_63', 'ma_126', 'drawdown') %in% names(dt))) {
  dt[, stage_3_score := {
   # Above MA126 (distance from MA126)
   ma126_score <- pmin(1, pmax(0, (close / ma_126 - 1) / 0.10))
   
   # MA stack (aligned MAs)
   ma_stack_score <- as.numeric(ma_21 > ma_63 & ma_63 > ma_126) * 0.5 + 0.5
   
   # Strong momentum (63-day return)
   strong_mom_score <- pmin(1, pmax(0, (close / shift(close, 63) - 1) / 0.20))
   
   # Low drawdown (less drawdown is better)
   drawdown_score <- pmin(1, pmax(0, 1 - (abs(drawdown) / 0.15)))
   
   # Weighted average
   (ma126_score * 0.3 + ma_stack_score * 0.2 + strong_mom_score * 0.3 + drawdown_score * 0.2) * 100
  }]
 } else {
  log_message("Missing required columns for stage 3 score calculation", "WARN")
 }
 
 # Stage 4: Exhaustion
 if (all(c('close', 'ma_21', 'rsi', 'volume', 'vol_63d_avg') %in% names(dt))) {
  dt[, stage_4_score := {
   # Overextension (distance from MA21)
   # Changed: Reduced overextension requirement from 20% to 15% above MA21
   overextended_score <- pmin(1, pmax(0, (close / ma_21 - 1.15) / 0.20))
   
   # Divergence (price vs momentum)
   divergence_score <- as.numeric(close > shift(close, 5) & rsi < shift(rsi, 5)) * 0.5 + 0.5
   
   # Climax volume (high volume)
   # Changed: Reduced volume requirement from 2x to 1.5x
   climax_vol_score <- pmin(1, volume / pmax(vol_63d_avg * 1.5, 1e-6))
   
   # Weighted average
   (overextended_score * 0.4 + divergence_score * 0.3 + climax_vol_score * 0.3) * 100
  }]
 } else {
  log_message("Missing required columns for stage 4 score calculation", "WARN")
 }
 
 # Stage 5: Distribution
 if (all(c('close', 'ma_21', 'volume', 'vol_21d_avg') %in% names(dt))) {
  dt[, stage_5_score := {
   # Price below MA21
   below_ma21_score <- pmin(1, pmax(0, (ma_21 - close) / (close * 0.05)))
   
   # Volume decline
   vol_decline_score <- pmin(1, pmax(0, 1 - (volume / pmax(vol_21d_avg * 0.8, 1e-6))))
   
   # Downward momentum
   down_mom_score <- pmin(1, pmax(0, (shift(close, 5) / close - 1) / 0.05))
   
   # Weighted average
   (below_ma21_score * 0.4 + vol_decline_score * 0.3 + down_mom_score * 0.3) * 100
  }]
 } else {
  log_message("Missing required columns for stage 5 score calculation", "WARN")
 }
 
 # Ensure scores are between 0 and 100
 for (s in 0:5) {
  score_col <- paste0('stage_', s, '_score')
  if (score_col %in% names(dt)) {
   dt[, (score_col) := pmin(100, pmax(0, get(score_col)))]
  }
 }
 
 log_message("Completed calculating stage scores", "DEBUG")
 return(dt)
}

# Function to evaluate close-to-stage conditions
# @param dt data.table with stage assignments and rule evaluations
# @return data.table with added close_to_stage_X columns and best_partial_stage
evaluate_partial_signals <- function(dt) {
 log_message("Starting evaluation of partial signals", "INFO")
 start_time <- Sys.time()
 
 # Log initial state
 log_message(sprintf("Processing %d rows of data", nrow(dt)), "DEBUG")
 
 # Initialize all close_to_stage_X columns with 0
 log_message("Initializing close_to_stage_X columns", "DEBUG")
 for (s in 0:5) {
  col_name <- paste0('close_to_stage_', s)
  dt[, (col_name) := 0L]
  log_message(sprintf(" Initialized column: %s", col_name), "TRACE")
 }
 
 log_message("Completed initialization of signal columns", "DEBUG")
 
 # Define stage rules
 stage_rules <- list(
  '0' = c('LOW_VOL', 'TIGHT_RANGE_3DAY', 'VOL_DRYUP'),
  '1' = c('PRICE_BREAKOUT', 'VOL_CONFIRM', 'MOMENTUM'),
  '2' = c('ABOVE_MA21', 'MA_CROSS', 'REL_STRENGTH', 'MOMENTUM'),
  '3' = c('ABOVE_MA126', 'MA_STACK', 'STRONG_MOM', 'LOW_DRAWDOWN'),
  '4' = c('OVEREXTENDED', 'DIVERGENCE', 'CLIMAX_VOL'),
  '5' = c('PRICE_BELOW_MA21', 'VOLUME_DECLINE', 'MOMENTUM_DOWN')
 )
 
 # Initialize close_to_stage columns with 0
 for (s in 0:5) {
  dt[, (paste0('close_to_stage_', s)) := 0L]
 }
 
 # Process each stage in parallel
 for (s in 0:5) {
  rules <- stage_rules[[as.character(s)]]
  existing_rules <- intersect(rules, names(dt))
  if (length(existing_rules) == 0) next
  
  # Check if rows are close to this stage (not current stage and meets all or all but one rule)
  rules_met <- rowSums(dt[, ..existing_rules] == 1, na.rm = TRUE)
  total_rules <- length(existing_rules)
  
  # Use %in% for vector comparison to avoid length mismatch
  is_close <- ((!is.na(dt$stage) & !(dt$stage %in% s)) | is.na(dt$stage)) &
       (rules_met >= pmax(1, total_rules - 1))
  
  # Update the close_to_stage column
  dt[is_close, (paste0('close_to_stage_', s)) := 1L]
 }
 
 # Set best_partial_stage to 0 for all records (temporary solution)
 dt[, best_partial_stage := 0L]
 
 # Original best_partial_stage calculation (commented out)
 # dt[, best_partial_stage := {
 #  # Get all close_to_stage_X columns that are 1
 #  stage_cols <- paste0('close_to_stage_', 0:5)
 #  close_stages <- which(sapply(stage_cols, function(x) get(x) == 1))
 #  if (length(close_stages) > 0) {
 #   paste(sort(close_stages - 1), collapse = ",")
 #  } else {
 #   NA_character_
 #  }
 # }]
 
 log_message(sprintf("Completed partial signal evaluation in %.2f seconds", 
          as.numeric(difftime(Sys.time(), start_time, units = "secs"))), 
      "INFO")
 
 return(dt)
}

#' Assign Momentum Stages
#' 
#' Determines the current momentum stage for each stock based on rule evaluations.
#' @param dt data.table with rule evaluation results
#' @return data.table with assigned stages and rule metrics
#' @details
#' Stages progress from 0 (low volatility) to 4 (extended trend).
#' Each stage requires a minimum number of rules to be satisfied.
#' The function tracks:
#' - Current stage
#' - Best partial stage 
#' - Stage assignment based on rule conditions
assign_stage <- function(dt) {
 log_message("Assigning momentum stages...")
 
 # 5.3.1 Initialize stage tracking columns
 dt[, `:=`(
  stage = NA_integer_,      # Current stage (0-5)
  best_partial_stage = NA_character_ # Comma-separated list of stages this is close to
 )]
 
 # Log initial state
 log_message(sprintf(" Processing %d companies with %d rows total", 
          dt[, uniqueN(company_id)], nrow(dt)), "INFO")
 
 # Precompute rule names for ease
 log_message("\nSTAGE ASSIGNMENT SUMMARY", "INFO")
 log_message(paste(rep("-", 50), collapse = ""), "INFO")
 
 for (s in names(stage_defs)) {
  if (!s %in% names(stage_defs)) {
   log_message(paste0("Warning: Stage definition not found for stage: ", s))
   next
  }
  
  # Safely get rules for this stage
  rules <- tryCatch({
   stage_defs[[s]]$rules
  }, error = function(e) {
   log_message(paste0("Error accessing rules for stage ", s, ": ", e$message))
   NULL
  })
  
  if (is.null(rules) || length(rules) == 0) {
   log_message(paste0("No rules defined for stage ", s))
   next
  }
  
  log_message(sprintf("\nProcessing stage %s with %d rules: %s", 
           s, length(rules), paste(rules, collapse = ", ")), "DEBUG")
  
  # Check which rules exist in the data
  present_rules <- rules[rules %in% names(dt)]
  missing_rules <- setdiff(rules, present_rules)
  
  if (length(present_rules) == 0) {
   log_message(sprintf(" No valid rules found in data for stage %s. Missing rules: %s", 
            s, paste(missing_rules, collapse = ", ")), "WARN")
   next
  }
  
  if (length(missing_rules) > 0) {
   log_message(sprintf(" Warning: %d rules missing for stage %s: %s", 
            length(missing_rules), s, 
            paste(missing_rules, collapse = ", ")), "WARN")
  }
  
  # Count met per row
  met_mat <- tryCatch({
   dt[, .SD, .SDcols = present_rules]
  }, error = function(e) {
   log_message(paste0("Error accessing rule columns for stage ", s, ": ", e$message))
   NULL
  })
  
  if (is.null(met_mat)) next
  
  met_count <- rowSums(as.matrix(met_mat) == 1, na.rm = TRUE)
  total <- length(present_rules)
  
  # Log rule statistics
  rule_stats <- colSums(met_mat == 1, na.rm = TRUE)
  rule_pct <- round(rule_stats / nrow(met_mat) * 100, 1)
  rule_summary <- data.table(
   rule = names(rule_stats),
   count = rule_stats,
   pct = rule_pct
  )
  
  log_message(sprintf(" Rule statistics for stage %s (showing rules met in >0%% of rows):", s), "DEBUG")
  log_message(capture.output(print(rule_summary[count > 0], nrows = 20)), "DEBUG")
  
  # Update best_partial_stage where we have a better match
  # Commented out as we're setting best_partial_stage to 0 for all records
  # better_idx <- which(is.na(dt$best_partial_stage) | 
  #          as.integer(s) > dt$best_partial_stage)
  # if (length(better_idx) > 0) {
  #  dt[better_idx, best_partial_stage := as.integer(s)]
  # }
  
  # Full matches -> assign stage
  full_idx <- which(met_count == total & total > 0)
  if (length(full_idx) > 0) {
   dt[full_idx, stage := as.integer(s)]
   log_message(sprintf(" Assigned stage %s to %d rows (%.1f%% of data)", 
            s, length(full_idx), 
            length(full_idx)/nrow(dt)*100), "DEBUG")
  } else {
   log_message(sprintf(" No full matches for stage %s (0 rows met all %d rules)", 
            s, total), "DEBUG")
  }
 }
 
 # Carry forward stage (locf) to avoid gaps
 dt[, stage := nafill(stage, type = "locf", fill = 0), by = company_id]
 
 # Replace NA stages with "NO_STAGE"
 dt[is.na(stage), stage := 0] # Use 0 as a placeholder for NO_STAGE
 
 # Log final stage distribution
 stage_dist <- dt[, .N, by = stage][order(stage)]
 total_rows <- nrow(dt)
 
 log_message("\nFINAL STAGE DISTRIBUTION", "INFO")
 log_message(paste(rep("-", 50), collapse = ""), "INFO")
 
 for (i in 1:nrow(stage_dist)) {
  stage_name <- if(stage_dist$stage[i] == -1) {
   "NO_STAGE"
  } else {
   switch(as.character(stage_dist$stage[i]),
      "0" = "SETUP",
      "1" = "BREAKOUT",
      "2" = "EARLY_MOM",
      "3" = "SUSTAINED",
      "4" = "EXTENDED",
      "5" = "DISTRIBUTION",
      as.character(stage_dist$stage[i]))
  }
  
  pct <- round(stage_dist$N[i] / total_rows * 100, 1)
  log_message(sprintf(" Stage %s (%s): %d rows (%.1f%%)", 
           stage_dist$stage[i], stage_name, 
           stage_dist$N[i], pct), "INFO")
 }
 
 log_message(sprintf(" Total assigned stages: %d rows (%.1f%% of total data)", 
          total_rows, total_rows/nrow(dt)*100), "INFO")
 
 return(dt)
}

add_stage_history <- function(dt) {
  setorder(dt, company_id, date)
  
  # Ensure stage has locf filled
  dt[, stage_ff := nafill(stage, type = "locf"), by = company_id]
  
  # Track last 3 stage changes
  dt[, stage_history := {
    # Get only the stage changes (where stage is different from previous)
    changes <- which(c(TRUE, diff(stage_ff) != 0))
    
    # Get the last 3 changes (or fewer if not enough changes)
    last_changes <- tail(changes, 3)
    
    # Get the stages and their start dates
    stages <- stage_ff[last_changes]
    
    # Calculate days in each stage
    ends <- c(last_changes[-1] - 1, length(stage_ff))
    days_in_stage <- ends - last_changes + 1
    
    # Create stage names mapping
    stage_names <- c(
      "0" = "SETUP",
      "1" = "BREAKOUT",
      "2" = "EARLY_MOM",
      "3" = "SUSTAINED",
      "4" = "EXTENDED",
      "5" = "DISTRIBUTION"
    )
    
    # Format each stage change
    stage_strings <- mapply(
      function(s, d) {
        stage_name <- stage_names[as.character(s)]
        if (is.na(stage_name)) stage_name <- paste("Stage", s)
        sprintf("%s (%d day%s)", stage_name, d, ifelse(d > 1, "s", ""))
      },
      stages,
      days_in_stage
    )
    
    # Combine with arrows and repeat for all rows
    history <- paste(rev(stage_strings), collapse = " → ")
    rep(history, .N)
  }, by = company_id]
  
  return(dt)
}

# 5.4 Dynamic Level Calculation
# ----------------------------------------------------------------------------

#' Calculate Dynamic Support/Resistance
#' 
#' Identifies key price levels for stop-loss and take-profit calculations.
#' @param dt data.table with price data and indicators
#' @return data.table with dynamic levels added
#' @details
#' Calculates:
#' - Swing highs/lows using local maxima/minima
#' - Support/resistance zones based on recent price action
#' - Stop-loss and take-profit levels using ATR and recent volatility
calculate_dynamic_levels <- function(dt) {
 log_message("Calculating dynamic price levels...")
 
 # 5.4.1 Data Preparation
 # Ensure data is ordered by company and date
 setorder(dt, company_id, date)
 
 # Calculate swing lows/highs with error handling
 dt[, `:=`(
  swing_low_5d = tryCatch({
   frollapply(low, 5, min, align = "right", fill = NA)
  }, error = function(e) {
   log_message("Error calculating swing_low_5d: ", e$message)
   rep(NA_real_, .N)
  }),
  swing_low_10d = tryCatch({
   frollapply(low, 10, min, align = "right", fill = NA)
  }, error = function(e) {
   log_message("Error calculating swing_low_10d: ", e$message)
   rep(NA_real_, .N)
  }),
  swing_high_5d = tryCatch({
   frollapply(high, 5, max, align = "right", fill = NA)
  }, error = function(e) {
   log_message("Error calculating swing_high_5d: ", e$message)
   rep(NA_real_, .N)
  })
 ), by = company_id]
 
 # Base stop multiplier by stage with safe access to stage_defs (vectorized version)
 dt[, base_stop_pct := {
  # Use fifelse for vectorized conditional logic
  fifelse(
   is.na(stage), 2.0, # Default if stage is NA
   fifelse(
    as.character(stage) %in% names(stage_defs),
    fcase(
     stage == 0, 1.5,
     stage == 1, 2.0,
     stage == 2, 2.5,
     stage == 3, 3.0,
     stage == 4, 1.0,
     default = 2.0 # Default if stage number is unexpected
    ),
    2.0 # Default if stage not found in stage_defs
   )
  )
 }]
 
 # Time factor and vol/momentum factors with error handling
 # First calculate optimal_holding_days using vectorized operations
 dt[, optimal_holding_days := {
  fifelse(
   is.na(stage), NA_integer_,
   fifelse(
    as.character(stage) %in% names(stage_defs),
    {
     # Safely get optimal_days for each stage
     sapply(as.character(stage), function(s) {
      if (s %in% names(stage_defs)) {
       stage_defs[[s]]$optimal_days
      } else {
       NA_integer_
      }
     })
    },
    NA_integer_
   )
  )
 }]
 
 # Now calculate the remaining factors
 dt[, `:=`(
  stage_age = seq_len(.N),
  time_factor = pmax(0.5, 1 - (seq_len(.N) / pmax(optimal_holding_days, 1)) * 0.5),
  vol_factor = pmin(pmax(vol_21d, 0.001, na.rm = TRUE) / 0.20, 1.5, na.rm = TRUE),
  momentum_factor = 1 + pmin(pmax(return_21d * 10, 0, na.rm = TRUE), 1, na.rm = TRUE)
 ), by = .(company_id, rleid(stage))]
 
 # Compute base stop with error handling
 dt[, base_stop := {
  tryCatch({
   close - (atr * base_stop_pct * time_factor * vol_factor / pmax(momentum_factor, 1e-6))
  }, error = function(e) {
   log_message(paste0("Error calculating base_stop: ", e$message))
   close * 0.9 # Default to 10% below close on error
  })
 }]
 
 # Stage-specific stop levels with error handling
 dt[, stop_loss := base_stop] # Default to base_stop
 
 # First, ensure base_stop is calculated for all rows
 dt[, base_stop := {
  tryCatch({
   close - (atr * base_stop_pct * time_factor * vol_factor / pmax(momentum_factor, 1e-6))
  }, error = function(e) {
   log_message(paste0("Error calculating base_stop: ", e$message))
   close * 0.9 # Default to 10% below close on error
  })
 }]
 
 # Initialize stop_loss with base_stop
 dt[, stop_loss := base_stop]
 
 # Update stop losses by stage with safety checks
 update_stop_loss <- function(condition, new_value_expr) {
  tryCatch({
   dt[eval(parse(text = condition)), stop_loss := eval(parse(text = new_value_expr))]
  }, error = function(e) {
   log_message(paste0("Error updating stop loss for condition ", condition, ": ", e$message))
  })
 }
 
 # Apply stop loss rules by stage
 update_stop_loss("stage == 0 & !is.na(swing_low_5d)", "pmax(base_stop, swing_low_5d * 0.99, na.rm = TRUE)")
 update_stop_loss("stage == 1 & !is.na(swing_low_5d)", "pmax(base_stop, swing_low_5d * 0.98, na.rm = TRUE)")
 update_stop_loss("stage == 2 & !is.na(ma_21)", "pmax(base_stop, ma_21 * 0.97, na.rm = TRUE)")
 
 # More complex stage 3 stop with fallbacks - vectorized version
 dt[stage == 3, stop_loss := {
  tryCatch({
   ma_stop <- ma_50 * 0.95
   swing_stop <- swing_low_10d * 0.95
   pmax(base_stop, ma_stop, swing_stop, na.rm = TRUE)
  }, error = function(e) {
   log_message(paste0("Error calculating stage 3 stop loss: ", e$message))
   base_stop
  })
 }]
 
 # Ensure stop is never below previous stop for same stage group (trail up)
 dt[, stop_loss := {
  tryCatch({
   cummax(nafill(stop_loss, type = "locf"))
  }, error = function(e) {
   log_message(paste0("Error in cummax for stop_loss: ", e$message))
   stop_loss
  })
 }, by = .(company_id, rleid(stage))]
 
 dt[, stop_pct := tryCatch({
    # Ensure stop is below current price for long positions
    stop_loss <- pmin(stop_loss, close * 0.99)  # Force stop to be at least 1% below current price
    # Calculate percentage distance
    ((close - stop_loss) / close) * 100
  }, 
  error = function(e) {
    log_message(paste0("Error calculating stop_pct: ", e$message))
    rep(NA_real_, .N)
  }
)]

 # Ensure stop_loss is properly defined and below current price
 if (!"stop_loss" %in% names(dt)) {
   dt[, stop_loss := close * 0.95]  # Default to 5% below close if not set
 } else {
   dt[, stop_loss := pmin(stop_loss, close * 0.99)]
 }
 
 # Calculate take profit with 2:1 reward-to-risk ratio
 dt[, take_profit := {
   tryCatch({
     close + (close - stop_loss) * 2
   }, error = function(e) {
     log_message(paste0("Error calculating take_profit: ", e$message))
     close * 1.1 # Default to 10% above close on error
   })
 }]
 
 # Calculate take profit percentage
 dt[, take_profit_pct := ((take_profit - close) / close) * 100]
 
 # Calculate risk/reward ratio with proper vectorization
 dt[, risk_reward := {
   tryCatch({
     risk <- close - stop_loss
     reward <- take_profit - close
     ifelse(abs(risk) < 1e-6, NA_real_, reward / risk)
   }, error = function(e) {
     log_message(paste0("Error calculating risk_reward: ", e$message))
     rep(NA_real_, .N)
   })
 }]
 
 return(dt)
}

add_metadata <- function(dt) {
 setorder(dt, company_id, date)
 # stage change using locf stage for stability - handle vectorized operations
 dt[, stage_ff := {
  if (.N > 0) nafill(stage, type = "locf") else NA_integer_
 }, by = company_id]
 
 # Calculate stage changes safely
 dt[, stage_change := {
  prev_stage <- shift(stage_ff, 1, type = "lag")
  !is.na(stage_ff) & !is.na(prev_stage) & (stage_ff != prev_stage)
 }, by = company_id]
 
 # Calculate stage group
 dt[, stage_group := rleid(stage_ff), by = company_id]
 
 # Calculate stage_age with proper run-length encoding - memory efficient version
 dt[, stage_age := {
  # Create a run-length ID for each stage per company
  rl <- rleid(stage_ff)
  # Calculate run lengths within each company group
  unlist(by(rl, company_id, function(x) {
   if (length(x) == 0) return(rep(NA_integer_, length(x)))
   r <- rle(x)
   sequence(r$lengths)
  }, simplify = FALSE))
 }]
 
 # Calculate optimal_holding_days based on stage_ff
 dt[, optimal_holding_days := {
  sapply(stage_ff, function(s) {
   if (is.na(s)) return(NA_integer_)
   s_char <- as.character(s)
   if (s_char %in% names(stage_defs)) {
    return(stage_defs[[s_char]]$optimal_days)
   } else {
    log_message(paste0("Warning: Invalid stage_ff value: ", s))
    return(NA_integer_)
   }
  })
 }]
 
 # Calculate days_remaining with proper NA handling
 dt[, days_remaining := {
  if (all(is.na(optimal_holding_days))) {
   rep(NA_integer_, .N)
  } else {
   pmax(0, optimal_holding_days - stage_age + 1, na.rm = TRUE)
  }
 }]
 
 # Dynamic factors already computed, pack progress factor
 dt[, progress_factor := pmin((close / shift(close, 21) - 1) / 0.2, 1)]
 
 # Initialize trade tracking columns if they don't exist (just the columns, no logic yet)
 trade_cols <- c('entry_price', 'exit_price', 'entry_date', 'exit_date', 'pnl_pct')
 for (col in trade_cols) {
  if (!col %in% names(dt)) {
   if (col %in% c('entry_date', 'exit_date')) {
    dt[, (col) := as.character(NA)]
   } else {
    dt[, (col) := NA_real_]
   }
  }
 }
 
 # Entry/exit signals
 dt[, is_entry := (!is.na(stage_ff) & stage_change == TRUE)]
 dt[, is_exit := (shift(stage_change, type = "lead") == TRUE) | 
   (stage_age >= optimal_holding_days & !is.na(optimal_holding_days)), by = company_id]
 
 # Evaluate close-to-stage conditions
 log_message(sprintf("DEBUG: Starting partial signal evaluation..."))
 dt <- evaluate_partial_signals(dt)
 log_message(sprintf("DEBUG: Completed partial signal evaluation"))
  # Log data structure after partial signals
  log_message(sprintf("DEBUG: Data dimensions after partial signals: %d rows, %d columns", nrow(dt), ncol(dt)))
  log_message(sprintf("DEBUG: Sample of stage_ff values: %s", paste(head(unique(na.omit(dt$stage_ff))), collapse=", ")))
  log_message(sprintf("DEBUG: Sample of close_to_stage_X columns: %s", 
              paste(grep("close_to_stage_", names(dt), value=TRUE), collapse=", ")))
  
  # Check for any NA values in key columns
  log_message(sprintf("DEBUG: NA check - stage_ff: %d of %d (%.2f%%)", 
                     sum(is.na(dt$stage_ff)), nrow(dt), 
                     round(mean(is.na(dt$stage_ff))*100, 2)))
 
 # Status assignment with risk-reward based conditions
 log_message(sprintf("DEBUG: Starting status assignment..."))
 dt[, `:=`(status = {
  # Initialize with NO_ACTION
  result <- rep("NO_ACTION", .N)
  
  # 1. ENTRY Conditions (Long only)
  entry_conditions <- 
   (close > stop_loss) &        # Price must be above stop loss (long only)
   (stage_ff %in% c(0, 1, 2, 3)) & # Enter in setup/accumulation/advancement stages
   (stop_pct <= 10) &          # Reasonable stop distance (max 10%)
   (stop_pct >= 1)             # Minimum stop distance (at least 1%)
  
  # 2. EXIT Conditions
  # Stage-based targets and holding periods
  stage_targets <- data.table(
    stage = 0:5,
    min_return_pct = c(0, 5, 10, 15, 20, 0),  # More conservative minimum returns
    max_return_pct = c(0, 15, 25, 30, 40, 0),  # More realistic maximum returns
    optimal_days = c(8, 14, 28, 42, 5, 3)      # From stage_defs
  )
  
  # Calculate current return since entry and days in position
  current_return <- (close / entry_price - 1) * 100
  days_in_position <- as.numeric(difftime(date, entry_date, units = "days"))
  
  # Initialize exit conditions as FALSE
  exit_conditions <- rep(FALSE, length(close))
  
  # Process each stage separately to ensure vector alignment
  for(s in 0:5) {
    # Get indices for current stage
    stage_mask <- !is.na(stage_ff) & stage_ff == s
    if(any(stage_mask)) {
      # Get targets for current stage
      stage_info <- stage_targets[stage == s]
      
      # Calculate exit conditions for this stage
      stage_exits <- 
        (close[stage_mask] <= stop_loss[stage_mask]) |  # Hit stop loss
        (s == 5) |  # In distribution stage
        (s == 4 & close[stage_mask] < shift(close[stage_mask], type = "lag")) |  # Early signs of topping
        (current_return[stage_mask] >= stage_info$max_return_pct) |  # Reached max target
        (days_in_position[stage_mask] >= stage_info$optimal_days &  # Held long enough
         current_return[stage_mask] >= stage_info$min_return_pct)  # With minimum return
      
      # Update exit conditions for this stage
      exit_conditions[stage_mask] <- stage_exits
    }
  }
  
  # Add debug logging
  log_message(sprintf("Exit conditions: %d rows (%.1f%% of data)", 
                     sum(exit_conditions, na.rm = TRUE),
                     mean(exit_conditions, na.rm = TRUE) * 100))
  
  # 3. HOLD Conditions (only for positions not hitting exit conditions)
  hold_conditions <-
   !is.na(entry_price) & # In a position
   !exit_conditions    # Not hitting exit conditions

  # Apply signals in order of priority
  result[exit_conditions] <- "EXIT"
  result[entry_conditions] <- "ENTRY"
  result[hold_conditions] <- "HOLD"
  
  # Add stage information to non-NO_ACTION statuses
  non_action_idx <- which(result != "NO_ACTION")
  if (length(non_action_idx) > 0) {
   result[non_action_idx] <- sapply(non_action_idx, function(i) {
    s <- stage_ff[i]
    if (is.na(s)) return(result[i])
    s_char <- as.character(s)
    stage_name <- if (s_char %in% names(stage_defs)) {
     stage_defs[[s_char]]$name
    } else {
     "UNKNOWN_STAGE"
    }
    paste0(result[i], "_S", s, "_", stage_name)
   })
  }
  
  result
 })]
 
 # Track entry/exit prices and dates for current stage trade
 dt[, c("entry_price", "exit_price", "entry_date", "exit_date") := {
   # Initialize with current values
   new_entry_price <- entry_price
   new_entry_date <- entry_date
   new_exit_price <- exit_price
   new_exit_date <- exit_date
   
   # Get current stage
   current_stage <- stage_ff
   prev_stage <- shift(stage_ff, 1, type = "lag")
   
   # Check for stage changes
   stage_changed <- !is.na(current_stage) & (is.na(prev_stage) | current_stage != prev_stage)
   
   # On new stage, clear previous trade data
   new_entry_price[stage_changed] <- NA_real_
   new_entry_date[stage_changed] <- NA_character_
   new_exit_price[stage_changed] <- NA_real_
   new_exit_date[stage_changed] <- NA_character_
   
   # Update entry on ENTRY status for current stage
   is_entry <- startsWith(status, "ENTRY_")
   new_entry_price[is_entry] <- close[is_entry]
   new_entry_date[is_entry] <- as.character(date[is_entry])
   
   # Update exit on EXIT status for current stage
   is_exit <- startsWith(status, "EXIT_")
   new_exit_price[is_exit] <- close[is_exit]
   new_exit_date[is_exit] <- as.character(date[is_exit])
   
   # Return updated columns
   list(new_entry_price, new_exit_price, new_entry_date, new_exit_date)
 }, by = company_id]
 
 # Function to generate data quality summary
 generate_data_quality_summary <- function(dt, context = "") {
  log_message(paste0("\n=== Data Quality Summary ", context, " ==="))
  
  # Basic info
  log_message(sprintf("Total Rows: %d", nrow(dt)))
  log_message(sprintf("Unique Companies: %d", length(unique(dt$company_id))))
  log_message(sprintf("Date Range: %s to %s", 
           min(dt$date, na.rm = TRUE), 
           max(dt$date, na.rm = TRUE)))
  
  # Key column checks
  key_cols <- c("company_id", "date", "close", "status", 
        "entry_price", "exit_price", "pnl_pct", "stage_ff")
  
  log_message("\nMissing Values in Key Columns:")
  na_summary <- sapply(key_cols, function(col) {
   na_count <- sum(is.na(dt[[col]]))
   pct_na <- round(na_count / nrow(dt) * 100, 2)
   sprintf(" %-15s: %8d (%5.2f%%)", col, na_count, pct_na)
  })
  log_message(paste(na_summary, collapse = "\n"))
  
  # Status distribution
  log_message("\nStatus Distribution:")
  status_dist <- dt[, .N, by = status][order(-N)]
  for (i in 1:nrow(status_dist)) {
   pct <- round(status_dist$N[i] / nrow(dt) * 100, 2)
   log_message(sprintf(" %-20s: %8d (%5.2f%%)", 
            status_dist$status[i], 
            status_dist$N[i],
            pct))
  }
  
  # Stage distribution
  if ("stage_ff" %in% names(dt)) {
   log_message("\nStage Distribution:")
   stage_dist <- dt[, .N, by = stage_ff][order(-N)]
   for (i in 1:nrow(stage_dist)) {
    pct <- round(stage_dist$N[i] / nrow(dt) * 100, 2)
    log_message(sprintf(" Stage %-15s: %8d (%5.2f%%)", 
             stage_dist$stage_ff[i], 
             stage_dist$N[i],
             pct))
   }
  }
  
  # Numeric columns summary
  num_cols <- names(dt)[sapply(dt, is.numeric)]
  log_message("\nNumeric Columns Summary:")
  num_summary <- lapply(num_cols, function(col) {
   data.table(
    column = col,
    min = min(dt[[col]], na.rm = TRUE),
    mean = mean(dt[[col]], na.rm = TRUE),
    median = median(dt[[col]], na.rm = TRUE),
    max = max(dt[[col]], na.rm = TRUE),
    na_count = sum(is.na(dt[[col]]))
   )
  })
  
  # Print top 10 numeric columns by NA count
  na_summary <- rbindlist(num_summary)[order(-na_count)]
  log_message("Top 10 numeric columns with most NAs:")
  print(na_summary[1:min(10, nrow(na_summary)), 
          .(column, na_count, 
           pct_na = round(na_count/nrow(dt)*100, 2))])
  
  log_message("\n")
  return(invisible(TRUE))
 }
 
 # Generate initial data quality report
 generate_data_quality_summary(dt, "Before Trade Summary Generation")
 
 # Create trade summary for clear position tracking
 dt[, trade_summary := {
  tryCatch({
   # Debug info
   message("Starting trade summary generation for company: ", company_id[1])
   
   # Base information that's always present - using fifelse for vectorization
   message("Creating base_info...")
   entry_str <- fifelse(!is.na(entry_price),
             paste0("Entry: ", sprintf("%.2f", entry_price)),
             "Entry: -",
             na = "Entry: -")
   
   current_str <- fifelse(!is.na(close),
             paste0("Current: ", sprintf("%.2f", close)),
             "Current: -",
             na = "Current: -")
   
   base_info <- paste(status, entry_str, current_str, sep = " | ")
   
   # PnL information (only if pnl_pct exists)
   message("Creating pnl_info...")
   pnl_info <- fifelse(!is.na(pnl_pct),
            fifelse(!is.na(take_profit_pct),
                paste0("PnL: ", sprintf("%+.1f%% (Target: %+.1f%%)", pnl_pct, take_profit_pct)),
                paste0("PnL: ", sprintf("%+.1f%%", pnl_pct))),
            "")
   
   # Risk information (only if all components exist)
   message("Creating risk_info...")
   risk_info <- fifelse(!is.na(stop_loss) & !is.na(stop_pct) & !is.na(risk_reward),
             paste0("Stop: ", sprintf("%.2f (%.1f%%) | R:R %.1f", 
                        stop_loss, -stop_pct, risk_reward)),
             "")
   
   # Time information (only if all components exist)
   message("Creating time_info...")
   time_info <- fifelse(!is.na(stage_age) & !is.na(optimal_holding_days) & !is.na(days_remaining),
             paste0("Days: ", sprintf("%d/%d (Remaining: %d)", 
                        stage_age, optimal_holding_days, days_remaining)),
             "")
   
   # Debug intermediate results
   message("Intermediate results - ")
   message("base_info length: ", length(base_info))
   message("pnl_info length: ", length(pnl_info))
   message("risk_info length: ", length(risk_info))
   message("time_info length: ", length(time_info))
   
   # Combine all parts conditionally
   message("Combining results...")
   result <- fifelse(startsWith(status, "NO_ACTION"),
           "NO_ACTION",
           fifelse(nchar(pnl_info) > 0 | nchar(risk_info) > 0 | nchar(time_info) > 0,
               paste(base_info, pnl_info, risk_info, time_info, sep = " | "),
               base_info))
   
   # Clean up any double separators or trailing separators
   message("Cleaning up separators...")
   result <- gsub("\\| \\| ", "| ", result)
   result <- gsub(" \\| $", "", result)
   result <- gsub("^ \\| ", "", result)
   result <- gsub("^\\| ", "", result)
   
   message("Trade summary generation complete")
   return(result)
  })
 }]
 
 # Create trade summary for clear position tracking
 message("Generating trade summaries...")
 
 tryCatch({
  # First, create all the components using data.table operations
  dt[, `:=`(
   # Entry price string
   entry_str = fifelse(!is.na(entry_price) & entry_price > 0,
            paste0("Entry: ", format(round(entry_price, 2), nsmall = 2)),
            "Entry: -",
            na = "Entry: -"),
   
   # Current price string
   current_str = fifelse(!is.na(close) & close > 0,
             paste0("Current: ", format(round(close, 2), nsmall = 2)),
             "Current: -",
             na = "Current: -")
  )]
  
  # PnL information (handled separately to avoid complex nested fifelse)
  dt[, pnl_info := ""]
  if (all(c("pnl_pct", "entry_price", "take_profit_pct") %in% names(dt))) {
   dt[!is.na(pnl_pct) & !is.na(entry_price) & entry_price > 0,
    pnl_info := fifelse(!is.na(take_profit_pct),
              paste0("PnL: ", format(round(pnl_pct, 1), nsmall = 1), "%",
                 " (Target: ", format(round(take_profit_pct, 1), nsmall = 1), "%)"),
              paste0("PnL: ", format(round(pnl_pct, 1), nsmall = 1), "%"))]
  }
  
  # Risk information
  dt[, risk_info := ""]
  if (all(c("stop_loss", "stop_pct", "risk_reward", "entry_price") %in% names(dt))) {
   dt[!is.na(stop_loss) & !is.na(stop_pct) & !is.na(risk_reward) & 
     !is.na(entry_price) & entry_price > 0,
    risk_info := paste0("Stop: ", format(round(stop_loss, 2), nsmall = 2), " (",
              format(round(stop_pct, 1), nsmall = 1), "%) | R:R 1:",
              format(round(risk_reward, 1), nsmall = 1))]
  }
  
  # Stage information
  dt[, stage_info := ""]
  if (all(c("stage_ff", "stage_age", "optimal_holding_days", "days_remaining") %in% names(dt))) {
   dt[!is.na(stage_ff) & !is.na(stage_age) & 
     !is.na(optimal_holding_days) & !is.na(days_remaining),
    stage_info := paste0("Stage ", stage_ff, 
              " (Day ", stage_age, 
              "/", optimal_holding_days, 
              ", ", days_remaining, " left)")]
  }
  
  # Now combine all components
  dt[, trade_summary := paste(na.omit(c(status, entry_str, current_str, pnl_info, risk_info, stage_info)), 
               collapse = " | "), by = 1:nrow(dt)]
  
  # Clean up the combined string
  dt[, trade_summary := gsub("\\| \\| ", "| ", trade_summary)]
  dt[, trade_summary := gsub(" \\| $", "", trade_summary)]
  dt[, trade_summary := gsub("^ \\| ", "", trade_summary)]
  dt[, trade_summary := gsub("^\\| ", "", trade_summary)]
  
 }, error = function(e) {
  warning("Error generating trade summaries: ", e$message)
  dt[, trade_summary := "Error generating trade summary"]
 })
 
 # Clean up temporary columns
 temp_cols <- c("entry_str", "current_str", "pnl_info", "risk_info", "stage_info")
 dt[, c(temp_cols) := NULL]
 
 # Generate final data quality report
 generate_data_quality_summary(dt, "After Trade Summary Generation")
 
 # Add data quality flags
 dt[, `:=`(
  has_missing_prices = fifelse(startsWith(status, "NO_ACTION") & 
                (is.na(entry_price) | is.na(exit_price)), 
               1L, 0L, na = 0L),
  has_invalid_dates = fifelse(startsWith(status, "NO_ACTION") & 
                (is.na(entry_date) | is.na(exit_date)), 
               1L, 0L, na = 0L),
  has_na_pnl = fifelse(startsWith(status, "NO_ACTION") & is.na(pnl_pct), 1L, 0L, na = 0L)
 )]
 
 # Log data quality issues
 data_issues <- dt[, .(
  total_rows = .N,
  missing_prices = sum(has_missing_prices, na.rm = TRUE),
  invalid_dates = sum(has_invalid_dates, na.rm = TRUE),
  na_pnl = sum(has_na_pnl, na.rm = TRUE)
 )]
 
 log_message("\n=== Data Quality Issues ===")
 log_message(sprintf("Rows with missing prices: %d (%.2f%%)", 
          data_issues$missing_prices,
          data_issues$missing_prices / data_issues$total_rows * 100))
 log_message(sprintf("Rows with invalid dates: %d (%.2f%%)",
          data_issues$invalid_dates,
          data_issues$invalid_dates / data_issues$total_rows * 100))
 log_message(sprintf("Rows with NA PnL: %d (%.2f%%)",
          data_issues$na_pnl,
          data_issues$na_pnl / data_issues$total_rows * 100))
 
 
 # Clean up temporary columns
 dt[, `:=`(potential_breakout = NULL, 
      potential_exhaustion = NULL, 
      potential_accumulation = NULL)]
 
 # Log status assignment summary
 status_summary <- dt[, .N, by = status][order(-N)]
 log_message("Status assignment summary:")
 for (i in 1:nrow(status_summary)) {
  pct <- status_summary$N[i] / nrow(dt) * 100
  log_message(sprintf(" - %-20s: %6d (%5.1f%%)", 
           status_summary$status[i], 
           status_summary$N[i],
           pct))
 }
 
 # Add detailed logging of data structure
 log_message("\nData structure details:")
 log_message(sprintf("Total rows: %d", nrow(dt)))
 log_message(sprintf("Number of companies: %d", length(unique(dt$company_id))))
 log_message("\nColumn types and NA counts:")
 
 # Get column info
 col_info <- data.table(
  column = names(dt),
  type = sapply(dt, class),
  na_count = sapply(dt, function(x) sum(is.na(x)))
 )
 
 # Log column info
 for (i in 1:nrow(col_info)) {
  log_message(sprintf(" %-20s %-15s NAs: %d (%.1f%%)", 
           col_info$column[i], 
           paste(col_info$type[[i]], collapse = ","),
           col_info$na_count[i],
           col_info$na_count[i] / nrow(dt) * 100))
 }
 
 # Check for potential issues in key columns
 log_message("\nChecking for potential issues in key columns:")
 
 # Check entry_price
 if (any(is.na(dt$entry_price) & startsWith(dt$status, "NO_ACTION"))) {
  log_message(sprintf(" - Found %d rows with NA entry_price but non-NO_ACTION status",
           sum(is.na(dt$entry_price) & startsWith(dt$status, "NO_ACTION"))))
 }
 
 # Check date columns
 date_cols <- c("entry_date", "exit_date")
 for (col in date_cols) {
  if (any(is.na(dt[[col]]) & startsWith(dt$status, "NO_ACTION"))) {
   log_message(sprintf(" - Found %d rows with NA %s but non-NO_ACTION status",
            sum(is.na(dt[[col]]) & startsWith(dt$status, "NO_ACTION")),
            col))
  }
 }
 
 # Check for any non-finite values in numeric columns
 num_cols <- names(dt)[sapply(dt, is.numeric)]
 for (col in num_cols) {
  if (any(!is.finite(dt[[col]]), na.rm = TRUE)) {
   log_message(sprintf(" - Found %d non-finite values in %s",
            sum(!is.finite(dt[[col]])),
            col))
  }
 }
 
 # Log sample of data for debugging
 log_message("\nSample data for debugging:")
 sample_rows <- dt[sample(.N, min(5, .N))]
 print(sample_rows[, .(company_id, date, status, entry_price, exit_price, pnl_pct
 )])
 
 
 # Add stage name safely
 dt[, stage_name := {
  sapply(stage_ff, function(s) {
   if (is.na(s)) return(NA_character_)
   s_char <- as.character(s)
   if (s_char %in% names(stage_defs)) {
    return(stage_defs[[s_char]]$name)
   } else {
    log_message(paste0("Warning: No stage definition found for stage: ", s_char))
    return(NA_character_)
   }
  })
 }]
 
 # Create trade log safely
 dt[, trade_log := {
  sn <- sapply(stage_ff, function(s) {
   if (is.na(s)) return(NA_character_)
   s_char <- as.character(s)
   if (s_char %in% names(stage_defs)) {
    return(stage_defs[[s_char]]$name)
   } else {
    return(NA_character_)
   }
  })
  rs <- ""
  paste0("Stage: ", sn, " | Rules: ", rs)
 }]
 
 # set entry/exit price/date
 dt[startsWith(status, "ENTRY_"), `:=`(entry_price = close, entry_date = as.character(date))]
 dt[startsWith(status, "EXIT_"), `:=`(exit_price = close, exit_date = as.character(date))]
 
 # Handle entry/exit prices and dates with carry forward logic
 # First ensure entry_date and exit_date are Date type
 if (!is.null(dt$entry_date)) dt[, entry_date := as.Date(entry_date)]
 if (!is.null(dt$exit_date)) dt[, exit_date := as.Date(exit_date)]
 
 # Handle numeric columns with nafill
 dt[, `:=`(
  # Carry forward entry price until exit
  entry_price = nafill(as.numeric(entry_price), type = 'locf'),
  # Carry forward exit price if set
  exit_price = nafill(as.numeric(exit_price), type = 'locf')
 ), by = company_id]
 
 # Handle date columns with data.table's shift and fill
 dt[, `:=`(
  entry_date = {
   # Convert to integer for carry forward, then back to Date
   entry_int <- as.integer(entry_date)
   entry_int_filled <- nafill(entry_int, type = 'locf')
   as.Date(entry_int_filled, origin = '1970-01-01')
  },
  exit_date = {
   # Convert to integer for carry forward, then back to Date
   exit_int <- as.integer(exit_date)
   exit_int_filled <- nafill(exit_int, type = 'locf')
   as.Date(exit_int_filled, origin = '1970-01-01')
  }
 ), by = company_id]
 
 # Calculate PnL percentage using vectorized operations
 dt[, pnl_pct := {
  fifelse(!is.na(entry_price),
     fifelse(!is.na(exit_price),
         # For closed positions
         (exit_price - entry_price) / entry_price * 100,
         # For open positions
         (close - entry_price) / entry_price * 100),
     # If entry_price is NA
     NA_real_)
 }]
 
 dt[, stage_ff := NULL]
 return(dt)
}

generate_final_output <- function(dt, companies = NULL) {
 log_message("Generating final output...")
 
 # Ensure all required columns exist in the input data.table
 required_cols <- c("company_id", "stage", "best_partial_stage", "date", "open", "high", 
          "low", "close", "volume", "vol_21d", "vol_63d_avg", "volume_ratio",
          "status", "stage_age", "optimal_holding_days", "days_remaining",
          "entry_price", "entry_date", "exit_price", "exit_date",
          "stop_loss", "stop_pct", "take_profit", "take_profit_pct", "risk_reward",
          "block_trade", "institutional_support", "accumulation_day", "buying_pressure",
          "absorption", "volume_delta", "smart_money_score", "var_1d", 
          "max_drawdown_252d", "sharpe_ratio", "kelly_fraction", "rsi", "adx", "atr",
          "range_contraction", "overextension", "drawdown", "ma_21", "ma_50", "ma_63",
          "ma_126", "ma_252", "high_21d", "low_21d", "vol_factor", "momentum_factor",
          "time_factor", "progress_factor",
          "LOW_VOL", "TIGHT_RANGE_1DAY", "TIGHT_RANGE_3DAY", "VOL_DRYUP",
          "PRICE_BREAKOUT", "VOL_CONFIRM", "MOMENTUM",
          "ABOVE_MA21", "MA_CROSS", "REL_STRENGTH",
          "ABOVE_MA126", "MA_STACK", "STRONG_MOM", "LOW_DRAWDOWN",
          "OVEREXTENDED", "DIVERGENCE", "CLIMAX_VOL",
          "trade_log", "stage_history")
 
 # Initialize missing columns with appropriate defaults
 for (col in required_cols) {
  if (!col %in% names(dt)) {
   if (col %in% c("company_id", "status")) {
    dt[, (col) := as.character(NA)]
   } else if (col %in% c("open", "high", "low", "close", "volume", "vol_21d", "vol_63d_avg", 
             "volume_ratio", "entry_price", "exit_price", "stop_loss", "stop_pct",
             "take_profit", "take_profit_pct", "risk_reward", "buying_pressure",
             "volume_delta", "smart_money_score", "var_1d", "max_drawdown_252d",
             "sharpe_ratio", "kelly_fraction", "rsi", "adx", "atr", "range_contraction",
             "overextension", "drawdown", "ma_21", "ma_50", "ma_63", "ma_126", "ma_252",
             "high_21d", "low_21d", "vol_factor", "momentum_factor", "time_factor",
             "progress_factor", "pnl_pct")) {
    dt[, (col) := as.numeric(NA)]
   } else if (col %in% c("stage", "best_partial_stage", "stage_age", "optimal_holding_days",
             "days_remaining")) {
    dt[, (col) := as.integer(NA)]
   } else if (col %in% c("date", "entry_date", "exit_date")) {
    dt[, (col) := as.Date(NA)]
   } else if (col %in% c("block_trade", "institutional_support", "accumulation_day",
             "LOW_VOL", "TIGHT_RANGE_1DAY", "TIGHT_RANGE_3DAY", "VOL_DRYUP",
             "PRICE_BREAKOUT", "VOL_CONFIRM", "MOMENTUM",
             "ABOVE_MA21", "MA_CROSS", "REL_STRENGTH",
             "ABOVE_MA126", "MA_STACK", "STRONG_MOM", "LOW_DRAWDOWN",
             "OVEREXTENDED", "DIVERGENCE", "CLIMAX_VOL")) {
    dt[, (col) := 0L] # Initialize as integer with 0 (FALSE)
   } else if (col %in% c("trade_log", "stage_history", "risk_category")) {
    dt[, (col) := as.character(NA)]
   } else {
    dt[, (col) := NA] # Generic fallback
   }
   log_message(sprintf(" Initialized missing column: %s as %s", 
            col, class(dt[[col]])[1]), "DEBUG")
  }
 }
 
 # latest row per company (non-NA stage or partial)
 latest <- dt[!is.na(stage) | !is.na(best_partial_stage), .SD[.N], by = company_id]
 
 log_message(sprintf(" Processing %d companies with valid stages", nrow(latest)))
 
 # If companies data is provided and contains ticker column, join it
 if (!is.null(companies) && "ticker" %in% names(companies)) {
  # Ensure companies is a data.table
  if (!is.data.table(companies)) companies <- as.data.table(companies)
  # Join with companies to get ticker and name
  latest <- merge(latest, 
         companies[, .(company_id, ticker, name)], 
         by = "company_id", 
         all.x = TRUE)
 } else if (!"ticker" %in% names(latest)) {
  # If no ticker column, create a dummy one
  latest[, ticker := as.character(company_id)]
  if (!"name" %in% names(latest)) latest[, name := ticker]
 }
 
 # Ensure all required columns exist in the output
 for (col in required_cols) {
  if (!col %in% names(latest)) {
   latest[, (col) := NA]
   log_message(sprintf(" Added missing column to output: %s", col), "DEBUG")
  }
 }
 
 # Build output table with necessary fields
 out <- data.table(
  company_id = latest$company_id,
  ticker = if ("ticker" %in% names(latest)) latest$ticker else as.character(NA),
  name = if ("name" %in% names(latest)) latest$name else as.character(NA),
  date = latest$date,
  open = latest$open,
  high = latest$high,
  low = latest$low,
  close = latest$close,
  volume = latest$volume,
  stage = ifelse(!is.na(latest$stage), latest$stage, latest$best_partial_stage),
  stage_name = {
   sapply(seq_along(latest$stage), function(i) {
    s <- ifelse(!is.na(latest$stage[i]), latest$stage[i], latest$best_partial_stage[i])
    if (is.na(s)) return(NA_character_)
    s_char <- as.character(s)
    if (s_char %in% names(stage_defs)) {
     return(stage_defs[[s_char]]$name)
    } else {
     return(NA_character_)
    }
   })
  },
  status = latest$status,
  stage_age = latest$stage_age,
  optimal_holding_days = latest$optimal_holding_days,
  days_remaining = latest$days_remaining,
  entry_price = latest$entry_price,
  entry_date = latest$entry_date,
  exit_price = latest$exit_price,
  exit_date = latest$exit_date,
  pnl_pct = latest$pnl_pct,
  stop_loss = latest$stop_loss,
  stop_pct = latest$stop_pct,
  take_profit = latest$take_profit,
  take_profit_pct = latest$take_profit_pct,
  risk_reward = latest$risk_reward,
  vol_21d_avg = latest$vol_21d,
  vol_63d_avg = latest$vol_63d_avg,
  volume_ratio = latest$volume_ratio,
  vol_vs_avg = (latest$volume / (latest$vol_21d + 1e-9) - 1) * 100,
  block_trade = latest$block_trade,
  institutional_support = latest$institutional_support,
  accumulation_day = latest$accumulation_day,
  buying_pressure = latest$buying_pressure,
  absorption = latest$absorption,
  ofi = NA_real_,
  volume_delta = latest$volume_delta,
  hidden_accumulation = NA,
  smart_money_score = latest$smart_money_score,
  risk_score = NA_real_,
  risk_category = NA_character_,
  var_1d = latest$var_1d,
  max_drawdown = ifelse(!is.na(latest$max_drawdown_252d), latest$max_drawdown_252d * 100, NA_real_),
  sharpe_ratio = latest$sharpe_ratio,
  kelly_fraction = latest$kelly_fraction,
  rsi = latest$rsi,
  adx = latest$adx,
  atr = latest$atr,
  vol_21d = ifelse(!is.na(latest$vol_21d), latest$vol_21d * 100, NA_real_),
  range_contraction = ifelse(!is.na(latest$range_contraction), latest$range_contraction * 100, NA_real_),
  overextension = ifelse(!is.na(latest$overextension), latest$overextension * 100, NA_real_),
  drawdown = ifelse(!is.na(latest$drawdown), latest$drawdown * 100, NA_real_),
  ma_21 = latest$ma_21,
  ma_50 = latest$ma_50,
  ma_63 = latest$ma_63,
  ma_126 = latest$ma_126,
  ma_252 = latest$ma_252,
  high_21d = latest$high_21d,
  low_21d = latest$low_21d,
  pct_from_21d_high = ifelse(!is.na(latest$close) & !is.na(latest$high_21d) & latest$high_21d > 0,
               (latest$close / latest$high_21d - 1) * 100, NA_real_),
  pct_from_21d_low = ifelse(!is.na(latest$close) & !is.na(latest$low_21d) & latest$low_21d > 0,
              (latest$close / latest$low_21d - 1) * 100, NA_real_),
  vol_factor = latest$vol_factor,
  momentum_factor = latest$momentum_factor,
  time_factor = latest$time_factor,
  progress_factor = ifelse(!is.na(latest$progress_factor), pmax(0, latest$progress_factor * 100), NA_real_),

  # Stage-specific rules (as integer columns)
  LOW_VOL = latest$LOW_VOL,
  TIGHT_RANGE_1DAY = latest$TIGHT_RANGE_1DAY,
  TIGHT_RANGE_3DAY = latest$TIGHT_RANGE_3DAY,
  VOL_DRYUP = latest$VOL_DRYUP,
  PRICE_BREAKOUT = latest$PRICE_BREAKOUT,
  VOL_CONFIRM = latest$VOL_CONFIRM,
  MOMENTUM = latest$MOMENTUM,
  ABOVE_MA21 = latest$ABOVE_MA21,
  MA_CROSS = latest$MA_CROSS,
  REL_STRENGTH = latest$REL_STRENGTH,
  ABOVE_MA126 = latest$ABOVE_MA126,
  MA_STACK = latest$MA_STACK,
  STRONG_MOM = latest$STRONG_MOM,
  LOW_DRAWDOWN = latest$LOW_DRAWDOWN,
  OVEREXTENDED = latest$OVEREXTENDED,
  DIVERGENCE = latest$DIVERGENCE,
  CLIMAX_VOL = latest$CLIMAX_VOL,
  trade_log = latest$trade_log,
  stage_history = latest$stage_history
 )
 
 # format trade_summary
 # Safely format trade summary with proper error handling
 out[, trade_summary := {
  tryCatch({
   sprintf("STAGE%d:%s %s @%.2f | DAY:%d/%d | PNL:%.1f%% | R:R %.2f | STOP:%.1f%% | TARGET:%.1f%%",
       stage, stage_name, status, close, stage_age, optimal_holding_days,
       ifelse(is.na(pnl_pct), 0, pnl_pct),
       ifelse(is.na(risk_reward), 0, risk_reward),
       ifelse(is.na(stop_pct), 0, stop_pct),
       ifelse(is.na(take_profit_pct), 0, take_profit_pct))
  }, error = function(e) {
   log_message(sprintf("Error formatting trade summary: %s", e$message), "ERROR")
   return(NA_character_)
  })
 }]
 
 # set order of important columns (removed entry_price and exit_price as they're already in the data.table)
 setcolorder(out, c("ticker", "date", "close", "volume", "status", "stage", "stage_name", "stage_age", "optimal_holding_days",
          "days_remaining", "pnl_pct", "risk_reward", "stop_loss", "stop_pct", "take_profit",
          "take_profit_pct", "smart_money_score", "institutional_support", "accumulation_day",
          "risk_score", "risk_category", "max_drawdown", "sharpe_ratio", "rsi", "adx", "atr", "vol_21d",
          "range_contraction", "trade_summary", "trade_log", "stage_history"))
 return(out)
}

# --- Main execution ---------------------------------------------------------
# ============================================================================
# 5. MAIN EXECUTION
# ============================================================================

#' Main Execution Function
#' 
#' Orchestrates the entire momentum signal generation pipeline.
#' @return Invisible NULL
#' @details
#' The main execution flow:
#' 1. Initialize logging and timing
#' 2. Establish database connection (if configured)
#' 3. Load and prepare data
#' 4. Calculate technical indicators
#' 5. Evaluate trading rules
#' 6. Assign momentum stages
#' 7. Calculate dynamic price levels
#' 8. Generate final output
#' 9. Save results to database and/or CSV
main <- function() {
 # 6.1 Initialization
 log_message("Momentum cycle signal generation (v2) starting")
 start_time <- Sys.time()
 
 # Debug: Print session info
 log_message("Session Info:")
 log_message(sessionInfo()$R.version$version.string)
 log_message(sprintf("Working directory: %s", getwd()))
 log_message(sprintf("File exists: %s", file.exists("/Users/chanderbhushan/stockmkt/data_ingestion/Rscripts/momentum_refined.R")))
 log_message(sprintf("File size: %d bytes", file.info("/Users/chanderbhushan/stockmkt/data_ingestion/Rscripts/momentum_refined.R")$size))

 # Parse command line arguments
 args <- commandArgs(trailingOnly = TRUE)
 if (length(args) > 0) {
  ref_date <- tryCatch({
   as.Date(args[1])
  }, error = function(e) {
   log_message(sprintf("Invalid date format: %s. Using today's date.", args[1]), "WARN")
   Sys.Date()
  })
 } else {
  # Default to today's date if no argument provided
  ref_date <- Sys.Date()
 }
 log_message(sprintf("Using reference date: %s", format(ref_date, "%Y-%m-%d")))

 # 6.2 Database Connection
 con <- NULL
 tryCatch({
  con <- get_db_con()
  if (!is.null(con)) {
   log_message("Successfully connected to the database")
  }
 }, error = function(e) {
  log_message(sprintf("Database connection error: %s", e$message), "WARN")
 })

 # 6.3 Data Loading
 log_message("Loading data...")

 # Try to load from database first
 if (!is.null(con)) {
  tryCatch({
   log_message("Loading companies and prices from DB")
   
   # Load companies
   companies <- data.table::as.data.table(DBI::dbReadTable(con, "companies"))
   log_message(sprintf("Loaded %d companies", nrow(companies)))
   
   # Load prices with date filtering
   query <- sprintf(
    "SELECT * FROM prices WHERE date <= '%s' ORDER BY company_id, date",
    format(ref_date, "%Y-%m-%d")
   )
   log_message(sprintf("Executing query: %s", query))
   
   prices <- data.table::as.data.table(DBI::dbGetQuery(con, query))
   log_message(sprintf("Fetched %d price records up to %s", nrow(prices), format(ref_date, "%Y-%m-%d")))
   
  }, error = function(e) {
   log_message(sprintf("Error loading from database: %s", e$message), "ERROR")
   con <- NULL # Force fallback to CSV
  })
 }
 
 # Fallback to CSV if DB load failed or no connection
 if (is.null(con) || !exists("companies") || !exists("prices")) {
  log_message("Falling back to CSV files", "WARN")
  if (file.exists("companies.csv") && file.exists("prices.csv")) {
   log_message("Loading companies.csv and prices.csv from working directory")
   companies <- data.table::fread("companies.csv")
   prices <- data.table::fread("prices.csv")
  } else {
   stop("No DB connection and CSV fallback not found. Provide DB env vars or companies.csv & prices.csv.")
  }
 }
 
 # 6.4 Data Preparation and Merging
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
  
  # Ensure we only keep the volume column from prices
  price_cols <- setdiff(names(prices), c("company_id", "date")) # Exclude join columns
  
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
 
 # 6.5 Run Pipeline Steps
 log_message("Starting pipeline execution...")
 
 tryCatch({
  # Track timing for each step
  step_start <- Sys.time()
  
  # 6.5.1 Data Validation
  log_message("Validating data structure...")
  
  # Check for required columns
  required_cols <- c("company_id", "date", "open", "high", "low", "close", "volume")
  missing_cols <- setdiff(required_cols, names(dt))
  
  if (length(missing_cols) > 0) {
   log_message(sprintf("Missing required columns: %s", paste(missing_cols, collapse = ", ")), "ERROR")
   log_message("Available columns:", "INFO")
   log_message(paste(names(dt), collapse = ", "), "INFO")
   stop("Input data is missing required price/volume columns")
  }
  
  # Check for NA values in critical columns
  na_check <- sapply(dt[, ..required_cols], function(x) sum(is.na(x)))
  if (any(na_check > 0)) {
   log_message("NA values found in critical columns:", "WARN")
   log_message(paste0(names(na_check), ": ", na_check, " (", 
            round(na_check/nrow(dt)*100, 2), "%)", 
            collapse = "\n"), "WARN")
   
   # Log sample of rows with NA values for debugging
   na_rows <- dt[is.na(company_id) | is.na(date) | is.na(close) | is.na(volume)]
   if (nrow(na_rows) > 0) {
    log_message(sprintf("Sample of rows with NA values (showing first 5):"), "WARN")
    log_message(capture.output(print(na_rows[1:min(5, nrow(na_rows)), .(company_id, date, close, volume)])), "WARN")
   }
   
   # Check for zero or negative prices/volumes
   invalid_prices <- dt[!is.na(close) & close <= 0, .N]
   invalid_volumes <- dt[!is.na(volume) & volume <= 0, .N]
   
   if (invalid_prices > 0) {
    log_message(sprintf("Found %d rows with zero or negative prices", invalid_prices), "WARN")
   }
   if (invalid_volumes > 0) {
    log_message(sprintf("Found %d rows with zero or negative volumes", invalid_volumes), "WARN")
   }
  }
  
  # 6.5.2 Calculate Indicators
  log_message("Step 1/6: Calculating technical indicators...")
  dt <- calculate_indicators(dt)
  log_message(sprintf("  Calculated indicators for %d rows", nrow(dt)))
  
  # Keep all data in dt for calculations, we'll filter to ref_date at the end
  
  # 6.5.2 Evaluate Rules (on full dataset)
  log_message("Step 2/6: Evaluating trading rules...")
  dt <- evaluate_rules(dt)
  log_message("  Trading rules evaluated")
  
  # 6.5.3 Assign Stages
  log_message("Step 3/6: Assigning momentum stages...")
  dt <- assign_stage(dt)
  log_message(sprintf("  Assigned stages. Distribution: %s", 
           paste(table(dt$stage, useNA = "ifany"), collapse = ", ")))
  
  # 6.5.4 Add Stage History
  log_message("Step 4/6: Adding stage history...")
  dt <- add_stage_history(dt)
  log_message("  Stage history added")
  
  # 6.5.5 Calculate Dynamic Levels
  log_message("Step 5/6: Calculating dynamic price levels...")
  dt <- calculate_dynamic_levels(dt)
  log_message("  Dynamic levels calculated")
  
  # 6.5.6 Add Metadata
  log_message("Step 6/6: Adding metadata...")
  dt <- add_metadata(dt)
  log_message("  Metadata added")
  
  # 6.7 Generate Final Output
  log_message("Generating final output...")
  
  # Ensure all columns are properly initialized and not NULL
  log_message("Ensuring all columns are properly initialized...", "DEBUG")
  
  # Fix NULL status column if it exists
  if ("status" %in% names(dt) && is.null(dt$status)) {
   log_message("Initializing NULL status column with 'NO_SIGNAL'", "WARN")
   dt[, status := "NO_SIGNAL"]
  }
  
  # Check for NULL or NA columns and handle them
  # 1. Check for completely NULL columns
  null_cols <- sapply(dt, function(x) all(is.null(x)))
  
  # 2. Check for columns with any NA values
  na_cols <- sapply(dt, function(x) any(is.na(x)))
  
  # 3. Get column types for better reporting
  col_types <- sapply(dt, class)
  
  # Report columns with any NAs
  if (any(na_cols)) {
   na_cols_info <- data.table(
    column = names(na_cols[na_cols]),
    type = col_types[na_cols],
    na_count = sapply(dt[, which(na_cols), with = FALSE], function(x) sum(is.na(x))),
    pct_na = sapply(dt[, which(na_cols), with = FALSE], function(x) round(mean(is.na(x)) * 100, 2))
   )
   
   # Sort by NA count (descending)
   setorder(na_cols_info, -na_count)
   
   # Log top 20 columns with most NAs
   log_message("Columns with NA values:", "INFO")
   log_message(capture.output(print(na_cols_info, topn = 20)), "INFO")
   
   # Initialize columns with NAs based on their type
   for (col in names(na_cols[na_cols])) {
    if (is.numeric(dt[[col]])) {
     dt[is.na(get(col)), (col) := 0]
    } else if (is.character(dt[[col]])) {
     dt[is.na(get(col)), (col) := ""]
    } else if (is.logical(dt[[col]])) {
     dt[is.na(get(col)), (col) := FALSE]
    } else if (inherits(dt[[col]], "Date")) {
     # Leave as NA for dates
     next
    } else {
     dt[is.na(get(col)), (col) := NA]
    }
   }
   log_message("Initialized NA values with appropriate defaults", "INFO")
  } else {
   log_message("No NA values found in the dataset", "DEBUG")
  }
  
  # Proceed with final output generation
  output <- generate_final_output(dt, companies)
  log_message(sprintf("Generated output with %d rows and %d columns", 
           nrow(output), ncol(output)))
  
  # 6.7 Save complete dataset for debugging
  #log_message(sprintf("Saving complete dataset with %d rows to 'momentum_cycle_signals_full' table...", nrow(dt)))
  #DBI::dbWriteTable(con, "momentum_cycle_signals_full", dt, overwrite = TRUE)
  #log_message("Complete dataset saved successfully")
  
  # 6.8 Filter to reference date and save to production table
  log_message(sprintf("Filtering to reference date: %s before saving", ref_date))
  dt_ref <- dt[date == ref_date]
  
  if (nrow(dt_ref) == 0) {
   stop(sprintf("No data found for reference date: %s", ref_date))
  }
  
  # 6.9 Save filtered Results to production table
  log_message("Saving filtered results to production table...")
  log_message(sprintf("Saving %d rows to 'momentum_cycle_signals' table...", nrow(dt_ref)))
  DBI::dbWriteTable(con, "momentum_cycle_signals", dt_ref, overwrite = TRUE)
  
  
  # 6.7.2 Save to CSV
  if (!dir.exists("output")) {
   dir.create("output", recursive = TRUE)
   log_message("Created output directory")
  }
  log_message("  Data saved to database")
 })
 
   # Log completion
 elapsed <- as.numeric(difftime(Sys.time(), step_start, units = "secs"))
 log_message(sprintf("Pipeline completed successfully in %.1f seconds", elapsed))
 
 # Final stats
log_message(paste(rep("=", 50), collapse = ""))
 log_message("KEY METRICS")
 log_message(paste(rep("-", 50), collapse = ""))
 log_message(sprintf("Total Signals Generated: %d", nrow(output)))
 
 # Get all status values and their counts
 if (nrow(output) > 0 && "status" %in% names(output)) {
  status_counts <- table(output$status, useNA = "ifany")
  log_message("\nSIGNAL STATUS DISTRIBUTION")
  log_message(paste(rep("-", 50), collapse = ""))
  for (status in names(status_counts)) {
   log_message(sprintf("%s: %d (%.1f%%)", 
            ifelse(is.na(status), "<NA>", status),
            status_counts[status],
            status_counts[status] / nrow(output) * 100))
  }
  
  # Show the sum of all status counts for verification
  log_message(sprintf("\nTotal status counts: %d", sum(status_counts)))
  log_message(sprintf("Difference from total rows: %d", nrow(output) - sum(status_counts)))
  
  # Check for any unexpected status values
  expected_status <- c("ENTRY", "EXIT", "HOLD")
  unexpected_status <- setdiff(names(status_counts), expected_status)
  
  if (length(unexpected_status) > 0) {
   log_message(sprintf("\nWARNING: Found unexpected status values: %s", 
            paste(unexpected_status, collapse = ", ")), "WARN")
   
   # Analyze NA statuses in detail
   if (any(is.na(output$status))) {
    na_status <- output[is.na(status)]
    log_message("\nDETAILED ANALYSIS OF MISSING STATUSES", "WARN")
    log_message(paste(rep("-", 50), collapse = ""), "WARN")
    
    # Count NAs by stage
    na_by_stage <- na_status[, .(count = .N), by = .(stage)]
    na_by_stage <- na_by_stage[order(stage)]
    
    log_message("Missing status count by stage:", "WARN")
    for (i in 1:nrow(na_by_stage)) {
     log_message(sprintf("Stage %d: %d (%.1f%% of stage, %.1f%% of all NAs)",
              na_by_stage$stage[i],
              na_by_stage$count[i],
              na_by_stage$count[i] / nrow(output[stage == na_by_stage$stage[i]]) * 100,
              na_by_stage$count[i] / nrow(na_status) * 100), "WARN")
    }
    
    # Check if these rows have any signal flags set
    signal_cols <- c("is_entry", "is_exit", "is_watch")
    if (all(signal_cols %in% names(na_status))) {
     log_message("\nSignal flags in rows with missing status:", "WARN")
     log_message(sprintf(" Rows with is_entry = TRUE: %d", sum(na_status$is_entry, na.rm = TRUE)), "WARN")
     log_message(sprintf(" Rows with is_exit = TRUE: %d", sum(na_status$is_exit, na.rm = TRUE)), "WARN")
     log_message(sprintf(" Rows with is_watch = TRUE: %d", sum(na_status$is_watch, na.rm = TRUE)), "WARN")
     log_message(sprintf(" Rows with no signal flags: %d", 
              nrow(na_status[is.na(is_entry) & is.na(is_exit) & is.na(is_watch)])), "WARN")
    }
   }
  }
  
  all_stages <- factor(output$stage, levels = 0:5)
  stage_counts <- table(all_stages, useNA = "ifany")
  
  # Create a more detailed stage distribution
  stage_dist <- data.table(
   Stage = 0:5,
   Name = c("SETUP", "BREAKOUT", "EARLY_MOM", "SUSTAINED", "EXTENDED", "DISTRIBUTION"),
   Count = as.numeric(stage_counts[as.character(0:5)])
  )
  
  # Replace NA with 0 for any missing stages
  stage_dist[is.na(Count), Count := 0]
  
  # Add percentage
  stage_dist[, Pct := round(Count / nrow(output) * 100, 1)]
  
  # Get close-to-stage distribution
  close_to_stage <- rep(0, 6) # Initialize for stages 0-5
  close_matches <- grepl("CLOSE_TO_STAGE_([0-5])", output$status, perl = TRUE)
  if (any(close_matches)) {
   close_stages <- as.integer(gsub(".*CLOSE_TO_STAGE_([0-5]).*", "\\1", output$status[close_matches]))
   close_counts <- table(factor(close_stages, levels = 0:5))
   close_to_stage[as.integer(names(close_counts)) + 1] <- as.numeric(close_counts)
  }
  stage_dist[, CloseToCount := close_to_stage]
  stage_dist[, CloseToPct := round(CloseToCount / nrow(output) * 100, 1)]
  
  # Log detailed stage distribution
  log_message("\nDETAILED STAGE DISTRIBUTION")
  log_message(paste(rep("=", 80), collapse = ""))
  log_message(sprintf("%-10s %-15s %10s %8s %15s %8s", 
           "Stage", "Name", "Count", "Pct %", "Close To Count", "Pct %"))
  log_message(paste(rep("-", 60), collapse = ""))
  
  # Log each stage with details
  for (i in 1:nrow(stage_dist)) {
   log_message(sprintf("%-10d %-15s %10d %7.1f%% %15d %7.1f%%",
            stage_dist$Stage[i],
            stage_dist$Name[i],
            stage_dist$Count[i],
            stage_dist$Pct[i],
            stage_dist$CloseToCount[i],
            stage_dist$CloseToPct[i]))
  }
  
  # Log totals for verification
  log_message(paste(rep("-", 60), collapse = ""))
  log_message(sprintf("%-10s %-15s %10d %7.1f%% %15d %7.1f%%",
           "TOTAL", "",
           sum(stage_dist$Count), 
           sum(stage_dist$Pct),
           sum(stage_dist$CloseToCount),
           sum(stage_dist$CloseToPct)))
  
  # Log summary
  log_message("\nSTAGE SUMMARY")
  log_message(paste(rep("-", 50), collapse = ""))
  log_message(sprintf("Total signals: %d", nrow(output)))
  log_message(sprintf("Stocks in setup (0): %d (%.1f%%)", 
           stage_dist$Count[1], stage_dist$Pct[1]))
  log_message(sprintf("Stocks in momentum (1-3): %d (%.1f%%)",
           sum(stage_dist$Count[2:4]),
           sum(stage_dist$Pct[2:4])))
  log_message(sprintf("Stocks extended/distributing (4-5): %d (%.1f%%)",
           sum(stage_dist$Count[5:6]),
           sum(stage_dist$Pct[5:6])))
  log_message(sprintf("Stocks close to next stage: %d (%.1f%%)",
           sum(stage_dist$CloseToCount),
           sum(stage_dist$CloseToPct)))
 }
 
 # Data processing summary
 log_message("\nDATA PROCESSING")
 log_message(paste(rep("-", 50), collapse = ""))
 log_message(sprintf("Processed %d companies", length(unique(dt$company_id))))
 log_message(sprintf("Analyzed %d price records", nrow(dt)))
 log_message(paste(rep("=", 50), collapse = ""))
 
 # Clean up DB connection
 if (!is.null(con)) {
  dbDisconnect(con)
  log_message("DB connection closed")
 }
 
 elapsed_total <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 2)
 log_message(paste("All done in", elapsed_total, "seconds"))
 
 return(invisible(output))
}

# ============================================================================
# 5. SCRIPT EXECUTION
# ============================================================================

# 5.1 Main Execution Block
# ----------------------------------------------------------------------------
# Only execute if run as a script (not sourced)
if (identical(environment(), globalenv())) {
 tryCatch({
  # 5.1.1 Execute Main Function
  main_output <- main()
  
  # 5.1.2 Final Status
  log_message("Script completed successfully", "SUCCESS")
 }, error = function(e) {
   # 5.1.3 Error Handling
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
   
   # Print stack trace for debugging
   if (exists(".traceback")) {
     log_message("Stack trace:", "ERROR")
     log_message(utils::capture.output(print(.traceback())), "ERROR")
   }
   
   # Additional error handling (e.g., cleanup, notifications)
   if (exists("con") && DBI::dbIsValid(con)) {
     tryCatch({
       DBI::dbDisconnect(con)
       log_message("Database connection closed due to error")
     }, error = function(e) {
       log_message(sprintf("Error closing database connection: %s", e$message), "ERROR")
     })
   }
   
   # Re-throw the error to ensure proper exit code
   stop(simpleError(error_msg, call = sys.calls()[[1]]))
})
}
