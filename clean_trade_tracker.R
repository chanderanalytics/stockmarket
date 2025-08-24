# Clean Trade Tracker
# This script processes signals to generate trades from scratch
library(data.table)
library(lubridate)

# Setup logging
log_message <- function(msg, level = "INFO") {
  cat(paste0("[", Sys.time(), "] [", level, "] ", msg, "\n"))
}

# Load and prepare data
log_message("Loading momentum signals data...")
# Input file path - using the full momentum signals file
data_file <- "/Users/chanderbhushan/stockmkt/output/momentum_cycle_signals_full.csv"
if (!file.exists(data_file)) {
  stop("Momentum signals file not found: ", data_file)
}

dt <- fread(data_file)
log_message(sprintf("Loaded %d rows from %s", nrow(dt), data_file))

# Ensure proper data types
dt[, date := as.Date(date)]
# Convert IDate columns to character to avoid type conflicts
data.table::set(dt, j = "entry_date", value = as.character(dt$entry_date))
data.table::set(dt, j = "exit_date", value = as.character(dt$exit_date))
data.table::setorder(dt, company_id, date)

# Initialize trade tracking columns with proper NAs
dt[, `:=`(
  entry_price = NA_real_,
  exit_price = NA_real_,
  pnl_pct = NA_real_,
  trade_active = FALSE
)]

# Function to process trades from signals
process_trades_from_signals <- function(dt) {
  log_message("Processing trades from signals...")
  
    # Process each company separately
  result_list <- list()
  
  for (comp_id in unique(dt$company_id)) {
    comp_data <- dt[company_id == comp_id]
    log_message(sprintf("Processing company: %s", comp_id))
    
    # Initialize variables
    in_trade <- FALSE
    entry_px <- NA_real_
    entry_dt <- as.character(NA)
    
    # Process each day in order
    for (i in 1:nrow(comp_data)) {
      current_status <- comp_data$status[i]
      
      # Check for entry signal (only if not in a trade)
      if (!in_trade && !is.na(current_status) && startsWith(current_status, "ENTRY_")) {
        in_trade <- TRUE
        entry_px <- comp_data$close[i]
        
        # Set entry price and date
        entry_px <- comp_data$close[i]
        entry_dt <- as.character(comp_data$date[i])
        data.table::set(comp_data, i, "entry_price", entry_px)
        data.table::set(comp_data, i, "entry_date", entry_dt)
        data.table::set(comp_data, i, "trade_active", TRUE)
        
        log_message(sprintf("  [%s] NEW TRADE ENTRY at %.2f", 
                           comp_data$date[i], entry_px))
      }
      
      # If in a trade, update the trade
      if (in_trade) {
        # Calculate current P&L
        current_pnl <- (comp_data$close[i] / entry_px - 1) * 100
        
        # Update current trade info
        data.table::set(comp_data, i, "entry_price", entry_px)
        data.table::set(comp_data, i, "entry_date", entry_dt)
        data.table::set(comp_data, i, "trade_active", TRUE)
        data.table::set(comp_data, i, "pnl_pct", current_pnl)
        
        # Clear exit values if they exist
        if (!is.na(comp_data$exit_price[i])) {
          data.table::set(comp_data, i, "exit_price", NA_real_)
          data.table::set(comp_data, i, "exit_date", NA_character_)
        }
        
        # Check for exit signal
        if (!is.na(current_status) && startsWith(current_status, "EXIT_")) {
          in_trade <- FALSE
          exit_px <- comp_data$close[i]
          
          # Set exit price and date
          data.table::set(comp_data, i, "exit_price", exit_px)
          data.table::set(comp_data, i, "exit_date", as.character(comp_data$date[i]))
          data.table::set(comp_data, i, "trade_active", FALSE)
          
          # Also ensure entry info is set for the exit row
          data.table::set(comp_data, i, "entry_price", entry_px)
          data.table::set(comp_data, i, "entry_date", entry_dt)
          
          # Clear entry values in the next row if it exists
          if (i < nrow(comp_data)) {
            data.table::set(comp_data, i + 1, "entry_price", NA_real_)
            data.table::set(comp_data, i + 1, "entry_date", NA_character_)
          }
          
          log_message(sprintf("  [%s] TRADE EXIT at %.2f (PnL: %.2f%%)", 
                             comp_data$date[i], exit_px, current_pnl))
        }
      }
    }
    
    result_list[[as.character(comp_id)]] <- comp_data
  }
  
  # Combine results
  rbindlist(result_list)
}

# Run the trade processor
result_dt <- process_trades_from_signals(dt)

# Save results
output_file <- "/Users/chanderbhushan/stockmkt/cleaned_trade_analysis.csv"
cleaned_data <- copy(result_dt)
cleaned_data[is.na(entry_price), entry_date := NA_character_]
cleaned_data[is.na(exit_price), exit_date := NA_character_]
fwrite(cleaned_data, output_file)
log_message(sprintf("Results saved to %s", output_file))

# Generate trade summary
generate_trade_summary <- function(dt) {
  log_message("\nGenerating trade summary...")
  
  # Create a clean data table with trade information
  trades <- data.table(
    company_id = character(),
    entry_date = as.Date(character()),
    entry_price = numeric(),
    entry_stop_loss = numeric(),
    exit_date = as.Date(character()),
    exit_price = numeric(),
    exit_stop_loss = numeric(),
    pnl_pct = numeric(),
    days_held = integer(),
    status = character(),
    day_return = numeric(),
    annualized_return = numeric(),
    entry_trade_summary = character(),
    entry_status = character(),
    exit_trade_summary = character(),
    exit_status = character()
  )
  
  # Process each company separately
  for (comp_id in unique(dt$company_id)) {
    comp_data <- dt[company_id == comp_id]
    
    # Initialize variables
    in_trade <- FALSE
    current_trade <- NULL
    
    # Process each day in order
    for (i in 1:nrow(comp_data)) {
      current_row <- comp_data[i]
      
      # Check for entry signal (only if not in a trade)
      if (!in_trade && !is.na(current_row$entry_price) && current_row$entry_price > 0) {
        in_trade <- TRUE
        current_trade <- list(
          company_id = comp_id,
          entry_date = as.Date(current_row$date),
          entry_price = current_row$entry_price,
          entry_stop_loss = ifelse(!is.null(current_row$stop_loss), current_row$stop_loss, NA_real_),
          entry_close = current_row$close,
          entry_trade_summary = ifelse(!is.null(current_row$trade_summary), current_row$trade_summary, ""),
          entry_status = ifelse(!is.null(current_row$status), current_row$status, "")
        )
      }
      
      # If in a trade, check for exit signal
      if (in_trade && !is.na(current_row$exit_price) && current_row$exit_price > 0) {
        # Calculate trade metrics
        exit_price <- current_row$exit_price
        pnl_pct <- (exit_price / current_trade$entry_close - 1) * 100
        days_held <- as.integer(as.Date(current_row$date) - current_trade$entry_date) + 1
        
        # Calculate additional metrics
        AbsolutePL <- (exit_price - current_trade$entry_price) * 1  # Assuming 1 share for now
        day_return <- ifelse(days_held > 0, AbsolutePL / days_held, 0)
        annualized_return <- ifelse(days_held > 0, (day_return * 252) / current_trade$entry_price * 100, 0)
        
        # Get the stop loss from the previous day
        prev_day_stop_loss <- if (i > 1) comp_data[i-1, stop_loss] else NA_real_
        
        # Calculate price range metrics
        trade_data <- comp_data[date >= current_trade$entry_date & date <= current_row$date]
        max_price <- max(trade_data$high, na.rm = TRUE)
        min_price <- min(trade_data$low, na.rm = TRUE)
        price_range_pct <- (max_price - min_price) / current_trade$entry_price * 100
        
        # Calculate conventional drawdown
        running_max <- cummax(trade_data$close)
        drawdowns <- (running_max - trade_data$close) / running_max * 100
        max_drawdown <- if (length(drawdowns) > 0) max(drawdowns, na.rm = TRUE) else 0
        
        # Add to trades table
        trades <- rbind(trades, data.table(
          company_id = comp_id,
          entry_date = current_trade$entry_date,
          entry_price = current_trade$entry_price,
          entry_stop_loss = current_trade$entry_stop_loss,
          exit_date = as.Date(current_row$date),
          exit_price = exit_price,
          exit_stop_loss = prev_day_stop_loss,
          pnl_pct = pnl_pct,
          days_held = days_held,
          status = ifelse(pnl_pct > 0, "WIN", "LOSS"),
          AbsolutePL = AbsolutePL,
          day_return = day_return,
          annualized_return = annualized_return,
          entry_trade_summary = current_trade$entry_trade_summary,
          entry_status = current_trade$entry_status,
          exit_trade_summary = current_row$trade_summary,
          exit_status = current_row$status,
          AbsolutePL_cum = 0,
          PercCumulativePL = 0,
          high_water_mark = max_price,
          max_drawdown = max_drawdown,
          price_range_pct = price_range_pct,
          running_max = max_price,
          drawdown = 0
        ), fill = TRUE)
        
        # Reset for next trade
        in_trade <- FALSE
        current_trade <- NULL
      }
    }
    
    # Handle any open trade at the end of data
    if (in_trade && !is.null(current_trade)) {
      last_row <- comp_data[nrow(comp_data)]
      pnl_pct <- (last_row$close / current_trade$entry_close - 1) * 100
      days_held <- as.integer(as.Date(last_row$date) - current_trade$entry_date) + 1
      
      # Calculate additional metrics for open trades
      AbsolutePL <- (last_row$close - current_trade$entry_price) * 1  # Assuming 1 share for now
      day_return <- ifelse(days_held > 0, AbsolutePL / days_held, 0)
      annualized_return <- ifelse(days_held > 0, (day_return * 252) / current_trade$entry_price * 100, 0)
      
      trades <- rbind(trades, data.table(
        company_id = comp_id,
        entry_date = current_trade$entry_date,
        entry_price = current_trade$entry_price,
        entry_stop_loss = current_trade$entry_stop_loss,
        exit_date = as.Date(NA),
        exit_price = NA_real_,
        exit_stop_loss = NA_real_,
        pnl_pct = pnl_pct,
        days_held = days_held,
        status = "OPEN",
        AbsolutePL = AbsolutePL,
        day_return = day_return,
        annualized_return = annualized_return,
        entry_trade_summary = current_trade$entry_trade_summary,
        entry_status = current_trade$entry_status,
        exit_trade_summary = "",
        exit_status = "",
        AbsolutePL_cum = 0,
        PercCumulativePL = 0,
        high_water_mark = last_row$high,
        max_drawdown = 0,
        price_range_pct = 0,
        running_max = last_row$high,
        drawdown = 0
      ), fill = TRUE)
    }
  }
  
  # Calculate summary statistics if we have trades
  if (nrow(trades) > 0) {
    # Ensure all numeric columns are properly typed
    numeric_cols <- c('AbsolutePL', 'AbsolutePL_cum', 'PercCumulativePL', 'high_water_mark', 
                     'max_drawdown', 'price_range_pct', 'running_max', 'drawdown')
    for (col in numeric_cols) {
      if (col %in% names(trades)) {
        trades[, (col) := as.numeric(get(col))]
      }
    }
    
    # Add cumulative PnL by company
    trades <- trades[order(company_id, entry_date)]
    trades[, AbsolutePL_cum := cumsum(AbsolutePL), by = company_id]
    
    # Calculate percentage cumulative P&L
    trades[, PercCumulativePL := {
      if (.N > 0) {
        cumprod(1 + pnl_pct/100) - 1
      } else {
        numeric(0)
      }
    }, by = company_id]
    
    # Basic metrics
    total_trades <- nrow(trades)
    winning_trades <- nrow(trades[status == "WIN"])
    losing_trades <- nrow(trades[status == "LOSS"])
    open_trades <- nrow(trades[status == "OPEN"])
    
    win_rate <- if (total_trades > 0) winning_trades / total_trades * 100 else 0
    avg_pnl <- mean(trades$pnl_pct, na.rm = TRUE)
    avg_win <- if (winning_trades > 0) mean(trades[status == "WIN"]$pnl_pct, na.rm = TRUE) else 0
    avg_loss <- if (losing_trades > 0) mean(trades[status == "LOSS"]$pnl_pct, na.rm = TRUE) else 0
    
    # Risk metrics
    profit_factor <- if (losing_trades > 0) 
      abs(sum(trades[status == "WIN"]$pnl_pct) / sum(trades[status == "LOSS"]$pnl_pct)) 
      else Inf
      
    # Calculate max drawdown per company
    trades[, high_water_mark := cummax(PercCumulativePL), by = company_id]
    trades[, drawdown := high_water_mark - PercCumulativePL]
    max_drawdown <- max(trades$drawdown, na.rm = TRUE)
    
    # Calculate risk-adjusted returns
    risk_free_rate <- 0  # Can be adjusted
    returns <- trades$pnl_pct / 100  # Convert to decimal
    sharpe_ratio <- if (sd(returns) > 0) (mean(returns) - risk_free_rate) / sd(returns) * sqrt(252) else 0
    
    # Sortino ratio (only downside deviation)
    downside_returns <- returns[returns < 0]
    sortino_ratio <- if (length(downside_returns) > 0) 
      (mean(returns) - risk_free_rate) / sd(downside_returns) * sqrt(252) else Inf
    
    # Additional metrics
    win_loss_ratio <- if (abs(avg_loss) > 0) abs(avg_win / avg_loss) else Inf
    expectancy <- (win_rate/100 * avg_win) - ((100-win_rate)/100 * abs(avg_loss))
    recovery_factor <- if (max_drawdown > 0) sum(trades$pnl_pct) / max_drawdown else Inf
    
    log_message("\n=== TRADE SUMMARY ===")
    log_message(sprintf("Total Trades: %d (W: %d, L: %d, Open: %d)", 
             total_trades, winning_trades, losing_trades, open_trades))
    log_message(sprintf("Win Rate: %.1f%%", win_rate))
    log_message(sprintf("Average P&L: %.2f%%", avg_pnl))
    log_message(sprintf("Average Win: %.2f%% | Average Loss: %.2f%%", avg_win, avg_loss))
    log_message(sprintf("Win/Loss Ratio: %.2f", win_loss_ratio))
    log_message(sprintf("Profit Factor: %.2f | Expectancy: %.2f%%", profit_factor, expectancy))
    log_message(sprintf("Max Drawdown: %.2f%% | Recovery Factor: %.2f", max_drawdown, recovery_factor))
    log_message(sprintf("Sharpe Ratio: %.2f | Sortino Ratio: %.2f", sharpe_ratio, sortino_ratio))
    log_message(sprintf("Best Trade: %.2f%% | Worst Trade: %.2f%%", 
             max(trades$pnl_pct), min(trades$pnl_pct)))
    log_message(sprintf("Average Days Held: %.1f", mean(trades$days_held, na.rm = TRUE)))
    
    # Show all trades
    log_message("\n=== TRADE DETAILS ===")
    print(trades[, .(
      company_id, 
      entry_date, 
      entry_price, 
      exit_date, 
      exit_price, 
      pnl_pct = round(pnl_pct, 2),
      days_held,
      status
    )])
    
  } else {
    log_message("No complete trades found")
  }
  
  return(trades)
}

# Check if company_name exists in the data, if not use company_id
if (!"company_name" %in% names(dt)) {
  # If company_name doesn't exist, create it from company_id
  dt[, company_name := as.character(company_id)]
  log_message("Company name not found in data, using company_id as name")
}

# Generate and show the trade summary
trade_summary <- generate_trade_summary(result_dt)

# Save the trade summary with performance metrics
if (nrow(trade_summary) > 0) {
  # Ensure company_id is character type in both data.tables
  trade_summary[, company_id := as.character(company_id)]
  dt[, company_id := as.character(company_id)]
  
  # Get unique company names - take the first occurrence of each company_id
  company_names <- unique(dt[, .(company_id, company_name)], by = "company_id")
  
  # Add company name to trade summary by joining with original data
  # Using allow.cartesian=TRUE as we expect some duplicates
  trade_summary <- merge(
    trade_summary,
    company_names,
    by = "company_id",
    all.x = TRUE,
    allow.cartesian = TRUE
  )
  
  # If any company_name is NA, replace with company_id
  trade_summary[is.na(company_name), company_name := company_id]
  
  # Remove any potential duplicates that might have been created
  trade_summary <- unique(trade_summary, by = c("company_id", "entry_date", "entry_price", "exit_date"))
  
  # Function to calculate metrics for a single company
  calculate_company_metrics <- function(company_data) {
    if (nrow(company_data) == 0) return(NULL)
    
    # Create a local copy to avoid modifying the original data.table
    dt <- copy(company_data)
    
    # Basic metrics
    total_trades <- nrow(dt)
    winning_trades <- nrow(dt[status == "WIN"])
    losing_trades <- nrow(dt[status == "LOSS"])
    open_trades <- nrow(dt[status == "OPEN"])
    
    win_rate <- if (total_trades > 0) round(winning_trades / total_trades * 100, 2) else 0
    
    # P&L metrics
    avg_pnl <- if (total_trades > 0) round(mean(dt$pnl_pct, na.rm = TRUE), 2) else 0
    avg_win <- if (winning_trades > 0) round(mean(dt[status == "WIN"]$pnl_pct, na.rm = TRUE), 2) else 0
    avg_loss <- if (losing_trades > 0) round(mean(dt[status == "LOSS"]$pnl_pct, na.rm = TRUE), 2) else 0
    
    # Risk metrics
    win_loss_ratio <- if (losing_trades > 0) round(avg_win / abs(avg_loss), 2) else Inf
    
    total_profit <- sum(dt[status == "WIN"]$pnl_pct, na.rm = TRUE)
    total_loss <- abs(sum(dt[status == "LOSS"]$pnl_pct, na.rm = TRUE))
    profit_factor <- if (total_loss > 0) round(total_profit / total_loss, 2) else Inf
    
    # Calculate max drawdown for the company
    if (nrow(dt) > 0) {
      dt[, high_water_mark := cummax(PercCumulativePL)]
      dt[, drawdown := high_water_mark - PercCumulativePL]
      max_drawdown <- round(max(dt$drawdown, na.rm = TRUE), 2)
      
      # Calculate recovery factor
      recovery_factor <- if (max_drawdown > 0) round(max(dt$PercCumulativePL, na.rm = TRUE) / max_drawdown, 2) else Inf
    } else {
      max_drawdown <- 0
      recovery_factor <- Inf
    }
    
    # Calculate Sharpe and Sortino ratios (using 0% as risk-free rate for simplicity)
    returns <- company_data[status %in% c("WIN", "LOSS")]$pnl_pct / 100
    
    sharpe_ratio <- if (length(returns) > 1) {
      round(mean(returns, na.rm = TRUE) / sd(returns, na.rm = TRUE) * sqrt(252), 2)
    } else 0
    
    downside_returns <- returns[returns < 0]
    sortino_ratio <- if (length(downside_returns) > 1) {
      round(mean(returns, na.rm = TRUE) / sd(downside_returns, na.rm = TRUE) * sqrt(252), 2)
    } else 0
    
    # Trade statistics
    best_trade <- if (nrow(company_data) > 0) round(max(company_data$pnl_pct, na.rm = TRUE), 2) else 0
    worst_trade <- if (nrow(company_data) > 0) round(min(company_data$pnl_pct, na.rm = TRUE), 2) else 0
    avg_days_held <- if (nrow(company_data) > 0) round(mean(company_data$days_held, na.rm = TRUE), 1) else 0
    
    data.table(
      total_trades = total_trades,
      winning_trades = winning_trades,
      losing_trades = losing_trades,
      open_trades = open_trades,
      win_rate = win_rate,
      avg_pnl = avg_pnl,
      avg_win = avg_win,
      avg_loss = avg_loss,
      win_loss_ratio = win_loss_ratio,
      profit_factor = profit_factor,
      max_drawdown = max_drawdown,
      recovery_factor = recovery_factor,
      sharpe_ratio = sharpe_ratio,
      sortino_ratio = sortino_ratio,
      best_trade = best_trade,
      worst_trade = worst_trade,
      avg_days_held = avg_days_held
    )
  }
  
  # Calculate metrics for each company
  performance_summary <- trade_summary[, c(calculate_company_metrics(.SD)), by = .(company_id, company_name)]
  
  # Reorder columns for better readability
  setcolorder(performance_summary, c("company_id", "company_name", setdiff(names(performance_summary), c("company_id", "company_name"))))
  
  # Save both trade details and performance summary
  summary_dir <- "/Users/chanderbhushan/stockmkt"
  
  # 1. Save detailed trades with company name
  trade_details_file <- file.path(summary_dir, "trade_details.csv")
  setcolorder(trade_summary, c("company_name", setdiff(names(trade_summary), "company_name")))
  fwrite(trade_summary, trade_details_file)
  
  # 2. Save performance metrics with company name
  metrics_file <- file.path(summary_dir, "performance_metrics.csv")
  fwrite(performance_summary, metrics_file)
  
  log_message(sprintf("\nTrade details saved to: %s", trade_details_file))
  log_message(sprintf("Performance metrics saved to: %s", metrics_file))
}

log_message("Analysis completed")
