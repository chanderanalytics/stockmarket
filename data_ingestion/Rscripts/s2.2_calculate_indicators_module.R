#!/usr/bin/env Rscript

# Module: calculate_indicators_enriched
# Exposes a pure function to enrich a price DT with PA/volume indicators

suppressWarnings({
  if (!requireNamespace("data.table", quietly = TRUE)) stop("data.table required")
  if (!requireNamespace("TTR", quietly = TRUE)) stop("TTR required")
})

# Helper for safe ECDF calculation (used in risk score)
safe_ecdf <- function(x) {
  if (all(is.na(x))) return(rep(NA_real_, length(x)))
  x_ecdf <- ecdf(na.omit(x))
  result <- rep(NA_real_, length(x))
  result[!is.na(x)] <- x_ecdf(x[!is.na(x)])
  return(result * 100) # Convert to 0-100 scale
}

# Helper for Kelly fraction calculation
calculate_kelly_fraction <- function(rr) {
  if (length(rr) >= 21) {
    wins <- sum(rr > 0, na.rm = TRUE)
    total <- sum(!is.na(rr))
    if (wins > 0 && total >= 21) {
      win_rate <- wins / total
      win_mask <- rr > 0 & !is.na(rr)
      loss_mask <- rr < 0 & !is.na(rr)
      if (sum(win_mask) > 0 && sum(loss_mask) > 0) {
        avg_win <- mean(rr[win_mask])
        avg_loss <- -mean(rr[loss_mask])
        if (avg_loss > 0) {
          win_ratio <- avg_win / avg_loss
          kelly <- ((win_rate * (win_ratio + 1)) - 1) / win_ratio
          return(pmax(0, pmin(1, kelly)))
        }
      }
    }
  }
  return(NA_real_)
}

calculate_indicators_enriched <- function(dt) {
  stopifnot(data.table::is.data.table(dt))
  data.table::setorder(dt, company_id, date)
  log_message("Starting enriched technical indicator calculations...")

  # ----------------------------------------------------------------------------
  # 1. Core Returns and Price MAs (from original mmtm.R)
  # ----------------------------------------------------------------------------

  # Basic returns (idempotent)
  if (!"return_1d" %in% names(dt)) dt[, return_1d := (close - data.table::shift(close, 1)) / data.table::shift(close, 1), by = company_id]
  if (!"return_5d" %in% names(dt)) dt[, return_5d := close / data.table::shift(close, 5) - 1, by = company_id]
  if (!"return_10d" %in% names(dt)) dt[, return_10d := close / data.table::shift(close, 10) - 1, by = company_id] # Added from previous module version
  if (!"return_21d" %in% names(dt)) dt[, return_21d := close / data.table::shift(close, 21) - 1, by = company_id]
  if (!"return_63d" %in% names(dt)) dt[, return_63d := close / data.table::shift(close, 63) - 1, by = company_id]
  log_message("  Returns calculated")

  # Moving averages (price)
  if (!"ma_5" %in% names(dt)) dt[, ma_5 := data.table::frollmean(close, 5, align = "right"), by = company_id]
  if (!"ma_21" %in% names(dt)) dt[, ma_21 := data.table::frollmean(close, 21, align = "right"), by = company_id]
  if (!"ma_50" %in% names(dt)) dt[, ma_50 := data.table::frollmean(close, 50, align = "right"), by = company_id]
  if (!"ma_63" %in% names(dt)) dt[, ma_63 := data.table::frollmean(close, 63, align = "right"), by = company_id]
  if (!"ma_126" %in% names(dt)) dt[, ma_126 := data.table::frollmean(close, 126, align = "right"), by = company_id]
  if (!"ma_252" %in% names(dt)) dt[, ma_252 := data.table::frollmean(close, 252, align = "right"), by = company_id]
  log_message("  Moving averages calculated")

  # ----------------------------------------------------------------------------
  # 2. Volatility (from original mmtm.R and previous module version)
  # ----------------------------------------------------------------------------
  if (!"tr" %in% names(dt)) dt[, tr := pmax(high - low,
                                             abs(high - data.table::shift(close, 1)),
                                             abs(low - data.table::shift(close, 1)), na.rm = TRUE), by = company_id]
  if (!"atr" %in% names(dt)) {
    log_message("  Calculating ATR...", "DEBUG")
    dt[, atr := {
      log_message(sprintf("  DEBUG (ATR - company %s): Starting ATR calculation for .N = %d rows", .BY$company_id, .N), "DEBUG")
      # Remove NAs only for the columns used in ATR calculation within this group
      temp_dt <- na.omit(.SD, cols = c("high", "low", "close"))
      log_message(sprintf("  DEBUG (ATR - company %s): After na.omit, temp_dt has %d rows and is of class %s", .BY$company_id, nrow(temp_dt), class(temp_dt)), "DEBUG")
      
      atr_values <- rep(NA_real_, .N) # Pre-allocate result vector with NAs
      
      if (nrow(temp_dt) > 0) {
        # Explicitly convert to matrix for TTR functions
        hlc_matrix <- as.matrix(temp_dt[, .(high, low, close)])
        log_message(sprintf("  DEBUG (ATR - company %s): HLC matrix dimensions: %s, class: %s", .BY$company_id, paste(dim(hlc_matrix), collapse = "x"), class(hlc_matrix)), "DEBUG")
        
        if (nrow(hlc_matrix) >= 14) { # ATR requires at least 'n' (14) observations
          calculated_atr <- TTR::ATR(HLC = hlc_matrix, n = 14)[, "atr"]
          
          # Map calculated_atr back to the original .N length
          if (length(calculated_atr) > 0) {
            # Find the original indices that correspond to the valid data in temp_dt
            original_valid_indices <- which(!is.na(high) & !is.na(low) & !is.na(close))
            
            # Ensure we don't try to assign more values than available slots
            start_idx_in_original <- original_valid_indices[length(original_valid_indices) - length(calculated_atr) + 1]
            end_idx_in_original <- tail(original_valid_indices, 1)
            
            if (start_idx_in_original > 0 && end_idx_in_original >= start_idx_in_original) {
              atr_values[start_idx_in_original:end_idx_in_original] <- calculated_atr
            }
          }
        } else {
          log_message(sprintf("  DEBUG (ATR - company %s): Insufficient data (%d rows) for ATR calculation, needs at least 14.", .BY$company_id, nrow(hlc_matrix)), "DEBUG")
        }
      } else {
        log_message(sprintf("  DEBUG (ATR - company %s): temp_dt is empty after na.omit.", .BY$company_id), "DEBUG")
      }
      atr_values # Return the pre-allocated vector with NAs and calculated values
    }, by = company_id]
    log_message("  ATR calculated", "DEBUG")
  }
  # Old ATR calculation: if (!"atr" %in% names(dt)) dt[, atr := TTR::ATR(HLC = dt[, .(high, low, close)], n = 14)$atr, by = company_id] # Use TTR's ATR
  # log_message("  ATR calculated")

  if (!"vol_5d" %in% names(dt)) {
    dt[, vol_5d := {
      if (.N >= 5) {
        mean5 <- frollmean(return_1d, 5, align = "right", na.rm = TRUE)
        mean_sq5 <- frollmean(return_1d^2, 5, align = "right", na.rm = TRUE)
        sqrt(pmax(mean_sq5 - mean5^2, 0, na.rm = TRUE)) * sqrt(252)
      } else { NA_real_ }
    }, by = company_id]
  }
  if (!"vol_21d" %in% names(dt)) {
    dt[, vol_21d := {
      if (.N >= 21) {
        mean21 <- frollmean(return_1d, 21, align = "right", na.rm = TRUE)
        mean_sq21 <- frollmean(return_1d^2, 21, align = "right", na.rm = TRUE)
        sqrt(pmax(mean_sq21 - mean21^2, 0, na.rm = TRUE)) * sqrt(252)
      } else { NA_real_ }
    }, by = company_id]
  }
  log_message("  Volatility metrics (5d, 21d) calculated")

  # ----------------------------------------------------------------------------
  # 3. Price Action / Range Metrics (from original mmtm.R and previous module version)
  # ----------------------------------------------------------------------------

  # Price distance to MAs (%)
  dt[, price_vs_ma21 := (close / pmax(ma_21, 1e-9) - 1) * 100]
  dt[, price_vs_ma50 := (close / pmax(ma_50, 1e-9) - 1) * 100]
  log_message("  Price vs MA calculated")

  # MA slopes (short trend)
  dt[, ma_21_slope := (ma_21 / pmax(data.table::shift(ma_21, 5), 1e-9) - 1) * 100, by = company_id]
  log_message("  MA slopes calculated")

  # High/low windows
  if (!"high_5d" %in% names(dt)) dt[, high_5d := data.table::frollapply(high, 5, max, align = "right", fill = NA), by = company_id]
  if (!"low_5d" %in% names(dt)) dt[, low_5d := data.table::frollapply(low, 5, min, align = "right", fill = NA), by = company_id]
  if (!"high_21d" %in% names(dt)) dt[, high_21d := data.table::frollapply(high, 21, max, align = "right", fill = NA), by = company_id]
  if (!"low_21d" %in% names(dt)) dt[, low_21d := data.table::frollapply(low, 21, min, align = "right", fill = NA), by = company_id]
  if (!"high_63d" %in% names(dt)) dt[, high_63d := data.table::frollapply(high, 63, max, align = "right", fill = NA), by = company_id] # Added
  if (!"low_63d" %in% names(dt)) dt[, low_63d := data.table::frollapply(low, 63, min, align = "right", fill = NA), by = company_id]   # Added
  log_message("  High/Low windows calculated")

  dt[, pct_from_21d_high := (close / pmax(high_21d, 1e-9) - 1) * 100]
  log_message("  Pct from 21d high calculated")

  # 52-week context (from previous module version)
  if (!"high_252d" %in% names(dt)) dt[, high_252d := data.table::frollapply(high, 252, max, align = "right", fill = NA), by = company_id]
  if (!"low_252d" %in% names(dt)) dt[, low_252d := data.table::frollapply(low, 252, min, align = "right", fill = NA), by = company_id]
  if (!"near_52wk_high" %in% names(dt)) dt[, near_52wk_high := close > 0.95 * high_252d]
  if (!"drawdown_52wk" %in% names(dt)) dt[, drawdown_52wk := (close / pmax(high_252d, 1e-9) - 1) * 100]
  log_message("  52-week context calculated")

  # Range metrics (from original mmtm.R)
  if (!"range_5d" %in% names(dt)) dt[, range_5d := high_5d - low_5d]
  if (!"range_21d" %in% names(dt)) dt[, range_21d := high_21d - low_21d]
  if (!"range_contraction" %in% names(dt)) {
    dt[, range_contraction := {
      safe_denominator <- pmax(range_21d, 1e-9)
      range_5d / safe_denominator
    }]
  }
  log_message("  Range metrics calculated")

  # Tight range (from original mmtm.R)
  if (!"is_tight_range" %in% names(dt)) {
    dt[, is_tight_range := {
      range_5d_calc <- high_5d - low_5d
      range_contraction_calc <- fifelse(!is.na(range_5d_calc) & !is.na(ma_21) & ma_21 > 0,
                                        range_5d_calc / ma_21, NA_real_)
      !is.na(range_contraction_calc) & range_contraction_calc < 0.05
    }]
  }
  if (!"tight_range_count" %in% names(dt)) {
    dt[, tight_range_count := {
      r <- rle(is_tight_range & !is.na(is_tight_range))
      if (length(r$lengths) == 0) return(integer(0))
      seqs <- sequence(r$lengths)
      seqs * rep(r$values, r$lengths)
    }, by = company_id]
  }
  if (!"is_3day_tight" %in% names(dt)) {
    dt[, is_3day_tight := {
      if (.N >= 3) {
        frollsum(is_tight_range, 3, align = "right") >= 3
      } else { FALSE }
    }, by = company_id]
  }
  log_message("  Tight range indicators (is_tight_range, tight_range_count, is_3day_tight) calculated")

  # Inside day, NR4/NR7 flags (from previous module version)
  if (!"inside_day" %in% names(dt)) dt[, inside_day := (high < data.table::shift(high, 1)) & (low > data.table::shift(low, 1)), by = company_id]
  if (!"day_range" %in% names(dt)) dt[, day_range := high - low]
  if (!"nr4" %in% names(dt)) dt[, nr4 := day_range <= data.table::frollapply(day_range, 4, function(x) quantile(x, 0.25, na.rm = TRUE), align = "right"), by = company_id]
  if (!"nr7" %in% names(dt)) dt[, nr7 := day_range <= data.table::frollapply(day_range, 7, function(x) quantile(x, 0.25, na.rm = TRUE), align = "right"), by = company_id]
  log_message("  Inside day, NR4/NR7 calculated")

  # Overextension from moving average (from original mmtm.R)
  if (!"overextension" %in% names(dt)) dt[, overextension := (close / ma_21 - 1)]
  log_message("  Price overextension calculated")

  # Drawdown from recent high (63-day lookback) (from original mmtm.R)
  if (!"drawdown" %in% names(dt)) {
    dt[, drawdown := {
      result <- rep(NA_real_, .N)
      if (.N >= 5) {
        valid_close <- !is.na(close) & close > 0
        valid_prices <- close[valid_close]
        valid_indices <- which(valid_close)
        window_size <- min(63, length(valid_prices))
        if (length(valid_prices) >= window_size) {
          dd_values <- sapply(1:(length(valid_prices) - window_size + 1), function(i) {
            window_prices <- valid_prices[i:(i + window_size - 1)]
            if (any(is.na(window_prices)) || length(window_prices) < 2) return(NA_real_)
            returns <- diff(window_prices) / window_prices[-length(window_prices)]
            if (any(is.na(returns)) || length(returns) == 0) return(NA_real_)
            cum_returns <- cumprod(1 + returns)
            max_dd <- min(cum_returns / cummax(cum_returns) - 1, na.rm = TRUE)
            if (is.finite(max_dd)) max_dd else NA_real_
          })
          if (length(dd_values) > 0) {
            start_idx <- valid_indices[1] + window_size - 1
            end_idx <- valid_indices[length(valid_indices)]
            result[start_idx:end_idx] <- dd_values[1:min(length(dd_values), length(start_idx:end_idx))]
          }
        }
      }
      result
    }, by = company_id]
  }
  log_message("  63-day drawdown calculated")

  # ----------------------------------------------------------------------------
  # 4. Volume Metrics (from original mmtm.R and previous module version)
  # ----------------------------------------------------------------------------

  # Volume moving averages
  if (!"vol_ma_5" %in% names(dt)) dt[, vol_ma_5 := data.table::frollmean(volume, 5, align = "right"), by = company_id]
  if (!"vol_ma_20" %in% names(dt)) dt[, vol_ma_20 := data.table::frollmean(volume, 20, align = "right"), by = company_id]
  if (!"vol_ma_50" %in% names(dt)) dt[, vol_ma_50 := data.table::frollmean(volume, 50, align = "right"), by = company_id]
  if (!"vol_8d_avg" %in% names(dt)) dt[, vol_8d_avg := data.table::frollmean(volume, 8, align = "right"), by = company_id] # Added from old mmtm
  if (!"vol_21d_avg" %in% names(dt)) dt[, vol_21d_avg := data.table::frollmean(volume, 21, align = "right"), by = company_id] # Added from old mmtm
  if (!"vol_63d_avg" %in% names(dt)) dt[, vol_63d_avg := data.table::frollmean(volume, 63, align = "right"), by = company_id] # Added from old mmtm
  log_message("  Volume MAs calculated")

  if (!"volume_ratio" %in% names(dt)) dt[, volume_ratio := frollmean(volume, 8, align = "right") / (frollmean(volume, 21, align = "right") + 1e-9), by = company_id] # Added from old mmtm
  log_message("  Volume ratio calculated")

  # Volume-based flags
  if (!"volume_surge" %in% names(dt)) dt[, volume_surge := volume > 2 * pmax(vol_ma_20, 1e-9)]
  if (!"volume_signal_20" %in% names(dt)) dt[, volume_signal_20 := volume > pmax(vol_ma_20, 1e-9) & volume > data.table::shift(volume, 1), by = company_id]
  log_message("  Volume surge/signal calculated")

  # VWAP 20d
  if (!"vwap_20d" %in% names(dt)) dt[, vwap_20d := data.table::frollsum(close * volume, 20, align = "right") / pmax(data.table::frollsum(volume, 20, align = "right"), 1e-9), by = company_id]
  log_message("  VWAP 20d calculated")

  # OBV and trend
  if (!"obv" %in% names(dt)) {
    log_message("  Calculating OBV...", "DEBUG")
    dt[, obv := {
      temp_dt <- na.omit(.SD, cols = c("close", "volume"))
      
      obv_values <- rep(NA_real_, .N) # Pre-allocate result vector with NAs
      
      if (nrow(temp_dt) > 0) {
        # Explicitly convert to matrix for TTR functions
        close_vector <- as.vector(temp_dt$close)
        volume_vector <- as.vector(temp_dt$volume)
        
        # TTR::OBV requires price and volume vectors
        if (length(close_vector) > 0 && length(volume_vector) > 0) { 
          calculated_obv <- TTR::OBV(price = close_vector, volume = volume_vector)
          
          # Map calculated_obv back to the original .N length
          if (length(calculated_obv) > 0) {
            original_valid_indices <- which(!is.na(close) & !is.na(volume))
            start_fill_idx <- original_valid_indices[length(original_valid_indices) - length(calculated_obv) + 1]
            end_fill_idx <- tail(original_valid_indices, 1)
            
            if (start_fill_idx > 0 && end_fill_idx >= start_fill_idx) {
              obv_values[start_fill_idx:end_fill_idx] <- calculated_obv
            }
          }
        }
      }
      obv_values # Return the pre-allocated vector with NAs and calculated values
    }, by = company_id]
  }
  if (!"obv_ma_20" %in% names(dt)) dt[, obv_ma_20 := data.table::frollmean(obv, 20, align = "right"), by = company_id]
  if (!"obv_ma_50" %in% names(dt)) dt[, obv_ma_50 := data.table::frollmean(obv, 50, align = "right"), by = company_id]
  if (!"obv_trend" %in% names(dt)) dt[, obv_trend := ifelse(obv_ma_20 > obv_ma_50, "up", "down")]
  log_message("  OBV and OBV trend calculated")

  # Volume momentum (from original mmtm.R)
  if (!"vol_momentum" %in% names(dt)) {
    dt[, vol_momentum := {
      if (.N >= 5) {
        x <- 1:5
        x_bar <- mean(x)
        y_bar <- frollmean(volume, 5, align = "right")
        xy_bar <- frollmean(volume * x, 5, align = "right")
        x_sq_bar <- mean(x^2)
        momentum <- (xy_bar - x_bar * y_bar) / (x_sq_bar - x_bar^2 + 1e-9)
        ifelse(is.finite(momentum), momentum, NA_real_)
      } else { NA_real_ }
    }, by = company_id]
  }
  log_message("  Volume momentum calculated")

  # Optimized buying pressure and volume metrics (from original mmtm.R)
  if (!"accumulation_day" %in% names(dt)) {
    dt[, accumulation_day := (close > open) & (close > (high + low) / 2) & (volume > 1.5 * vol_21d_avg) & (close > ma_50)]
  }
  if (!"buying_pressure_pct_change" %in% names(dt)) { # Renamed to avoid conflict with `buying_pressure_orig_21d_pct`
    dt[, buying_pressure_pct_change := {
      if (.N >= 5) {
        (close / shift(close, 4, type = "lag") - 1) * 100
      } else { NA_real_ }
    }, by = company_id]
  }
  if (!"absorption" %in% names(dt)) {
    dt[, absorption := (abs(close - open) / (pmax(high - low, 1e-9)) < 0.3) & (volume > 1.5 * vol_21d_avg)]
  }
  log_message("  Accumulation day, buying pressure (pct change), absorption calculated")

  # Volume delta calculation (from original mmtm.R)
  if (!"volume_delta_ma" %in% names(dt)) { # Renamed to avoid conflict
    dt[, buy_vol_temp := volume * (close > open) + volume * 0.5 * (close == open)]
    dt[, sell_vol_temp := volume * (close < open) + volume * 0.5 * (close == open)]
    dt[, volume_delta_ma := {
      if (.N >= 5) {
        buy_sum <- frollsum(buy_vol_temp, 5, align = "right")
        sell_sum <- frollsum(sell_vol_temp, 5, align = "right")
        vol_sum <- frollsum(volume, 5, align = "right")
        (buy_sum - sell_sum) / (vol_sum + 1e-9)
      } else { NA_real_ }
    }, by = company_id]
    dt[, c("buy_vol_temp", "sell_vol_temp") := NULL]
  }
  log_message("  Volume delta (MA) calculated")

  # Block trades detection (from original mmtm.R)
  if (!"block_trade" %in% names(dt)) {
    dt[, block_trade := volume > 5 * frollmean(volume, 63, align = "right"), by = company_id]
  }
  log_message("  Block trades calculated")


  # Institutional support calculation
  if (!"institutional_support" %in% names(dt)) {
    log_message("Calculating institutional support levels...")
    dt[, vol_price := round(close * 2) / 2] # Pre-compute rounded prices

    dt[, institutional_support := {
      res <- logical(.N) # Pre-allocate result vector

      for (i in 1:.N) {
        current_date <- date[i]
        current_close <- close[i]

        # Define window for the current date (63 days lookback)
        window_start_date <- current_date - 63

        # Get data for the window using .SD to avoid copying large dt
        window_data <- .SD[date >= window_start_date & date <= current_date]

        if (nrow(window_data) >= 5) { # Minimum 5 days for analysis
          # Aggregate volume by rounded price within the window
          vol_dist <- window_data[, .(total_v = sum(volume, na.rm = TRUE)), by = vol_price]

          if (nrow(vol_dist) > 0) {
            # Get top 3 price levels by volume
            data.table::setorderv(vol_dist, "total_v", order = -1L)
            top_prices <- vol_dist[1:min(3, nrow(vol_dist)), vol_price]

            # Check if current close is near any of the top prices
            res[i] <- any(abs(current_close - top_prices) / current_close < 0.01, na.rm = TRUE)
          } else {
            res[i] <- FALSE
          }
        } else {
          res[i] <- FALSE
        }
      }
      res
    }, by = company_id]
    dt[, vol_price := NULL] # Clean up temp column
  }
  log_message("  Institutional support calculated")

  # ----------------------------------------------------------------------------
  # 5. Oscillators (from previous module version)
  # ----------------------------------------------------------------------------

  # RSI
  if (!"rsi" %in% names(dt)) {
    log_message("  Calculating RSI...", "DEBUG")
    dt[, rsi := {
      temp_dt <- na.omit(.SD, cols = "close")
      
      rsi_values <- rep(NA_real_, .N) # Pre-allocate result vector with NAs
      
      if (nrow(temp_dt) > 0) {
        # Explicitly convert to matrix for TTR functions
        close_matrix <- as.matrix(temp_dt$close)
        
        if (nrow(close_matrix) >= 14) { # RSI requires at least 'n' (14) observations
          calculated_rsi <- as.numeric(TTR::RSI(price = as.numeric(temp_dt$close), n = 14))
          
          # Map calculated_rsi back to the original .N length
          if (length(calculated_rsi) > 0) {
            original_valid_indices <- which(!is.na(close))
            start_fill_idx <- original_valid_indices[length(original_valid_indices) - length(calculated_rsi) + 1]
            end_fill_idx <- tail(original_valid_indices, 1)
            
            if (start_fill_idx > 0 && end_fill_idx >= start_fill_idx) {
              rsi_values[start_fill_idx:end_fill_idx] <- calculated_rsi
            }
          }
        }
      }
      rsi_values # Return the pre-allocated vector with NAs and calculated values
    }, by = company_id]
    log_message("  RSI calculated", "DEBUG")
  }
  # Old RSI calculation: if (!"rsi" %in% names(dt)) dt[, rsi := TTR::RSI(close, n = 14), by = company_id]
  # log_message("  RSI calculated")

  # Robust ADX calculation with comprehensive error handling
  if (!"adx" %in% names(dt)) {
    log_message("  Calculating ADX with comprehensive error handling...", "DEBUG")
    
    # Custom ADX implementation that's more robust than TTR::ADX
    safe_adx <- function(high, low, close, n = 14) {
      tryCatch({
        # Ensure we have enough data and valid inputs
        if (length(high) < n * 2 || length(low) != length(high) || length(close) != length(high)) {
          return(rep(NA_real_, length(high)))
        }
        
        # Ensure no NAs in the middle of the series
        valid_idx <- !is.na(high) & !is.na(low) & !is.na(close)
        if (sum(valid_idx) < n * 2) {
          return(rep(NA_real_, length(high)))
        }
        
        # Use only valid data points
        h <- high[valid_idx]
        l <- low[valid_idx]
        c <- close[valid_idx]
        
        # Calculate True Range (TR)
        h_minus_l <- h - l
        h_minus_pc <- c(NA, abs(h[-1] - c[-length(c)]))
        l_minus_pc <- c(NA, abs(l[-1] - c[-length(c)]))
        tr <- pmax(h_minus_l, h_minus_pc, l_minus_pc, na.rm = TRUE)
        
        # Calculate Directional Movement (+DM and -DM)
        up_move <- c(NA, h[-1] - h[-length(h)])
        down_move <- c(NA, l[-length(l)] - l[-1])
        
        plus_dm <- ifelse(up_move > pmax(down_move, 0, na.rm = TRUE), up_move, 0)
        minus_dm <- ifelse(down_move > pmax(up_move, 0, na.rm = TRUE), down_move, 0)
        
        # Initialize smoothed values
        tr_smooth <- rep(NA_real_, length(h))
        plus_dm_smooth <- rep(0, length(h))
        minus_dm_smooth <- rep(0, length(h))
        
        # First value is sum of first n TRs
        tr_smooth[n] <- sum(tr[1:n], na.rm = TRUE)
        plus_dm_smooth[n] <- sum(plus_dm[1:n], na.rm = TRUE)
        minus_dm_smooth[n] <- sum(minus_dm[1:n], na.rm = TRUE)
        
        # Calculate subsequent values using Wilder's smoothing
        for (i in (n+1):length(h)) {
          tr_smooth[i] <- (tr_smooth[i-1] * (n-1) + tr[i]) / n
          plus_dm_smooth[i] <- (plus_dm_smooth[i-1] * (n-1) + plus_dm[i]) / n
          minus_dm_smooth[i] <- (minus_dm_smooth[i-1] * (n-1) + minus_dm[i]) / n
        }
        
        # Calculate +DI and -DI (with protection against division by zero)
        plus_di <- 100 * plus_dm_smooth / (tr_smooth + 1e-10)
        minus_di <- 100 * minus_dm_smooth / (tr_smooth + 1e-10)
        
        # Calculate DX (Directional Movement Index)
        dx <- 100 * abs(plus_di - minus_di) / (plus_di + minus_di + 1e-10)
        
        # Calculate ADX (smoothed DX)
        adx <- rep(NA_real_, length(h))
        adx[n*2-1] <- mean(dx[n:(n*2-1)], na.rm = TRUE)
        
        for (i in (n*2):length(h)) {
          adx[i] <- (adx[i-1] * (n-1) + dx[i]) / n
        }
        
        # Map back to original indices
        result <- rep(NA_real_, length(high))
        result[valid_idx] <- c(rep(NA, n*2-2), adx[-(1:(n*2-2))])
        return(result)
        
      }, error = function(e) {
        log_message(sprintf("Error in safe_adx: %s", e$message), "ERROR")
        return(rep(NA_real_, length(high)))
      })
    }
    
    # Calculate ADX for each company
    dt[, adx := {
      # Only calculate if we have enough data
      if (.N >= 28) {
        safe_adx(high, low, close, n = 14)
      } else {
        rep(NA_real_, .N)
      }
    }, by = company_id]
    
    log_message("  ADX calculation completed", "DEBUG")
  }
  # Old ADX calculation: if (!"adx" %in% names(dt)) {
  #   dt[, adx := {
  #     result <- rep(NA_real_, .N)
  #     if (.N >= 28) {
  #       tryCatch({
  #         adx_result <- TTR::ADX(cbind(high, low, close), n = 14)
  #         if (!is.null(adx_result) && nrow(adx_result) > 0) {
  #           adx_col <- grep("^ADX", colnames(adx_result), value = TRUE, ignore.case = TRUE)[1]
  #           if (!is.na(adx_col) && adx_col %in% colnames(adx_result)) {
  #             start_idx <- .N - nrow(adx_result) + 1
  #             if (start_idx > 0) { result[start_idx:.N] <- adx_result[[adx_col]] }
  #           }
  #         }
  #       }, error = function(e) { NULL })
  #     }
  #     result
  #   }, by = company_id]
  # }
  # log_message("  ADX calculated")

  # MACD signals
  if (!"macd_line" %in% names(dt)) {
    log_message("  Calculating MACD...", "DEBUG")
    macd_calc <- function(x) {
      # Ensure no NAs in input for MACD calculation
      x_omit_na <- na.omit(x)
      log_message(sprintf("  DEBUG (MACD - company %s): x_omit_na length: %d", .BY$company_id, length(x_omit_na)), "DEBUG")
      if (length(x_omit_na) < 26) { # MACD requires at least 26 observations (nSlow)
        log_message(sprintf("  DEBUG (MACD - company %s): Insufficient data (%d rows) for MACD calculation, needs at least 26.", .BY$company_id, length(x_omit_na)), "DEBUG")
        return(list(line=rep(NA_real_, length(x)), sig=rep(NA_real_, length(x)), hist=rep(NA_real_, length(x))))
      }
      m <- TTR::MACD(as.matrix(x_omit_na), nFast = 12, nSlow = 26, nSig = 9)
      if (is.null(m) || ncol(m) < 2 || nrow(m) == 0) {
        log_message(sprintf("  DEBUG (MACD - company %s): TTR::MACD returned invalid output (null, <2 cols, or 0 rows).", .BY$company_id), "DEBUG")
        return(list(line=rep(NA_real_, length(x)), sig=rep(NA_real_, length(x)), hist=rep(NA_real_, length(x))))
      }
      
      # Pad with NAs at the beginning to match original length
      num_na_front <- length(x) - nrow(m)
      log_message(sprintf("  DEBUG (MACD - company %s): MACD output dimensions: %s, num_na_front: %d", .BY$company_id, paste(dim(m), collapse = "x"), num_na_front), "DEBUG")
      list(line = c(rep(NA_real_, num_na_front), m[,1]),
           sig = c(rep(NA_real_, num_na_front), m[,2]),
           hist = c(rep(NA_real_, num_na_front), m[,1] - m[,2]))
    }
    macd_dt <- dt[, macd_calc(close), by = company_id]
    dt[, macd_line := macd_dt$line]
    dt[, macd_signal := macd_dt$sig]
    dt[, macd_hist := macd_dt$hist]
    dt[, macd_bullish_cross := (macd_line > macd_signal) & (data.table::shift(macd_line, 1) <= data.table::shift(macd_signal, 1)), by = company_id]
    dt[, macd_bearish_cross := (macd_line < macd_signal) & (data.table::shift(macd_line, 1) >= data.table::shift(macd_signal, 1)), by = company_id]
    dt[, macd_hist_trend := data.table::frollmean(macd_hist, 3, align = "right") > data.table::shift(data.table::frollmean(macd_hist, 3, align = "right"), 1), by = company_id]
    log_message("  MACD indicators calculated", "DEBUG")
  }
  # Old MACD calculation: if (!"macd_line" %in% names(dt)) {
  #   macd_calc <- function(x) {
  #     m <- TTR::MACD(x, nFast = 12, nSlow = 26, nSig = 9)
  #     if (is.null(m)) return(list(line=rep(NA_real_, length(x)), sig=rep(NA_real_, length(x)), hist=rep(NA_real_, length(x))))
  #     list(line = m[,1], sig = m[,2], hist = m[,1] - m[,2])
  #   }
  #   macd_dt <- dt[, macd_calc(close), by = company_id]
  #   dt[, macd_line := macd_dt$line]
  #   dt[, macd_signal := macd_dt$sig]
  #   dt[, macd_hist := macd_dt$hist]
  #   dt[, macd_bullish_cross := (macd_line > macd_signal) & (data.table::shift(macd_line, 1) <= data.table::shift(macd_signal, 1)), by = company_id]
  #   dt[, macd_bearish_cross := (macd_line < macd_signal) & (data.table::shift(macd_line, 1) >= data.table::shift(macd_signal, 1)), by = company_id]
  #   dt[, macd_hist_trend := data.table::frollmean(macd_hist, 3, align = "right") > data.table::shift(data.table::frollmean(macd_hist, 3, align = "right"), 1), by = company_id]
  # }
  # log_message("  MACD indicators calculated")

  # Stochastic oscillator
  if (!"stoch_k" %in% names(dt)) {
    log_message("  Calculating Stochastic indicators...", "DEBUG")
    dt[, c("stoch_k", "stoch_d") := {
      # Create a temporary data.table for Stochastic calculation with only required columns
      temp_stoch_dt <- na.omit(.SD, cols = c("high", "low", "close"))
      
      k_val <- rep(NA_real_, .N)
      d_val <- rep(NA_real_, .N)
      
      if (nrow(temp_stoch_dt) < 14) { # Stochastic requires at least 14 observations (nFastK)
        log_message(sprintf("  DEBUG (Stoch - company %s): Insufficient data (%d rows) for Stochastic calculation, needs at least 14.", .BY$company_id, nrow(temp_stoch_dt)), "DEBUG")
        return(list(k_val, d_val))
      }
      
      hlc_matrix <- as.matrix(temp_stoch_dt[, .(high, low, close)])
      log_message(sprintf("  DEBUG (Stoch - company %s): HLC matrix dimensions: %s, class: %s", .BY$company_id, paste(dim(hlc_matrix), collapse = "x"), class(hlc_matrix)), "DEBUG")
      stoch_res <- TTR::stoch(HLC = hlc_matrix, nFastK = 14, nFastD = 3, nSlowD = 3)
      
      if (!is.null(stoch_res) && nrow(stoch_res) > 0) {
        # Map the calculated Stochastic values back to the original rows
        original_row_indices <- which(!is.na(high) & !is.na(low) & !is.na(close))
        
        if (length(original_row_indices) >= nrow(stoch_res)) {
          start_fill_idx <- original_row_indices[length(original_row_indices) - nrow(stoch_res) + 1]
          end_fill_idx <- tail(original_row_indices, 1)
          
          if (start_fill_idx > 0 && end_fill_idx >= start_fill_idx) {
            k_val[start_fill_idx:end_fill_idx] <- stoch_res[,'fastK']
            d_val[start_fill_idx:end_fill_idx] <- stoch_res[,'slowD']
          }
        }
      }
      list(k_val, d_val)
    }, by = company_id]
    
    dt[, stoch_overbought := stoch_k > 80]
    dt[, stoch_oversold := stoch_k < 20]
    dt[, stoch_bullish_cross := stoch_k > stoch_d & data.table::shift(stoch_k, 1) <= data.table::shift(stoch_d, 1), by = company_id]
    dt[, stoch_bearish_cross := stoch_k < stoch_d & data.table::shift(stoch_k, 1) >= data.table::shift(stoch_d, 1), by = company_id]
  }
  log_message("  Stochastic indicators calculated", "DEBUG")

  # ----------------------------------------------------------------------------
  # 6. Risk and Position Sizing Metrics (from original mmtm.R)
  # ----------------------------------------------------------------------------

  if (!"var_1d" %in% names(dt) || !"max_drawdown_252d" %in% names(dt) || !"sharpe_ratio" %in% names(dt)) {
    log_message("Calculating risk metrics (VaR, Max Drawdown, Sharpe)...")
    dt[, `:=`(
      var_1d = NA_real_,
      max_drawdown_252d = NA_real_,
      sharpe_ratio = NA_real_,
      var_calc_status = NA_character_
    )]

    required_cols_risk <- c("company_id", "return_1d", "close")
    missing_cols_risk <- setdiff(required_cols_risk, names(dt))
    if (length(missing_cols_risk) > 0) {
      for (col in missing_cols_risk) dt[, (col) := NA_real_]
    }

    valid_companies_risk <- dt[, {
      valid_days <- sum(!is.na(return_1d) & is.finite(return_1d))
      list(valid = valid_days >= 21, count = .N, valid_days = valid_days)
    }, by = company_id][valid == TRUE, company_id]

    if (length(valid_companies_risk) > 0) {
      chunk_size <- 200
      num_chunks <- ceiling(length(valid_companies_risk) / chunk_size)
      for (i in 1:num_chunks) {
        start_idx <- (i - 1) * chunk_size + 1
        end_idx <- min(i * chunk_size, length(valid_companies_risk))
        current_companies <- valid_companies_risk[start_idx:end_idx]

        dt[company_id %in% current_companies, {
          var_1d_val <- rep(NA_real_, .N)
          sharpe_val <- rep(NA_real_, .N)
          max_dd <- rep(NA_real_, .N)
          status_calc <- "insufficient_data"

          tryCatch({
            valid_returns <- !is.na(return_1d) & is.finite(return_1d)
            if (sum(valid_returns) >= 21) {
              roll_mean <- frollmean(return_1d, 21, align = "right", na.rm = TRUE)
              roll_mean_sq <- frollmean(return_1d^2, 21, align = "right", na.rm = TRUE)
              variance <- pmax(0, roll_mean_sq - roll_mean^2)
              roll_sd <- sqrt(variance)
              var_1d_val <- roll_mean + qnorm(0.05) * roll_sd
              sharpe_val <- ifelse(roll_sd > 1e-9,
                                   roll_mean / roll_sd * sqrt(252),
                                   sign(roll_mean) * Inf)
              sharpe_val <- pmin(pmax(sharpe_val, -10), 10)

              if (.N >= 21) {
                roll_max <- frollapply(close, min(.N, 252), max, align = "right", na.rm = TRUE)
                valid_prices <- !is.na(close) & close > 0 & !is.na(roll_max) & roll_max > 0
                drawdown_calc <- rep(NA_real_, .N)
                drawdown_calc[valid_prices] <- (close[valid_prices] - roll_max[valid_prices]) / roll_max[valid_prices]
                max_dd <- frollapply(drawdown_calc, min(.N, 252), min, align = "right", na.rm = FALSE)
                if (sum(!is.na(max_dd)) < 21) max_dd <- rep(NA_real_, .N)
              }
              max_dd <- pmin(pmax(max_dd, -1), 0, na.rm = FALSE)
              status_calc <- "success"
            }
          }, error = function(e) {
            log_message(sprintf("Error calculating risk metrics for company %s: %s",
                               .BY$company_id, e$message), "ERROR")
            status_calc <<- paste0("error: ", conditionMessage(e))
          })
          .(
            var_1d = var_1d_val,
            max_drawdown_252d = max_dd,
            sharpe_ratio = sharpe_val,
            var_calc_status = status_calc
          )
        }, by = company_id]
      }
    }
  }
  log_message("  Risk metrics (VaR, Max Drawdown, Sharpe) calculated")

  if (!"kelly_fraction" %in% names(dt)) {
    log_message("Calculating position sizing (Kelly fraction)...")
    dt[, kelly_fraction := {
      kf <- calculate_kelly_fraction(return_1d) # Using the helper function
      rep(ifelse(is.na(kf), 0.1, kf), .N) # Default to 10% if calculation failed
    }, by = company_id]
    dt[is.na(kelly_fraction), kelly_fraction := 0.1]
  }
  log_message("  Kelly fraction calculated")

  # Smart money score (from original mmtm.R, with robust version)
  if (!"smart_money_score" %in% names(dt)) {
    log_message("Calculating smart money score (robust version)...")
    dt[, smart_money_score := pmin(100, 50 + 10 * as.integer(accumulation_day) +
                                   5 * as.integer(absorption) + 5 * pmin(1, buying_pressure_pct_change / 2)), by = company_id]
  }
  if (!"smart_money_score_legacy" %in% names(dt)) { # Legacy version for comparison if needed
    log_message("Calculating smart money score (legacy version)...")
    dt[, smart_money_score_legacy := {
      score_val <- 50
      if (!is.null(dt$accumulation_day_orig) && any(accumulation_day_orig, na.rm = TRUE)) score_val <- score_val + 10
      if (!is.null(dt$buying_pressure_orig_21d_pct) && any(buying_pressure_orig_21d_pct > 0.6, na.rm = TRUE)) score_val <- score_val + 10
      if (!is.null(dt$absorption_orig) && any(absorption_orig, na.rm = TRUE)) score_val <- score_val + 10
      pmin(score_val, 100)
    }, by = company_id]
  }
  log_message("  Smart money score calculated")

  # Composite risk score (from original mmtm.R)
  if (!"risk_score" %in% names(dt)) {
    log_message("Calculating composite risk score...")
    dt[, risk_score := {
      # 1. Calculate component scores (0-100 scale, higher = riskier)
      vol_risk <- safe_ecdf(vol_21d)
      dd_risk <- if (all(is.na(max_drawdown_252d))) rep(NA_real_, .N) else safe_ecdf(abs(max_drawdown_252d))
      var_risk <- safe_ecdf(abs(var_1d))
      sharpe_risk <- if (all(is.na(sharpe_ratio))) rep(NA_real_, .N) else 100 - safe_ecdf(sharpe_ratio)

      vol_sd_calc <- frollapply(volume, 21, sd, na.rm = TRUE, align = "right")
      vol_mean_calc <- frollmean(volume, 21, na.rm = TRUE, align = "right")
      vol_cv <- ifelse(vol_mean_calc > 0, vol_sd_calc / vol_mean_calc * 100, 0)
      volume_stability <- safe_ecdf(vol_cv)

      price_sd_calc <- frollapply(close, 21, sd, na.rm = TRUE, align = "right")
      price_mean_calc <- frollmean(close, 21, na.rm = TRUE, align = "right")
      price_cv <- ifelse(price_mean_calc > 0, price_sd_calc / price_mean_calc * 100, 0)
      price_stability <- safe_ecdf(price_cv)

      # 2. Define component weights
      weights <- c(
        vol_risk = 0.20,
        dd_risk = 0.20,
        var_risk = 0.20,
        sharpe_risk = 0.15,
        volume_stability = 0.15,
        price_stability = 0.10
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
      risk_score_calc <- rep(NA_real_, .N)
      for (i in 1:.N) {
        row_components <- as.numeric(component_values[i])
        row_weights <- weights[!is.na(row_components)]
        row_values <- row_components[!is.na(row_components)]
        if (length(row_values) > 0) {
          risk_score_calc[i] <- sum(row_values * row_weights) / sum(row_weights) * 100
        }
      }
      pmin(pmax(risk_score_calc, 0), 100)
    }, by = .(company_id)]
    dt[, risk_category := cut(risk_score,
                              breaks = c(0, 20, 40, 60, 80, 100),
                              labels = c("Very High", "High", "Medium", "Low", "Very Low"),
                              include.lowest = TRUE)]
  }
  log_message("  Composite risk score and risk category calculated")

  # Clean up temporary columns
  # Note: "running_max" might be from a different context, adding for safety if it exists
  if ("running_max" %in% names(dt)) dt[, running_max := NULL]
  if ("day_range" %in% names(dt)) dt[, day_range := NULL]

  log_message("All core and enriched indicators calculated.")

  return(dt)
}

# No side effects on source; function only. 