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
  if (!"ma_100" %in% names(dt)) dt[, ma_100 := data.table::frollmean(close, 100, align = "right"), by = company_id]
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
    
    # Define required columns
    req_cols <- c("high", "low", "close")
    
    # Check if all required columns exist in the data.table
    if (!all(req_cols %in% names(dt))) {
      missing_cols <- setdiff(req_cols, names(dt))
      log_message(sprintf("  ERROR: Missing required columns for ATR: %s", 
                         paste(missing_cols, collapse=", ")), "ERROR")
      dt[, atr := NA_real_]
    } else {
      # Calculate ATR directly without tryCatch to avoid scoping issues
      dt[, atr := {
        # Calculate True Range
        tr <- pmax(high - low, 
                  abs(high - data.table::shift(close, 1)), 
                  abs(low - data.table::shift(close, 1)), 
                  na.rm = TRUE)
        
        # Calculate ATR using a simple moving average of TR
        atr <- data.table::frollmean(tr, n = 14, align = "right", na.rm = TRUE)
        
        # Return the ATR values
        atr
      }, by = company_id]
      log_message("  ATR calculation completed")
    }
  }
  # Old ATR calculation: if (!"atr" %in% names(dt)) dt[, atr := TTR::ATR(HLC = dt[, .(high, low, close)], n = 14)$atr, by = company_id] # Use TTR's ATR
  # log_message("  ATR calculated")

  if (!"atr_pct" %in% names(dt)) {
    dt[, atr_pct := atr / pmax(close, 1e-9) * 100]
  }

  if (!"vol_5d" %in% names(dt)) {
    dt[, vol_5d := {
      if (.N >= 5) {
        mean5 <- frollmean(return_1d, 5, align = "right", na.rm = TRUE)
        mean_sq5 <- frollmean(return_1d^2, 5, align = "right", na.rm = TRUE)
        sqrt(pmax(mean_sq5 - mean5^2, 0, na.rm = TRUE)) * sqrt(252)
      } else { NA_real_ }
    }, by = company_id]
  }
  # 21-day price volatility (annualized) to match legacy pipeline expectations
  if (!"vol_21d" %in% names(dt)) {
    dt[, vol_21d := {
      if (.N >= 21) {
        mean21 <- frollmean(return_1d, 21, align = "right", na.rm = TRUE)
        mean_sq21 <- frollmean(return_1d^2, 21, align = "right", na.rm = TRUE)
        sqrt(pmax(mean_sq21 - mean21^2, 0, na.rm = TRUE)) * sqrt(252)
      } else { NA_real_ }
    }, by = company_id]
  }
  # 21-day volume coefficient-of-variation (kept separately)
  if (!"vol_cv_21d" %in% names(dt)) {
    dt[, vol_cv_21d := {
      if (.N >= 21) {
        vol_mean <- frollmean(volume, 21, align = "right", na.rm = TRUE)
        vol_sq <- frollmean(volume^2, 21, align = "right", na.rm = TRUE)
        vol_var <- vol_sq - vol_mean^2
        vol_sd <- sqrt(pmax(vol_var, 0))
        result <- vol_sd / (vol_mean + 1e-10)
        result[is.infinite(result) | is.nan(result)] <- NA_real_
        result
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
  if (!"high_252d" %in% names(dt)) dt[, high_252d := data.table::frollapply(high, 252, max, align = "right", na.rm = TRUE), by = company_id]
  if (!"low_252d" %in% names(dt)) dt[, low_252d := data.table::frollapply(low, 252, min, align = "right", na.rm = TRUE), by = company_id]
  if (!"near_52wk_high" %in% names(dt)) dt[, near_52wk_high := close >= 0.95 * high_252d]
  if (!"drawdown_52wk" %in% names(dt)) dt[, drawdown_52wk := (close - high_252d) / pmax(high_252d, 1e-9) * 100]
  if (!"recovery_factor" %in% names(dt)) dt[, recovery_factor := (close / pmax(low_252d, 1e-9) - 1) * 100]
  
  # Add missing high/low indicators for rules (avoid duplication)
  if (!"high_5d" %in% names(dt)) dt[, high_5d := data.table::frollapply(high, 5, max, align = "right", na.rm = TRUE), by = company_id]
  if (!"low_5d" %in% names(dt)) dt[, low_5d := data.table::frollapply(low, 5, min, align = "right", na.rm = TRUE), by = company_id]
  
  # Add price vs MA indicators needed by rules
  if (!"price_vs_ma21" %in% names(dt)) dt[, price_vs_ma21 := (close / pmax(ma_21, 1e-9) - 1) * 100]
  if (!"price_vs_ma50" %in% names(dt)) dt[, price_vs_ma50 := (close / pmax(ma_50, 1e-9) - 1) * 100]
  
  log_message("  52-week context and price levels calculated")

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
      roll_max <- data.table::frollapply(close, 63, max, align = "right", na.rm = TRUE)
      out <- rep(NA_real_, .N)
      ok <- !is.na(close) & close > 0 & !is.na(roll_max) & roll_max > 0
      out[ok] <- close[ok] / roll_max[ok] - 1
      out
    }, by = company_id]
  }
  log_message("  63-day drawdown calculated")

  if (!"LOW_DRAWDOWN" %in% names(dt)) {
    dt[, LOW_DRAWDOWN := as.integer(!is.na(drawdown) & drawdown > -0.10)]
  }

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
  if (!"dollar_vol_20d" %in% names(dt)) dt[, dollar_vol_20d := vol_ma_20 * close]
  log_message("  Volume MAs calculated")

  if (!"volume_ratio" %in% names(dt)) dt[, volume_ratio := frollmean(volume, 8, align = "right") / (frollmean(volume, 21, align = "right") + 1e-9), by = company_id] # Added from old mmtm
  log_message("  Volume ratio calculated")

  # Volume-based flags
  if (!"volume_surge" %in% names(dt)) dt[, volume_surge := volume > 2 * pmax(vol_ma_20, 1e-9)]
  if (!"volume_spike" %in% names(dt)) dt[, volume_spike := volume > 2.5 * pmax(vol_ma_20, 1e-9)]
  if (!"volume_signal_20" %in% names(dt)) dt[, volume_signal_20 := volume > pmax(vol_ma_20, 1e-9) & volume > data.table::shift(volume, 1), by = company_id]
  if (!"volume_accumulation" %in% names(dt)) {
    dt[, volume_accumulation := (close > open) & (volume > 1.2 * pmax(vol_ma_20, 1e-9))]
  }
  if (!"volume_trend_strength" %in% names(dt)) {
    dt[, volume_trend_strength := (vol_ma_20 / pmax(data.table::shift(vol_ma_20, 20), 1e-9) - 1) * 100, by = company_id]
  }
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
  # Add buying_pressure indicator needed by rules
  if (!"buying_pressure" %in% names(dt)) {
    dt[, buying_pressure := {
      # Simple buying pressure: positive volume when up, negative when down
      ifelse(close > open, volume, -volume)
    }]
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
    dt[, block_trade := {
      adv_63 <- data.table::frollmean(volume, 63, align = "right", na.rm = TRUE)
      threshold <- 5 * pmax(data.table::shift(adv_63, 1), 1e-9)
      !is.na(volume) & volume > threshold
    }, by = company_id]
  }
  log_message("  Block trades calculated")


  # Extreme Persistence Score (EPS) - % time stock spends ≥10% away from MA50
  if (!"extreme_persistence_score" %in% names(dt)) {
    log_message("Calculating Extreme Persistence Score (EPS)...")
    
    dt[, extreme_persistence_score := {
      # Calculate distance from MA50
      distance_pct <- abs(close - ma_50) / pmax(ma_50, 1e-9)
      
      # Flag days where distance ≥ 10%
      extreme_flag <- ifelse(distance_pct >= 0.10, 1, 0)
      
      # Rolling sum of extreme days over 250 trading days
      extreme_days <- data.table::frollsum(extreme_flag, 250, align = "right", na.rm = TRUE)
      
      # Calculate persistence score (0-1 range)
      persistence_score <- extreme_days / pmin(250, data.table::rowid(company_id))
      
      persistence_score
    }, by = company_id]
    
    # Directional persistence - separate for above and below MA
    dt[, eps_positive := {
      distance_positive <- (close - ma_50) / pmax(ma_50, 1e-9)
      extreme_positive_flag <- ifelse(distance_positive >= 0.10, 1, 0)
      extreme_positive_days <- data.table::frollsum(extreme_positive_flag, 250, align = "right", na.rm = TRUE)
      extreme_positive_days / pmin(250, data.table::rowid(company_id))
    }, by = company_id]
    
    dt[, eps_negative := {
      distance_negative <- (ma_50 - close) / pmax(ma_50, 1e-9)
      extreme_negative_flag <- ifelse(distance_negative >= 0.10, 1, 0)
      extreme_negative_days <- data.table::frollsum(extreme_negative_flag, 250, align = "right", na.rm = TRUE)
      extreme_negative_days / pmin(250, data.table::rowid(company_id))
    }, by = company_id]
    
    log_message("Extreme Persistence Score calculated")
  }
  
  # Volume Efficiency Ratio (VER) - measures accumulation vs distribution
  if (!"volume_efficiency_ratio" %in% names(dt)) {
    log_message("Calculating Volume Efficiency Ratio (VER)...")
    
    dt[, volume_efficiency_ratio := {
      # Absolute daily price change percentage
      price_change_pct <- abs(return_1d)
      
      # Volume ratio (current / 20-day average)
      vol_ratio <- volume / pmax(vol_ma_20, 1e-9)
      
      # VER = price_change / volume_ratio
      # Lower VER = high volume, low movement (accumulation)
      ver <- price_change_pct / pmax(vol_ratio, 1e-9)
      
      ver
    }, by = company_id]
    
    log_message("Volume Efficiency Ratio calculated")
  }
  
  # Accumulation Score - % days with accumulation characteristics
  if (!"accumulation_score" %in% names(dt)) {
    log_message("Calculating Accumulation Score...")
    
    dt[, accumulation_score := {
      # Daily accumulation flag
      accum_flag <- (
        !is.na(volume) & !is.na(return_1d) & !is.na(ma_21) & !is.na(vwap_20d) &
        volume >= 1.2 * pmax(vol_ma_20, 1e-9) &  # Above average volume
        abs(return_1d) <= 0.015 &  # Small price movement (≤1.5%)
        close >= pmax(ma_21, vwap_20d)  # Close above key references
      )
      
      # Rolling sum over 20 days
      accum_days <- data.table::frollsum(accum_flag, 20, align = "right", na.rm = TRUE)
      
      # Accumulation score (0-1 range)
      accum_score <- accum_days / pmin(20, data.table::rowid(company_id))
      
      accum_score
    }, by = company_id]
    
    log_message("Accumulation Score calculated")
  }

  # Pre-Move Probability Score (PMPS) - Measures pressure buildup for big moves
  if (!"pmps_score" %in% names(dt)) {
    log_message("Calculating Pre-Move Probability Score (PMPS)...")
    
    dt[, pmps_score := {
      # Block 1: EPS Regime Score (0-20)
      eps_score <- {
        eps_val <- extreme_persistence_score * 100  # Convert to 0-100 scale
        ifelse(eps_val < 5, 0,
        ifelse(eps_val < 8, 5,
        ifelse(eps_val < 12, 10,
        ifelse(eps_val < 18, 15, 20))))
      }
      
      # Block 2: Accumulation Persistence Score (0-20)
      accum_score <- {
        accum_val <- accumulation_score * 100  # Convert to 0-100 scale
        ifelse(accum_val < 15, 0,
        ifelse(accum_val < 25, 5,
        ifelse(accum_val < 35, 10,
        ifelse(accum_val < 50, 15, 20))))
      }
      
      # Block 3: Distribution Absence Score (0-20)
      # Distribution = 1 - accumulation_score (inverse logic)
      dist_score <- {
        dist_val <- (1 - accumulation_score) * 100  # Convert to 0-100 scale
        ifelse(dist_val > 40, 0,
        ifelse(dist_val > 30, 5,
        ifelse(dist_val > 20, 10,
        ifelse(dist_val > 10, 15, 20))))
      }
      
      # Block 4: Price Compression Score (0-20)
      compression_score <- {
        # ATR compression: ATR(14) / ATR(50)
        atr_14 <- data.table::frollapply(abs(return_1d), 14, function(x) mean(x, na.rm = TRUE))
        atr_50 <- data.table::frollapply(abs(return_1d), 50, function(x) mean(x, na.rm = TRUE))
        atr_ratio <- atr_14 / pmax(atr_50, 1e-9)
        
        atr_comp <- ifelse(atr_ratio > 1.0, 0,
                     ifelse(atr_ratio > 0.8, 5,
                     ifelse(atr_ratio > 0.6, 10,
                     ifelse(atr_ratio > 0.4, 15, 20))))
        
        # Range tightness: Last 5D range / 21D range
        range_5 <- high_5d - low_5d
        range_21 <- high_21d - low_21d
        range_ratio <- range_5 / pmax(range_21, 1e-9)
        
        range_comp <- ifelse(range_ratio < 0.1, 20,
                        ifelse(range_ratio < 0.2, 15,
                        ifelse(range_ratio < 0.3, 10,
                        ifelse(range_ratio < 0.4, 5, 0))))
        
        # Average of both methods
        (atr_comp + range_comp) / 2
      }
      
      # Block 5: Location/Structure Score (0-20)
      structure_score <- {
        ifelse(is.na(ma_50) | is.na(ma_21), 0,
        ifelse(close < ma_50, 0,  # Below MA50
        ifelse(close < ma_21, 5,  # Between MA50 & MA21
        ifelse(is.na(high_5d) | close < high_5d, 10,  # Below 5D high
        ifelse(compression_score > 15, 20, 15)))))  # At high + compression
      }
      
      # Final PMPS calculation (0-100 scale)
      pmps <- eps_score + accum_score + dist_score + compression_score + structure_score
      
      # Normalize to 0-100 range (max possible is 100)
      pmin(pmps, 100)
    }, by = company_id]
    
    log_message("Pre-Move Probability Score (PMPS) calculated")
  }

  # Whale behavior mode indicator - captures accumulation/pausing/distribution
  if (!"whale_behavior_mode" %in% names(dt)) {
    log_message("Calculating whale behavior mode...")
    
    dt[, whale_behavior_mode := {
      # Mode 1: Still Buying (Green)
      # High volume + price holds up + positive flow
      still_buying <- (
        !is.na(volume) & volume > 1.5 * pmax(vol_ma_20, 1e-9) &
        !is.na(close) & !is.na(ma_21) & close > ma_21 &
        !is.na(volume_delta_ma) & volume_delta_ma > 0 &
        !is.na(return_1d) & return_1d > -0.02  # Small pullbacks only
      )
      
      # Mode 3: Distributing (Red)  
      # High volume + price fails + negative flow
      distributing <- (
        !is.na(volume) & volume > 1.5 * pmax(vol_ma_20, 1e-9) &
        !is.na(close) & !is.na(ma_21) & close < ma_21 &
        !is.na(volume_delta_ma) & volume_delta_ma < 0 &
        !is.na(return_1d) & return_1d < -0.03  # Significant drops
      )
      
      # Mode 2: Pausing (Yellow) - default case
      fifelse(still_buying, "BUYING",
      fifelse(distributing, "DISTRIBUTING", "PAUSING"))
    }, by = company_id]
    
    # Enhanced institutional support - only true during BUYING mode
    dt[, institutional_support := {
      !is.na(whale_behavior_mode) & whale_behavior_mode == "BUYING"
    }]
    
    log_message("Whale behavior mode and enhanced institutional support calculated")
  }

  # ----------------------------------------------------------------------------
  # 5. Oscillators (from previous module version)
  # ----------------------------------------------------------------------------

  # RSI - Proper implementation within data.table
  if (!"rsi" %in% names(dt)) {
    log_message("  Calculating RSI...", "DEBUG")
    
    dt[, rsi := {
      # Calculate price changes
      delta <- c(NA, diff(close))
      
      # Separate gains and losses
      gain <- ifelse(delta > 0, delta, 0)
      loss <- ifelse(delta < 0, -delta, 0)
      
      # Calculate average gain and loss using wilder's smoothing
      avg_gain <- frollmean(gain, 14, align = "right", na.rm = TRUE)
      avg_loss <- frollmean(loss, 14, align = "right", na.rm = TRUE)
      
      # Calculate RS and RSI
      rs <- avg_gain / (avg_loss + 1e-10)  # Add small value to avoid division by zero
      rsi <- 100 - (100 / (1 + rs))
      
      # Handle edge cases
      rsi[is.infinite(rsi) | is.nan(rsi)] <- NA_real_
      rsi
    }, by = company_id]
    
    log_message("  RSI calculation completed")
  }

  if (!"rsi_overbought" %in% names(dt)) dt[, rsi_overbought := rsi > 70]
  if (!"rsi_oversold" %in% names(dt)) dt[, rsi_oversold := rsi < 30]

  # ADX - Simplified but functional implementation
  if (!"adx" %in% names(dt)) {
    log_message("  Calculating ADX...", "DEBUG")
    
    dt[, adx := {
      if (.N >= 14) {
        # Calculate True Range
        tr <- pmax(high - low, abs(high - shift(close)), abs(low - shift(close)), na.rm = TRUE)
        
        # Calculate +DM and -DM
        up_move <- high - shift(high)
        down_move <- shift(low) - low
        
        plus_dm <- ifelse((up_move > down_move) & (up_move > 0), up_move, 0)
        minus_dm <- ifelse((down_move > up_move) & (down_move > 0), down_move, 0)
        
        # Smooth the values
        atr <- frollmean(tr, 14, align = "right", na.rm = TRUE)
        plus_di <- 100 * frollmean(plus_dm, 14, align = "right", na.rm = TRUE) / (atr + 1e-10)
        minus_di <- 100 * frollmean(minus_dm, 14, align = "right", na.rm = TRUE) / (atr + 1e-10)
        
        # Calculate ADX
        dx <- 100 * abs(plus_di - minus_di) / (plus_di + minus_di + 1e-10)
        adx <- frollmean(dx, 14, align = "right", na.rm = TRUE)
        
        # Handle edge cases
        adx[is.infinite(adx) | is.nan(adx)] <- NA_real_
        adx
      } else { NA_real_ }
    }, by = company_id]
    
    log_message("  ADX calculation completed")
  }
  # MACD - Proper implementation
  if (!"macd_line" %in% names(dt)) {
    log_message("  Calculating MACD...", "DEBUG")
    
    # First calculate MACD line
    dt[, macd_line := {
      if (.N >= 26) {
        ema_12 <- frollapply(close, 12, function(x) {
          if (length(x) < 2) return(NA_real_)
          # Simple EMA calculation
          alpha <- 2 / (12 + 1)
          result <- numeric(length(x))
          result[1] <- mean(x, na.rm = TRUE)
          for (i in 2:length(x)) {
            result[i] <- alpha * x[i] + (1 - alpha) * result[i-1]
          }
          result[length(x)]
        }, align = "right")
        
        ema_26 <- frollapply(close, 26, function(x) {
          if (length(x) < 2) return(NA_real_)
          alpha <- 2 / (26 + 1)
          result <- numeric(length(x))
          result[1] <- mean(x, na.rm = TRUE)
          for (i in 2:length(x)) {
            result[i] <- alpha * x[i] + (1 - alpha) * result[i-1]
          }
          result[length(x)]
        }, align = "right")
        
        ema_12 - ema_26
      } else { NA_real_ }
    }, by = company_id]
    
    # Then calculate signal line
    dt[, macd_signal := {
      if (.N >= 35) {  # Need more data for signal line
        frollapply(macd_line, 9, function(x) {
          if (length(x) < 2) return(NA_real_)
          alpha <- 2 / (9 + 1)
          result <- numeric(length(x))
          result[1] <- mean(x, na.rm = TRUE)
          for (i in 2:length(x)) {
            result[i] <- alpha * x[i] + (1 - alpha) * result[i-1]
          }
          result[length(x)]
        }, align = "right")
      } else { NA_real_ }
    }, by = company_id]
    
    # Then calculate histogram and signals
    dt[, macd_hist := macd_line - macd_signal]
    
    # Calculate MACD histogram slope separately
    dt[, macd_hist_slope := {
      frollapply(macd_hist, 3, function(x) {
        if (length(x) < 3) return(NA_real_)
        # Simple slope calculation using linear regression
        if (all(is.na(x))) return(NA_real_)
        tryCatch({
          lm_fit <- lm(x ~ 1:3, na.action = na.omit)
          coef(lm_fit)[2]
        }, error = function(e) NA_real_)
      }, align = "right")
    }, by = company_id]
    
    # Add other MACD signals
    dt[, `:=`(
      macd_bullish_cross = (macd_line > macd_signal) & (shift(macd_line) <= shift(macd_signal)),
      macd_bearish_cross = (macd_line < macd_signal) & (shift(macd_line) >= shift(macd_signal)),
      macd_hist_trend = data.table::frollmean(macd_hist, 3, align = "right") > data.table::shift(data.table::frollmean(macd_hist, 3, align = "right"), 1),
      macd_above_zero = macd_line > 0
    ), by = company_id]
    
    log_message("  MACD calculation completed")
  }
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

  # Stochastic Oscillator - Proper implementation
  if (!"stoch_k" %in% names(dt)) {
    log_message("  Calculating Stochastic indicators...", "DEBUG")
    
    # First calculate %K
    dt[, stoch_k := {
      if (.N >= 14) {
        # Calculate %K
        lowest_low <- frollapply(low, 14, min, align = "right", na.rm = TRUE)
        highest_high <- frollapply(high, 14, max, align = "right", na.rm = TRUE)
        k_percent <- 100 * (close - lowest_low) / (highest_high - lowest_low + 1e-10)
        k_percent[is.infinite(k_percent) | is.nan(k_percent)] <- NA_real_
        k_percent
      } else { NA_real_ }
    }, by = company_id]
    
    # Then calculate %D
    dt[, stoch_d := {
      if (.N >= 17) {  # Need more data for %D (3-period SMA of %K)
        frollmean(stoch_k, 3, align = "right", na.rm = TRUE)
      } else { NA_real_ }
    }, by = company_id]
    
    # Then calculate other indicators
    dt[, `:=`(
      stoch_overbought = stoch_k > 80,
      stoch_oversold = stoch_k < 20,
      stoch_bullish_cross = (stoch_k > stoch_d) & (shift(stoch_k) <= shift(stoch_d)),
      stoch_bearish_cross = (stoch_k < stoch_d) & (shift(stoch_k) >= shift(stoch_d))
    ), by = company_id]
    
    log_message("  Stochastic indicators calculation completed")
  }

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

    dt[, var_calc_status := {
      valid_returns <- !is.na(return_1d) & is.finite(return_1d)
      ok21 <- data.table::frollsum(as.integer(valid_returns), 21, align = "right", na.rm = TRUE) >= 21
      ifelse(ok21, "success", "insufficient_data")
    }, by = company_id]

    dt[, var_1d := {
      roll_mean <- data.table::frollmean(return_1d, 21, align = "right", na.rm = TRUE)
      roll_mean_sq <- data.table::frollmean(return_1d^2, 21, align = "right", na.rm = TRUE)
      variance <- pmax(0, roll_mean_sq - roll_mean^2)
      roll_sd <- sqrt(variance)
      out <- roll_mean + stats::qnorm(0.05) * roll_sd
      out[is.na(var_calc_status) | var_calc_status != "success"] <- NA_real_
      out
    }, by = company_id]

    dt[, sharpe_ratio := {
      roll_mean <- data.table::frollmean(return_1d, 21, align = "right", na.rm = TRUE)
      roll_mean_sq <- data.table::frollmean(return_1d^2, 21, align = "right", na.rm = TRUE)
      variance <- pmax(0, roll_mean_sq - roll_mean^2)
      roll_sd <- sqrt(variance)
      out <- ifelse(roll_sd > 1e-9, roll_mean / roll_sd * sqrt(252), NA_real_)
      out <- pmin(pmax(out, -10), 10)
      out[is.na(var_calc_status) | var_calc_status != "success"] <- NA_real_
      out
    }, by = company_id]

    dt[, max_drawdown_252d := {
      roll_max <- data.table::frollapply(close, 252, max, align = "right", na.rm = TRUE)
      dd <- rep(NA_real_, .N)
      ok <- !is.na(close) & close > 0 & !is.na(roll_max) & roll_max > 0
      dd[ok] <- close[ok] / roll_max[ok] - 1
      out <- data.table::frollapply(dd, 252, min, align = "right", na.rm = TRUE)
      out <- pmin(pmax(out, -1), 0)
      out[is.na(var_calc_status) | var_calc_status != "success"] <- NA_real_
      out
    }, by = company_id]
  }
  log_message("  Risk metrics (VaR, Max Drawdown, Sharpe) calculated")

  if (!"kelly_fraction" %in% names(dt)) {
    log_message("Calculating position sizing (Kelly fraction)...")
    dt[, kelly_fraction := data.table::frollapply(return_1d, 252, function(x) {
      kf <- calculate_kelly_fraction(x)
      ifelse(is.na(kf), 0.1, kf)
    }, align = "right", fill = NA_real_), by = company_id]
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
    dt[, smart_money_score_legacy := smart_money_score]
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
          risk_score_calc[i] <- sum(row_values * row_weights) / sum(row_weights)
        }
      }
      pmin(pmax(risk_score_calc, 0), 100)
    }, by = .(company_id)]
    dt[, risk_category := cut(risk_score,
                              breaks = c(0, 20, 40, 60, 80, 100),
                              labels = c("Very Low", "Low", "Medium", "High", "Very High"),
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