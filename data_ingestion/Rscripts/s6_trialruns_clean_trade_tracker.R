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

# Process all companies
unique_companies <- unique(dt$company_id)
log_message(sprintf("Processing all %d companies", length(unique_companies)))
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
unique_companies <- unique(dt$company_id)
log_message(sprintf("Processing all %d companies", length(unique_companies)))

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
  
  # Only process companies in our limited list
  for (comp_id in unique_companies) {
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

# Create trialruns directory if it doesn't exist
if (!dir.exists("trialruns")) {
  dir.create("trialruns")
}

# Define output file path
output_file <- file.path("trialruns", "cleaned_trade_analysis.csv")
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
  
  # Process each company separately - only those in our limited list
  for (comp_id in unique_companies) {
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
    numeric_cols <- c('AbsolutePL', 'AbsolutePL_cum', 'PercCumulativePL', 'high_water_mark', 'portfolio_high_water_mark', 
                     'portfolio_drawdown', 'price_range_pct', 'running_max')
    for (col in numeric_cols) {
      if (col %in% names(trades)) {
        trades[[col]] <- as.numeric(trades[[col]])
      }
    }
    
    # Function to calculate metrics for trades up to each point in time
    calculate_rolling_metrics <- function(company_trades) {
      if (!is.data.table(company_trades) || nrow(company_trades) == 0) return(NULL)
      
      # Make a local copy to avoid modifying the original
      dt <- copy(company_trades)
      
      # Sort trades by entry date
      setorder(dt, entry_date)
      
      # Initialize result list to store each row
      result_list <- list()
      
      # Calculate metrics for each trade using history up to that point
      for (i in 1:nrow(dt)) {
        # Get historical trades up to but not including current trade
        hist_trades <- if (i > 1) dt[1:(i-1)] else dt[0]
        current_trade <- dt[i]
        
        # Use the same calculation as portfolio metrics
        # Calculate metrics on historical trades
        total_trades_hist <- nrow(hist_trades)
        winning_trades_hist <- nrow(hist_trades[status == "WIN"])
        losing_trades_hist <- nrow(hist_trades[status == "LOSS"])
        
        win_rate_hist <- if (total_trades_hist > 0) round(winning_trades_hist / total_trades_hist * 100, 2) else 0
        avg_pnl_hist <- if (total_trades_hist > 0) round(mean(hist_trades$pnl_pct, na.rm = TRUE), 2) else 0
        avg_win_hist <- if (winning_trades_hist > 0) round(mean(hist_trades[status == "WIN"]$pnl_pct, na.rm = TRUE), 2) else 0
        avg_loss_hist <- if (losing_trades_hist > 0) round(mean(hist_trades[status == "LOSS"]$pnl_pct, na.rm = TRUE), 2) else 0
        
        # Risk metrics
        win_loss_ratio_hist <- if (losing_trades_hist > 0) round(avg_win_hist / abs(avg_loss_hist), 2) else Inf
        total_profit_hist <- sum(hist_trades[status == "WIN"]$pnl_pct, na.rm = TRUE)
        total_loss_hist <- abs(sum(hist_trades[status == "LOSS"]$pnl_pct, na.rm = TRUE))
        profit_factor_hist <- if (total_loss_hist > 0) total_profit_hist / total_loss_hist else Inf
        
        # Initialize max_drawdown_hist
        max_drawdown_hist <- 0
        
        # Calculate trade-level recovery factor using only historical data
        if (nrow(hist_trades) > 0) {
          # Calculate running cumulative P&L
          hist_trades[, cum_pnl := cumsum(pnl_pct)]
          # Calculate running maximum
          hist_trades[, running_max := cummax(pmax(0, cum_pnl))]  # Don't go below 0
          # Calculate drawdown from peak
          hist_trades[, drawdown := running_max - cum_pnl]
          # Get maximum drawdown up to this point
          max_drawdown_hist <- if (all(is.na(hist_trades$drawdown))) 0 else max(hist_trades$drawdown, na.rm = TRUE)
          
          # Calculate recovery factor using only historical trades
          if (max_drawdown_hist > 0) {
            recovery_factor_hist <- round(sum(hist_trades$pnl_pct, na.rm = TRUE) / max_drawdown_hist, 2)
          } else if (nrow(hist_trades) > 0) {
            # If no drawdown but we have trades
            recovery_factor_hist <- 100  # No drawdown to recover from
          } else {
            recovery_factor_hist <- 0  # No trades
          }
          
          # Clean up temporary columns
          hist_trades[, `:=`(cum_pnl = NULL, running_max = NULL, drawdown = NULL)]
        } else {
          recovery_factor_hist <- 0  # No historical trades
        }
        
        # Check if this is the first trade
        prev_trades <- nrow(hist_trades)
        # No special handling for first trade - all trades use actual metrics
        
        # Calculate metrics for trades with history
        returns_hist <- hist_trades[status %in% c("WIN", "LOSS")]$pnl_pct / 100
        
        # Calculate Sharpe ratio with dynamic annualization
        sharpe_ratio_hist <- if (length(returns_hist) > 1) {
          # Calculate actual holding period for each historical trade in days
          # Using only historical trades to avoid lookahead bias
          holding_days <- as.numeric(difftime(hist_trades$exit_date, hist_trades$entry_date, units = "days"))
          avg_holding_days <- mean(holding_days, na.rm = TRUE)
          if (is.na(avg_holding_days) || avg_holding_days <= 0) avg_holding_days <- 1
          annual_factor <- sqrt(252 / avg_holding_days)  # Scale by actual holding period
          
          mean_return <- mean(returns_hist, na.rm = TRUE)
          std_dev <- sd(returns_hist, na.rm = TRUE)
          
          if (!is.na(mean_return) && !is.na(std_dev) && std_dev > 0) {
            # Cap the Sharpe ratio at 5
            pmin(5, (mean_return / std_dev) * annual_factor)
          } else if (!is.na(mean_return) && mean_return > 0) {
            # If no volatility but positive returns, return a moderate value
            2
          } else {
            0
          }
        } else {
          -1  # Not enough data
        }
        
        # Calculate Sortino ratio (only downside deviation)
        sortino_ratio_hist <- if (length(returns_hist) > 1) {
          downside_returns_hist <- returns_hist[returns_hist < 0 & !is.na(returns_hist)]
          if (length(downside_returns_hist) > 1) {
            # Only calculate if we have at least 2 downside returns for meaningful SD
            mean_return <- mean(returns_hist, na.rm = TRUE)
            downside_dev <- sd(downside_returns_hist, na.rm = TRUE)
            if (!is.na(mean_return) && !is.na(downside_dev) && downside_dev > 0) {
              # Calculate dynamic annualization factor based on holding period
              # Calculate actual holding period for each historical trade in days
          # Using only historical trades to avoid lookahead bias
          holding_days <- as.numeric(difftime(hist_trades$exit_date, hist_trades$entry_date, units = "days"))
          avg_holding_days <- mean(holding_days, na.rm = TRUE)
              if (is.na(avg_holding_days) || avg_holding_days <= 0) avg_holding_days <- 1
              annual_factor <- sqrt(252 / avg_holding_days)
              
              # Calculate Sortino ratio and cap it at 5
              ratio <- (mean_return / downside_dev) * annual_factor
              pmin(5, ratio)  # Cap at 5
            } else if (!is.na(mean_return) && mean_return > 0) {
              # If no downside deviation but positive returns, return a moderate value
              2  # Conservative value for perfect downside protection
            } else {
              # If no downside deviation and no positive returns, return -1
              -1
            }
          } else if (length(downside_returns_hist) == 1) {
            # If only one downside return, use it directly
            mean_return <- mean(returns_hist, na.rm = TRUE)
            if (!is.na(mean_return) && mean_return > 0) {
              # Use the single downside return as the deviation
              ratio <- sqrt(252) * mean_return / abs(downside_returns_hist[1])
              # Cap at 5 to prevent extreme values from single trade
              pmin(5, ratio)
            } else {
              0
            }
          } else {
            # No downside returns
            mean_return <- mean(returns_hist, na.rm = TRUE)
            if (!is.na(mean_return) && mean_return > 0) {
              # If no downside and positive returns, return a high value
              5  # More conservative than 10 for perfect downside protection
            } else {
              # If no downside and no positive returns, return 0
              0
            }
          }
        } else {
          # Not enough data points, return -1 to indicate missing data
          -1
        }
        
        # Calculate confidence based on number of trades
        trade_confidence <- 1 / (1 + exp(-0.2 * (prev_trades - 10)))  # Sigmoid centered at 10 trades
        
        # Apply logarithmic transformations to all metrics for better scaling
        # and remove any capping to preserve the full range of values
        
        # Calculate trade duration in days (if not already available)
        trade_days <- as.numeric(difftime(current_trade$exit_date, current_trade$entry_date, units = "days"))
        
        
        # Get the last cumulative max drawdown from historical trades
        # Using pre-calculated metrics where available
        hist_cum_max_dd <- if (nrow(hist_trades) > 0) {
          last_cum_max_dd <- tail(na.omit(hist_trades$cumulative_max_drawdown), 1)
          if (length(last_cum_max_dd) == 0) 0 else last_cum_max_dd
        } else {
          0  # No historical trades
        }
        
        # Calculate trade drawdown score using pre-calculated metrics
        # Using log1p to        # Calculate trade drawdown score (inverted)
        trade_drawdown_score <- if (hist_cum_max_dd > 0) {
          1 / (1 + hist_cum_max_dd) * 100  # Invert
        } else {
          100  # Handle case with no drawdown
        }
        
        # Calculate recovery score using pre-calculated recovery_factor_hist
        recovery_score_hist <- recovery_factor_hist
        
        # Calculate raw composite score with normalized metrics and proper weighting
        # All metrics are first normalized to 0-1 range before weighting
        
        # 1. Win Rate (0-100 scale)
        win_rate_norm <- win_rate_hist / 100
        
        # 2. Profit Factor (cap at 10, then normalize)
        pf_capped <- pmin(profit_factor_hist, 10)
        pf_norm <- pf_capped / 10
        
        # 3. Recovery Score (0-100 scale)
        recovery_norm <- recovery_score_hist / 100
        
        # 4. Sharpe Ratio (cap at 5, then normalize)
        sharpe_capped <- pmin(pmax(sharpe_ratio_hist, -2), 5)
        sharpe_norm <- (sharpe_capped + 2) / 7
        
        # 5. Sortino Ratio (cap at 10, then normalize)
        sortino_capped <- pmin(pmax(sortino_ratio_hist, 0), 10)
        sortino_norm <- sortino_capped / 10
        
        # 6. Win/Loss Ratio (cap at 10, then normalize)
        wl_capped <- pmin(win_loss_ratio_hist, 10)
        wl_norm <- wl_capped / 10
        
        # 7. Drawdown Score (0-100 scale)
        dd_norm <- trade_drawdown_score / 100
        
        # Calculate raw composite score with weights summing to 100
        raw_composite <- (
          (win_rate_norm * 15) +                   # 15% weight (0-1 scale)
          (pf_norm * 20) +                         # 20% weight
          (recovery_norm * 15) +                   # 15% weight (0-1 scale)
          (sharpe_norm * 15) +                     # 15% weight
          (sortino_norm * 10) +                    # 10% weight
          (wl_norm * 10) +                         # 10% weight
          (dd_norm * 15)                          # 15% weight
        )  # Total = 100
        
        # Scale to 0-100 range and apply trade confidence
        # Using a softmax-like scaling that handles outliers gracefully
        composite_score <- 100 * (1 - 1/(1 + raw_composite)) * trade_confidence
        
        # Prepare metrics for output
        
        # Categorize performance
        performance_category <- cut(
          composite_score,
          breaks = c(-Inf, 20, 40, 60, 80, Inf),
          labels = c("Very Poor", "Poor", "Average", "Good", "Excellent"),
          right = FALSE
        )
        
        # Calculate current trade metrics (for the trade being scored)
        current_status <- ifelse(current_trade$pnl_pct > 0, "WIN", 
                               ifelse(current_trade$pnl_pct < 0, "LOSS", "BREAKEVEN"))
        
        # Store metrics for this trade
        result_list[[i]] <- cbind(
          current_trade,
          data.table(
            win_rate_hist = win_rate_hist,
            avg_pnl_hist = avg_pnl_hist,
            avg_win_hist = avg_win_hist,
            avg_loss_hist = avg_loss_hist,
            win_loss_ratio_hist = win_loss_ratio_hist,
            profit_factor_hist = profit_factor_hist,
            recovery_factor_hist = recovery_factor_hist,
            max_drawdown_hist = max_drawdown_hist,
            sharpe_ratio_hist = if (exists("sharpe_ratio_hist")) sharpe_ratio_hist else NA_real_,
            sortino_ratio_hist = if (exists("sortino_ratio_hist")) sortino_ratio_hist else NA_real_,
            composite_score = composite_score,
            performance_category = as.character(performance_category),
            trade_confidence = trade_confidence
          )
        )
      }
      
      # Combine all results
      if (length(result_list) > 0) {
        return(rbindlist(result_list, use.names = TRUE, fill = TRUE))
      } else {
        return(NULL)
      }
    }
    
    # Process companies in smaller batches to avoid memory issues
    process_company_batch <- function(company_batch) {
      batch_results <- list()
      for (comp_id in company_batch) {
        tryCatch({
          comp_trades <- trades[company_id == comp_id]
          if (nrow(comp_trades) > 0) {
            metrics <- calculate_rolling_metrics(comp_trades)
            if (!is.null(metrics) && nrow(metrics) > 0) {
              batch_results[[as.character(comp_id)]] <- metrics
            }
          }
        }, error = function(e) {
          log_message(sprintf("Error processing company %s: %s", comp_id, e$message))
        })
      }
      return(batch_results)
    }
    
    # Process companies in batches
    company_ids <- unique(trades$company_id)
    batch_size <- 10  # Process 10 companies at a time
    trades_list <- list()
    
    for (i in seq(1, length(company_ids), batch_size)) {
      batch_end <- min(i + batch_size - 1, length(company_ids))
      current_batch <- company_ids[i:batch_end]
      log_message(sprintf("Processing batch %d to %d of %d companies", i, batch_end, length(company_ids)))
      
      batch_results <- process_company_batch(current_batch)
      trades_list <- c(trades_list, batch_results)
    }
    
    # Combine all results
    if (length(trades_list) > 0) {
      trades <- rbindlist(trades_list, use.names = TRUE, fill = TRUE)
    } else {
      stop("No valid trades after processing")
    }
    
    # Clean up any temporary columns
    #trades[, c("V1") := NULL]
    
    # Add cumulative PnL by company
    trades <- trades[order(company_id, entry_date)]
    
    # Calculate percentage cumulative P&L using lagged values to prevent look-ahead
    trades[, `:=`(
      AbsolutePL_cum = c(0, cumsum(AbsolutePL[-.N])),  # Lagged cumulative sum
      PercCumulativePL = c(0, cumsum(pmax(pmin(pnl_pct[-.N], 100), -100))),  # Bounded and lagged
      portfolio_high_water_mark = c(0, cummax(pmax(0, cumsum(pmax(pmin(pnl_pct[-.N], 100), -100)))))
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
  } 
  
  if (nrow(trades) == 0) {
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
    
    # Calculate trade confidence using a sigmoid-like function that scales with number of trades
    # - Reaches 0.5 at 10 trades
    # - Reaches 0.9 at 30 trades
    # - Approaches 1.0 as trades increase beyond 50
    trade_confidence <- 1 / (1 + exp(-0.2 * (total_trades - 10)))  # Sigmoid centered at 10 trades
    trade_confidence <- pmin(pmax(trade_confidence, 0.2), 1.0)  # Cap between 0.2 and 1.0
    
    # Use raw metrics without capping
    profit_factor_scaled <- profit_factor
    recovery_scaled <- recovery_factor
    sharpe_scaled <- sharpe_ratio
    sortino_scaled <- sortino_ratio
    wl_ratio_scaled <- win_loss_ratio
    
    # Calculate raw composite score using weighted average of metrics
    # Weights are chosen to give more importance to metrics that better predict performance
    # Handle recovery factor (can be negative)
    # For negative recovery, we'll use -log1p(abs(x)) to maintain ordering
    recovery_score <- ifelse(recovery_factor >= 0, 
                           log1p(recovery_factor),
                           -log1p(abs(recovery_factor)))
    
    # Calculate portfolio drawdown score
    # Using the maximum drawdown across all companies
    portfolio_drawdown_score <- ifelse(!is.na(portfolio_drawdown) && portfolio_drawdown > 0, 
                                    1 / (1 + portfolio_drawdown) * 100,
                                    100)
    
    # Calculate raw composite score with weights summing to 100
    raw_composite <- (
      (win_rate * 0.15) +               # 15% weight (0-15)
      (log1p(profit_factor) * 20) +      # 20% weight (log scale)
      (recovery_score * 15) +            # 15% weight (handles negative)
      (sharpe_ratio * 15) +              # 15% weight
      (sortino_ratio * 10) +             # 10% weight
      (log1p(win_loss_ratio) * 10) +     # 10% weight (log scale)
      (portfolio_drawdown_score * 0.15)   # 15% weight for drawdown
    )  # Total = 100
    
    # Scale to 0-100 range and apply trade confidence
    # Using a softmax-like scaling that handles outliers gracefully
    portfolio_composite_score <- 100 * (1 - 1/(1 + raw_composite/100)) * trade_confidence
    
    # Use the already scaled metrics for output
    profit_factor_norm <- profit_factor_scaled
    recovery_factor_norm <- recovery_scaled
    sharpe_ratio_norm <- sharpe_scaled
    sortino_ratio_norm <- sortino_scaled
    win_loss_ratio_norm <- wl_ratio_scaled
    
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
  
  # Save both trade details and performance summary to trialruns directory
  summary_dir <- "trialruns"
  
  # Create the trialruns directory if it doesn't exist
  if (!dir.exists(summary_dir)) {
    dir.create(summary_dir, recursive = TRUE, mode = "0755")
    log_message(sprintf("Created directory: %s", summary_dir))
  }
  
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
  metrics_file <- file.path("trialruns", "performance_metrics.csv")
  
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