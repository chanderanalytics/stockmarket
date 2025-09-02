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
log_message("Column names in input file:")
print(names(dt))

# Check for required columns
required_cols <- c("company_id", "date", "status", "close")
missing_cols <- setdiff(required_cols, names(dt))
if (length(missing_cols) > 0) {
  stop(sprintf("Missing required columns: %s", paste(missing_cols, collapse=", ")))
}

# Check for high/low columns for drawdown calculation
has_high_low <- all(c("high", "low") %in% names(dt))
log_message(sprintf("Has high/low columns for drawdown calculation: %s", has_high_low))

# Process all companies
log_message(sprintf("Processing all %d companies", length(unique(dt$company_id))))

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
    exit_status = character(),
    high = numeric(),
    low = numeric(),
    close = numeric()
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
        portfolio_drawdown <- if (length(drawdowns) > 0) max(drawdowns, na.rm = TRUE) else 0
        
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
          portfolio_drawdown = portfolio_drawdown,
          price_range_pct = price_range_pct,
          running_max = max_price
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
        price_range_pct = 0,
        running_max = last_row$high
      ), fill = TRUE)
    }
  }
  
  # Calculate summary statistics if we have trades
  if (nrow(trades) > 0) {
    # Ensure all numeric columns are properly typed
    numeric_cols <- c('AbsolutePL', 'AbsolutePL_cum', 'PercCumulativePL', 'high_water_mark', 
                     'portfolio_drawdown', 'price_range_pct', 'running_max')
    for (col in numeric_cols) {
      if (col %in% names(trades)) {
        trades[[col]] <- as.numeric(trades[[col]])
      }
    }
    
    # Function to calculate metrics for trades up to each point in time
    calculate_rolling_metrics <- function(dt) {
      # Sort trades by entry date
      setorder(dt, entry_date)
      
      # Initialize result data.table
      result <- data.table()
      
      # Calculate metrics for each trade using history up to that point
      for (i in 1:nrow(dt)) {
        # Get historical trades up to current trade
        hist_trades <- dt[1:i]
        current_trade <- dt[i]
        
        # Use the same calculation as portfolio metrics
        # Basic metrics
        total_trades <- nrow(hist_trades)
        winning_trades <- nrow(hist_trades[status == "WIN"])
        losing_trades <- nrow(hist_trades[status == "LOSS"])
        
        win_rate <- if (total_trades > 0) round(winning_trades / total_trades * 100, 2) else 0
        avg_pnl <- if (total_trades > 0) round(mean(hist_trades$pnl_pct, na.rm = TRUE), 2) else 0
        avg_win <- if (winning_trades > 0) round(mean(hist_trades[status == "WIN"]$pnl_pct, na.rm = TRUE), 2) else 0
        avg_loss <- if (losing_trades > 0) round(mean(hist_trades[status == "LOSS"]$pnl_pct, na.rm = TRUE), 2) else 0
        
        # Risk metrics
        win_loss_ratio <- if (losing_trades > 0) round(avg_win / abs(avg_loss), 2) else Inf
        total_profit <- sum(hist_trades[status == "WIN"]$pnl_pct, na.rm = TRUE)
        total_loss <- abs(sum(hist_trades[status == "LOSS"]$pnl_pct, na.rm = TRUE))
        profit_factor <- if (total_loss > 0) total_profit / total_loss else Inf
        
        # Calculate portfolio drawdown for the historical trades
        # This matches how it's done in the portfolio metrics
        if (nrow(hist_trades) > 0) {
          # Calculate cumulative P&L
          hist_trades[, cum_pnl := cumsum(pnl_pct)]
          # Calculate running maximum
          hist_trades[, running_max := cummax(cum_pnl)]
          # Calculate drawdown from peak
          hist_trades[, drawdown := running_max - cum_pnl]
          # Get maximum drawdown
          portfolio_drawdown <- max(hist_trades$drawdown, na.rm = TRUE)
          # Clean up temporary columns
          hist_trades[, `:=`(cum_pnl = NULL, running_max = NULL, drawdown = NULL)]
        } else {
          portfolio_drawdown <- 0
        }
        
        # Calculate recovery factor using the same logic as portfolio metrics
        recovery_factor <- if (portfolio_drawdown > 0) {
          round(sum(hist_trades[status %in% c("WIN", "LOSS"), ]$pnl_pct, na.rm = TRUE) / portfolio_drawdown, 2)
        } else if (nrow(hist_trades[status %in% c("WIN", "LOSS"), ]) > 0) {
          # If no drawdown but we have trades, set a high recovery factor
          100  # Arbitrary high value since there's no drawdown to recover from
        } else {
          0  # No trades, no recovery factor
        }
        
        # Calculate Sharpe and Sortino ratios (using 0% as risk-free rate for simplicity)
        returns <- hist_trades[status %in% c("WIN", "LOSS")]$pnl_pct / 100
        
        sharpe_ratio <- if (length(returns) > 1) {
          round(mean(returns, na.rm = TRUE) / sd(returns, na.rm = TRUE) * sqrt(252), 2)
        } else 0
        
        downside_returns <- returns[returns < 0]
        sortino_ratio <- if (length(downside_returns) > 1) {
          round(mean(returns, na.rm = TRUE) / sd(downside_returns, na.rm = TRUE) * sqrt(252), 2)
        } else 0
        
        # Calculate composite score components (normalized to 0-100 scale)
        normalize_metric <- function(x, min_val, max_val) {
          pmin(pmax((x - min_val) / (max_val - min_val) * 100, 0), 100)
        }
        
        # Calculate trade confidence using the same sigmoid function as portfolio metrics
        trade_confidence <- 1 / (1 + exp(-0.2 * (total_trades - 10)))  # Sigmoid centered at 10 trades
        trade_confidence <- pmin(pmax(trade_confidence, 0.2), 1.0)  # Cap between 0.2 and 1.0
        
        # Normalize each metric with the same bounds as portfolio metrics
        win_rate_norm <- win_rate  # Already in 0-100 range
        profit_factor_norm <- normalize_metric(profit_factor, 0.3, 5)
        recovery_factor_norm <- normalize_metric(recovery_factor, 0, 15)
        sharpe_ratio_norm <- normalize_metric(sharpe_ratio, -1, 3)
        sortino_ratio_norm <- normalize_metric(sortino_ratio, -1, 5)
        win_loss_ratio_norm <- ifelse(is.infinite(win_loss_ratio), 100, 
                                    normalize_metric(win_loss_ratio, 0.25, 5))
        
        # Apply confidence to normalized metrics (same as portfolio metrics)
        win_rate_norm <- win_rate_norm * trade_confidence
        profit_factor_norm <- profit_factor_norm * trade_confidence
        recovery_factor_norm <- recovery_factor_norm * trade_confidence
        sharpe_ratio_norm <- sharpe_ratio_norm * trade_confidence
        sortino_ratio_norm <- sortino_ratio_norm * trade_confidence
        win_loss_ratio_norm <- win_loss_ratio_norm * trade_confidence
        
        # Calculate composite score with same weights as portfolio metrics
        composite_score <- (win_rate_norm * 0.25) +
                          (profit_factor_norm * 0.25) +
                          (recovery_factor_norm * 0.20) +
                          (sharpe_ratio_norm * 0.15) +
                          (sortino_ratio_norm * 0.10) +
                          (win_loss_ratio_norm * 0.05)
        
        # Categorize performance (same as portfolio metrics)
        performance_category <- cut(
          composite_score,
          breaks = c(-Inf, 20, 40, 60, 80, Inf),
          labels = c("Very Poor", "Poor", "Average", "Good", "Excellent"),
          right = FALSE
        )
        
        # Use the same confidence calculation as portfolio metrics
        # (composite_score is already scaled 0-100, so we just divide by 100 and cap at 1)
        trade_confidence <- pmin(composite_score / 100, 1)
        
        # Combine with current trade
        result <- rbind(result, cbind(
          current_trade,
          data.table(
            trade_composite_score = round(composite_score, 2),
            trade_performance_category = as.character(performance_category),
            trade_confidence = trade_confidence
          )
        ), fill = TRUE)
      }
      
      return(result)
    }
    
    # Calculate metrics for each company separately
    trades_list <- split(trades, by = "company_id")
    trades_list <- lapply(trades_list, calculate_rolling_metrics)
    trades <- rbindlist(trades_list, use.names = TRUE)
    
    # Clean up any temporary columns
    trades[, c("V1") := NULL]
    
    # Add cumulative PnL by company
    trades <- trades[order(company_id, entry_date)]
    
    # Calculate percentage cumulative P&L (simple sum for P&L percentages)
    trades[, `:=`(
      AbsolutePL_cum = cumsum(AbsolutePL),
      PercCumulativePL = cumsum(pnl_pct)
    ), by = company_id]
    
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
      
    # Sort trades by company and entry date for proper drawdown calculation
    setorder(trades, company_id, entry_date)
    
    # Calculate cumulative P&L by company
    trades[, cum_pnl := cumsum(ifelse(is.na(pnl_pct), 0, pnl_pct)), by = company_id]
    
    # Calculate running maximum (high water mark) by company
    trades[, running_max := cummax(pmax(0, cum_pnl)), by = company_id]
    
    # Calculate running drawdown by company
    trades[, running_dd := {
      peak <- 0
      dd <- numeric(.N)
      for (i in 1:.N) {
        if (is.na(cum_pnl[i])) next
        if (cum_pnl[i] > peak) peak <- cum_pnl[i]
        dd[i] <- if (peak > 0) (peak - cum_pnl[i]) / peak * 100 else 0
      }
      dd
    }, by = company_id]
    
    # Calculate cumulative max drawdown by company
    trades[, `:=`(
      cumulative_max_drawdown = cummax(ifelse(is.na(running_dd), 0, running_dd)),
      portfolio_drawdown = max(ifelse(is.na(running_dd), 0, running_dd), na.rm = TRUE)
    ), by = company_id]
    
    # Clean up temporary columns
    trades[, c('cum_pnl', 'running_max') := NULL]
    
    # Calculate returns for rolling metrics
    trades[, returns := c(NA, diff(cumsum(pnl_pct)) / 1)]
    
    # Calculate rolling metrics for each trade
    n_trades <- nrow(trades)
    rolling_metrics <- lapply(2:n_trades, function(i) {
      current_returns <- trades$returns[2:i]  # Skip first NA
      current_drawdown <- trades$portfolio_drawdown[2:i]
      
      # Calculate metrics
      win_rate <- mean(current_returns > 0, na.rm = TRUE) * 100
      wins <- sum(current_returns[current_returns > 0], na.rm = TRUE)
      losses <- abs(sum(current_returns[current_returns < 0], na.rm = TRUE))
      profit_factor <- if (losses > 0) wins / losses else Inf
      
      max_dd <- max(current_drawdown, na.rm = TRUE)
      recovery_factor <- if (is.finite(max_dd) && max_dd > 0) 
        sum(current_returns, na.rm = TRUE) / max_dd else 0
      
      # Risk-adjusted returns
      sharpe_ratio <- if (length(na.omit(current_returns)) > 1 && sd(current_returns, na.rm = TRUE) > 0) {
        mean(current_returns, na.rm = TRUE) / sd(current_returns, na.rm = TRUE) * sqrt(252)
      } else 0
      
      downside_returns <- current_returns[current_returns < 0 & !is.na(current_returns)]
      sortino_ratio <- if (length(downside_returns) > 1) {
        mean(current_returns, na.rm = TRUE) / sd(downside_returns, na.rm = TRUE) * sqrt(252)
      } else 0
      
      list(
        win_rate = win_rate,
        profit_factor = profit_factor,
        recovery_factor = recovery_factor,
        sharpe_ratio = sharpe_ratio,
        sortino_ratio = sortino_ratio
      )
    })
    
    # Get the most recent metrics for summary
    if (length(rolling_metrics) > 0) {
      last_metrics <- tail(rolling_metrics, 1)[[1]]
      win_rate <- last_metrics$win_rate
      profit_factor <- last_metrics$profit_factor
      recovery_factor <- last_metrics$recovery_factor
      sharpe_ratio <- last_metrics$sharpe_ratio
      sortino_ratio <- last_metrics$sortino_ratio
    }
    
    # Additional metrics
    win_loss_ratio <- if (abs(avg_loss) > 0) abs(avg_win / avg_loss) else Inf
    expectancy <- (win_rate/100 * avg_win) - ((100-win_rate)/100 * abs(avg_loss))
    recovery_factor <- if (portfolio_drawdown > 0) sum(trades$pnl_pct) / portfolio_drawdown else Inf
    
    log_message("\n=== TRADE SUMMARY ===")
    log_message(sprintf("Total Trades: %d (W: %d, L: %d, Open: %d)", 
             total_trades, winning_trades, losing_trades, open_trades))
    log_message(sprintf("Win Rate: %.1f%%", win_rate))
    log_message(sprintf("Average P&L: %.2f%%", avg_pnl))
    log_message(sprintf("Average Win: %.2f%% | Average Loss: %.2f%%", avg_win, avg_loss))
    log_message(sprintf("Win/Loss Ratio: %.2f", win_loss_ratio))
    log_message(sprintf("Profit Factor: %.2f | Expectancy: %.2f%%", profit_factor, expectancy))
    log_message(sprintf("Portfolio Drawdown: %.2f%% | Recovery Factor: %.2f", portfolio_drawdown, recovery_factor))
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
    profit_factor <- if (total_loss > 0) total_profit / total_loss else Inf
    
    # Use the pre-calculated portfolio_drawdown from the trade summary
    portfolio_drawdown <- if (nrow(dt) > 0) max(dt$portfolio_drawdown, na.rm = TRUE) else 0
    
    # Calculate recovery factor using portfolio drawdown
    recovery_factor <- if (portfolio_drawdown > 0) {
      round(sum(dt[status %in% c("WIN", "LOSS"), ]$pnl_pct, na.rm = TRUE) / portfolio_drawdown, 2)
    } else {
      Inf
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
    
    # Calculate composite score components (normalized to 0-100 scale)
    normalize_metric <- function(x, min_val, max_val) {
      pmin(pmax((x - min_val) / (max_val - min_val) * 100, 0), 100)
    }
    
    # Calculate trade confidence using a sigmoid-like function that scales with number of trades
    # - Reaches 0.5 at 10 trades
    # - Reaches 0.9 at 30 trades
    # - Approaches 1.0 as trades increase beyond 50
    trade_confidence <- 1 / (1 + exp(-0.2 * (total_trades - 10)))  # Sigmoid centered at 10 trades
    trade_confidence <- pmin(pmax(trade_confidence, 0.2), 1.0)  # Cap between 0.2 and 1.0
    
    # Normalize each metric (with reasonable bounds) and apply trade confidence
    win_rate_norm <- win_rate * trade_confidence  # Already in 0-100 range
    profit_factor_norm <- normalize_metric(profit_factor, 0.3, 5) * trade_confidence
    recovery_factor_norm <- normalize_metric(recovery_factor, 0, 15) * trade_confidence
    sharpe_ratio_norm <- normalize_metric(sharpe_ratio, -1, 3) * trade_confidence
    sortino_ratio_norm <- normalize_metric(sortino_ratio, -1, 5) * trade_confidence
    win_loss_ratio_norm <- normalize_metric(win_loss_ratio, 0.25, 5) * trade_confidence
    
    # Calculate composite score (weighted average)
    portfolio_composite_score <- (win_rate_norm * 0.25) +
                               (profit_factor_norm * 0.25) +
                               (recovery_factor_norm * 0.20) +
                               (sharpe_ratio_norm * 0.15) +
                               (sortino_ratio_norm * 0.10) +
                               (win_loss_ratio_norm * 0.05)
    
    # Categorize performance
    portfolio_performance_category <- cut(portfolio_composite_score,
                                        breaks = c(-Inf, 20, 40, 60, 80, Inf),
                                        labels = c("Very Poor", "Poor", "Average", "Good", "Excellent"),
                                        right = FALSE)
    
    # Calculate confidence level (0-1)
    portfolio_trade_confidence <- pmin(portfolio_composite_score / 100, 1)
    
    # Trade statistics
    best_trade <- if (nrow(company_data) > 0) round(max(company_data$pnl_pct, na.rm = TRUE), 2) else 0
    worst_trade <- if (nrow(company_data) > 0) round(min(company_data$pnl_pct, na.rm = TRUE), 2) else 0
    avg_days_held <- if (nrow(company_data) > 0) round(mean(company_data$days_held, na.rm = TRUE), 1) else 0
    
    return(list(
      total_trades = total_trades,
      winning_trades = winning_trades,
      losing_trades = losing_trades,
      open_trades = open_trades,
      win_rate = round(win_rate, 2),
      avg_pnl = round(avg_pnl, 2),
      avg_win = round(avg_win, 2),
      avg_loss = round(avg_loss, 2),
      win_loss_ratio = round(win_loss_ratio, 2),
      profit_factor = round(profit_factor, 2),
      portfolio_drawdown = round(portfolio_drawdown, 2),
      recovery_factor = recovery_factor,
      sharpe_ratio = sharpe_ratio,
      sortino_ratio = sortino_ratio,
      best_trade = best_trade,
      worst_trade = worst_trade,
      avg_days_held = avg_days_held,
      portfolio_composite_score = round(portfolio_composite_score, 2),
      portfolio_performance_category = as.character(portfolio_performance_category),
      portfolio_trade_confidence = round(portfolio_trade_confidence, 4)
    ))
  }
  
  # Calculate metrics for each company
  performance_summary <- trade_summary[, c(calculate_company_metrics(.SD)), by = .(company_id, company_name)]
  
  # Reorder columns for better readability
  setcolorder(performance_summary, c("company_id", "company_name", setdiff(names(performance_summary), c("company_id", "company_name"))))
  
  # Save both trade details and performance summary
  summary_dir <- "/Users/chanderbhushan/stockmkt"
  
  # Add composite score, category, and confidence to trade details
  if (exists("performance_summary") && nrow(performance_summary) > 0) {
    # Select only the needed columns to merge
    company_metrics <- performance_summary[, .(company_id, portfolio_composite_score, 
                                             portfolio_performance_category, portfolio_trade_confidence)]
    
    # Add metrics to trade details
    trade_summary <- merge(trade_summary, company_metrics, by = "company_id", all.x = TRUE)
  }
  
  # 1. Save detailed trades with company name and metrics
  trade_details_file <- file.path(summary_dir, "trade_details.csv")
  
  # Reorder columns for better readability
  setcolorder(trade_summary, c("company_id", "company_name", "entry_date", "entry_price",
                             "exit_date", "exit_price", "pnl_pct", "days_held", "status",
                             "portfolio_composite_score", "portfolio_performance_category", "portfolio_trade_confidence",
                             setdiff(names(trade_summary), c("company_id", "company_name", 
                                                           "entry_date", "entry_price",
                                                           "exit_date", "exit_price", 
                                                           "pnl_pct", "days_held", "status",
                                                           "portfolio_composite_score", 
                                                           "portfolio_performance_category", 
                                                           "portfolio_trade_confidence"))))
  
  fwrite(trade_summary, trade_details_file)
  
  # 2. Save performance metrics with company name
  metrics_file <- file.path(summary_dir, "performance_metrics.csv")
  
  # Reorder columns for better readability
  setcolorder(performance_summary, c("company_id", "company_name", "total_trades", 
                                   "winning_trades", "losing_trades", "win_rate",
                                   "avg_pnl", "avg_win", "avg_loss", "win_loss_ratio",
                                   "profit_factor", "portfolio_drawdown", "recovery_factor",
                                   "sharpe_ratio", "sortino_ratio", "portfolio_composite_score",
                                   "portfolio_performance_category", "portfolio_trade_confidence"))
  
  fwrite(performance_summary, metrics_file)
  
  log_message(sprintf("\nTrade details saved to: %s", trade_details_file))
  log_message(sprintf("Performance metrics saved to: %s", metrics_file))
}

log_message("Analysis completed")