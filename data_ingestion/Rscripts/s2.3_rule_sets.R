# Momentum Trading Rule Sets
# This file contains momentum trading rule configurations
# Each scenario defines different phases of a momentum trade with specific entry/exit rules

# ======================
# MOMENTUM RULE SETS
# ======================

# Scenario 0: Technical Indicators
scenario_0 <- list(
  "0" = list(
    name = "LOW_VOLATILITY",
    rules = c(
      "vol_21d < quantile(vol_21d, 0.2, na.rm = TRUE)",
      "is_tight_range == 1",
      "is_3day_tight == 1",
      "(volume_ratio < 0.8) & (vol_8d_avg < vol_63d_avg)"
    ),
    optimal_days = 5,
    score_expression = "((pmin(1, pmax(0, 1 - (vol_8d_avg / pmax(vol_63d_avg, 1e-6)))) * 0.4) + (pmin(1, 1 - ((high - low) / (atr * 0.1))) * 0.4) + (pmin(1, pmax(0, 1 - (volume / pmax(vol_21d_avg, 1e-6)))) * 0.2)) * 100"
  ),
  "1" = list(
    name = "BREAKOUT",
    rules = c(
      "close > 0.99 * high_21d",
      "volume > 1.2 * vol_21d_avg",
      "return_5d > 0.02"
    ),
    optimal_days = 10,
    score_expression = "((pmin(1, pmax(0, (close - (high_21d * 0.99)) / (close * 0.05))) * 0.5) + (pmin(1, volume / pmax(vol_21d_avg * 1.2, 1e-6)) * 0.3) + (pmin(1, pmax(0, (close / shift(close, 5) - 1) / 0.03)) * 0.2)) * 100"
  ),
  "2" = list(
    name = "TREND_CONFIRMATION",
    rules = c(
      "close > ma_21",
      "ma_21 > ma_63",
      "return_21d > 0.10"
    ),
    optimal_days = 21,
    score_expression = "((pmin(1, pmax(0, (close / ma_21 - 1) / 0.05)) * 0.3) + (as.numeric(ma_21 > shift(ma_21, 5)) * 0.5 + 0.5) * 0.2) + (pmin(1, pmax(0, (return_21d - 0.05) / 0.15)) * 0.3) + (pmin(1, pmax(0, (close / shift(close, 21) - 1) / 0.10)) * 0.2)) * 100"
  ),
  "3" = list(
    name = "STRONG_TREND",
    rules = c(
      "close > ma_126",
      "ma_21 > ma_63 & ma_63 > ma_126",
      "return_63d > 0.20",
      "drawdown > -0.10"
    ),
    optimal_days = 42,
    score_expression = "((pmin(1, pmax(0, (close / ma_126 - 1) / 0.10)) * 0.3) + (as.numeric(ma_21 > ma_63 & ma_63 > ma_126) * 0.5 + 0.5) * 0.2) + (pmin(1, pmax(0, (close / shift(close, 63) - 1) / 0.20)) * 0.3) + (pmin(1, pmax(0, 1 - (abs(drawdown) / 0.15))) * 0.2)) * 100"
  ),
  "4" = list(
    name = "OVEREXTENDED",
    rules = c(
      "overextension > 0.075",
      "return_5d < 0.03 & return_63d > -0.08",
      "volume > 1.5 * vol_63d_avg"
    ),
    optimal_days = 3,
    score_expression = "((pmin(1, pmax(0, (close / ma_21 - 1.15) / 0.20)) * 0.4) + (as.numeric(close > shift(close, 5) & rsi < shift(rsi, 5)) * 0.5 + 0.5) * 0.3) + (pmin(1, volume / pmax(vol_63d_avg * 1.5, 1e-6)) * 0.3)) * 100"
  ),
  "5" = list(
    name = "DISTRIBUTION",
    rules = c(
      "close < ma_21",
      "volume < shift(vol_21d_avg, 1, type = 'lag') * 0.8",
      "return_21d < 0"
    ),
    optimal_days = 2,
    score_expression = "((pmin(1, pmax(0, (ma_21 - close) / (close * 0.05))) * 0.4) + (pmin(1, pmax(0, 1 - (volume / pmax(vol_21d_avg * 0.8, 1e-6)))) * 0.3) + (pmin(1, pmax(0, (shift(close, 5) / close - 1) / 0.05)) * 0.3)) * 100"
  )
)

# Scenario 1: Pure Momentum Strategy
scenario_1 <- list(
  "0" = list(name = "SETUP", rules = c("return_5d > 0.02", "volume > vol_21d_avg", "close > ma_21"), optimal_days = 5,
             score_expression = "((return_5d > 0.02) * 0.4 + (volume > vol_21d_avg) * 0.3 + (close > ma_21) * 0.3) * 100"),
  "1" = list(name = "BREAKOUT", rules = c("return_5d > 0.05", "volume > 1.5 * vol_21d_avg", "close > ma_50"), optimal_days = 10,
             score_expression = "((return_5d > 0.05) * 0.5 + (volume > 1.5 * vol_21d_avg) * 0.3 + (close > ma_50) * 0.2) * 100"),
  "2" = list(name = "EARLY_MOM", rules = c("return_21d > 0.1", "rsi > 55 & rsi < 75", "close > ma_50"), optimal_days = 21,
             score_expression = "((return_21d > 0.1) * 0.4 + (rsi > 55 & rsi < 75) * 0.3 + (close > ma_50) * 0.3) * 100"),
  "3" = list(name = "SUSTAINED", rules = c("return_63d > 0.2", "sharpe_ratio > 1.2", "close > ma_100"), optimal_days = 42,
             score_expression = "((return_63d > 0.2) * 0.4 + (sharpe_ratio > 1.2) * 0.3 + (close > ma_100) * 0.3) * 100"),
  "4" = list(name = "EXTENDED", rules = c("rsi > 70", "return_10d > 0.1", "volume > 2 * vol_21d_avg"), optimal_days = 3,
             score_expression = "((rsi > 70) * 0.4 + (return_10d > 0.1) * 0.3 + (volume > 2 * vol_21d_avg) * 0.3) * 100"),
  "5" = list(name = "DISTRIBUTION", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_21d_avg"), optimal_days = 2,
             score_expression = "((close < ma_21) * 0.4 + (return_5d < -0.03) * 0.3 + (volume > vol_21d_avg) * 0.3) * 100")
)

# Scenario 2: Momentum with Volume Confirmation
scenario_2 <- list(
  "0" = list(name = "SETUP", rules = c("volume > 1.5 * vol_21d_avg", "close > ma_21", "return_5d > 0.03"), optimal_days = 5,
             score_expression = "((volume > 1.5 * vol_21d_avg) * 0.4 + (close > ma_21) * 0.3 + (return_5d > 0.03) * 0.3) * 100"),
  "1" = list(name = "BREAKOUT", rules = c("volume > 2 * vol_21d_avg", "close > ma_50", "return_5d > 0.05"), optimal_days = 10,
             score_expression = "((volume > 2 * vol_21d_avg) * 0.5 + (close > ma_50) * 0.3 + (return_5d > 0.05) * 0.2) * 100"),
  "2" = list(name = "EARLY_MOM", rules = c("volume > 1.8 * vol_21d_avg", "return_10d > 0.08", "rsi > 50 & rsi < 70"), optimal_days = 14,
             score_expression = "((volume > 1.8 * vol_21d_avg) * 0.4 + (return_10d > 0.08) * 0.3 + (rsi > 50 & rsi < 70) * 0.3) * 100"),
  "3" = list(name = "SUSTAINED", rules = c("volume > vol_21d_avg", "return_21d > 0.15", "sharpe_ratio > 1"), optimal_days = 21,
             score_expression = "((volume > vol_21d_avg) * 0.4 + (return_21d > 0.15) * 0.3 + (sharpe_ratio > 1) * 0.3) * 100"),
  "4" = list(name = "EXTENDED", rules = c("volume > 2.5 * vol_21d_avg", "rsi > 70", "return_5d > 0.08"), optimal_days = 3,
             score_expression = "((volume > 2.5 * vol_21d_avg) * 0.4 + (rsi > 70) * 0.3 + (return_5d > 0.08) * 0.3) * 100"),
  "5" = list(name = "DISTRIBUTION", rules = c("volume > vol_21d_avg", "close < ma_21", "return_5d < -0.02"), optimal_days = 2,
             score_expression = "((volume > vol_21d_avg) * 0.4 + (close < ma_21) * 0.3 + (return_5d < -0.02) * 0.3) * 100")
)

# Scenario 3: Risk-Adjusted Momentum with Divergence
scenario_3 <- list(
  "0" = list(name = "SETUP", rules = c("sharpe_ratio > 1", "return_5d > 0.02", "volume > vol_21d_avg"), optimal_days = 7,
             score_expression = "((sharpe_ratio > 1) * 0.4 + (return_5d > 0.02) * 0.3 + (volume > vol_21d_avg) * 0.3) * 100"),
  "1" = list(name = "BREAKOUT", rules = c("sharpe_ratio > 1.5", "return_5d > 0.05", "volume > 1.5 * vol_21d_avg"), optimal_days = 14,
             score_expression = "((sharpe_ratio > 1.5) * 0.5 + (return_5d > 0.05) * 0.3 + (volume > 1.5 * vol_21d_avg) * 0.2) * 100"),
  "2" = list(name = "EARLY_MOM", rules = c("return_21d > 0.12", "sharpe_ratio > 1.2", "rsi > 50 & rsi < 70"), optimal_days = 21,
             score_expression = "((return_21d > 0.12) * 0.4 + (sharpe_ratio > 1.2) * 0.3 + (rsi > 50 & rsi < 70) * 0.3) * 100"),
  "3" = list(name = "SUSTAINED", rules = c("return_63d > 0.25", "sharpe_ratio > 1.3", "close > ma_50"), optimal_days = 35,
             score_expression = "((return_63d > 0.25) * 0.4 + (sharpe_ratio > 1.3) * 0.3 + (close > ma_50) * 0.3) * 100"),
  "4" = list(name = "EXTENDED", rules = c("rsi > 70", "return_5d > 0.1", "volume > 2 * vol_21d_avg"), optimal_days = 3,
             score_expression = "((rsi > 70) * 0.4 + (return_5d > 0.1) * 0.3 + (volume > 2 * vol_21d_avg) * 0.3) * 100"),
  "5" = list(name = "DISTRIBUTION", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_21d_avg"), optimal_days = 2,
             score_expression = "((close < ma_21) * 0.4 + (return_5d < -0.03) * 0.3 + (volume > vol_21d_avg) * 0.3) * 100")
)

# Scenario 4: High Momentum Breakout
scenario_4 <- list(
  "0" = list(name = "SETUP", rules = c("return_10d > 0.05", "volume > vol_21d_avg", "close > ma_21"), optimal_days = 5,
             score_expression = "((return_10d > 0.05) * 0.4 + (volume > vol_21d_avg) * 0.3 + (close > ma_21) * 0.3) * 100"),
  "1" = list(name = "BREAKOUT", rules = c("return_5d > 0.08", "volume > 2 * vol_21d_avg", "close > ma_50"), optimal_days = 10,
             score_expression = "((return_5d > 0.08) * 0.5 + (volume > 2 * vol_21d_avg) * 0.3 + (close > ma_50) * 0.2) * 100"),
  "2" = list(name = "EARLY_MOM", rules = c("return_21d > 0.15", "rsi > 60 & rsi < 80", "close > ma_50"), optimal_days = 14,
             score_expression = "((return_21d > 0.15) * 0.4 + (rsi > 60 & rsi < 80) * 0.3 + (close > ma_50) * 0.3) * 100"),
  "3" = list(name = "SUSTAINED", rules = c("return_63d > 0.3", "sharpe_ratio > 1.5", "close > ma_100"), optimal_days = 30,
             score_expression = "((return_63d > 0.3) * 0.4 + (sharpe_ratio > 1.5) * 0.3 + (close > ma_100) * 0.3) * 100"),
  "4" = list(name = "EXTENDED", rules = c("rsi > 75", "return_10d > 0.15", "volume > 3 * vol_21d_avg"), optimal_days = 3,
             score_expression = "((rsi > 75) * 0.4 + (return_10d > 0.15) * 0.3 + (volume > 3 * vol_21d_avg) * 0.3) * 100"),
  "5" = list(name = "DISTRIBUTION", rules = c("close < ma_21", "return_5d < -0.05", "volume > vol_21d_avg"), optimal_days = 2,
             score_expression = "((close < ma_21) * 0.4 + (return_5d < -0.05) * 0.3 + (volume > vol_21d_avg) * 0.3) * 100")
)

# Scenario 5: Pullback to MA21 with Volume Thrust
scenario_5 <- list(
  "0" = list(name = "BASE_TIGHT", rules = c("is_3day_tight == 1", "range_contraction < 0.5", "vol_ma_5 < vol_ma_20"), optimal_days = 5,
             score_expression = "((is_3day_tight == 1) * 0.4 + (range_contraction < 0.5) * 0.3 + (vol_ma_5 < vol_ma_20) * 0.3) * 100"),
  "1" = list(name = "PB_TO_MA21", rules = c("price_vs_ma21 > -3 & price_vs_ma21 < 0", "rsi > 45 & rsi < 60", "volume < vol_ma_20 * 1.1"), optimal_days = 5,
             score_expression = "((price_vs_ma21 > -3 & price_vs_ma21 < 0) * 0.4 + (rsi > 45 & rsi < 60) * 0.3 + (volume < vol_ma_20 * 1.1) * 0.3) * 100"),
  "2" = list(name = "THRUST_UP", rules = c("close > high_5d * 0.99", "volume > 1.5 * vol_ma_20", "return_5d > 0.03"), optimal_days = 10,
             score_expression = "((close > high_5d * 0.99) * 0.5 + (volume > 1.5 * vol_ma_20) * 0.3 + (return_5d > 0.03) * 0.2) * 100"),
  "3" = list(name = "FOLLOW_THROUGH", rules = c("close > ma_21", "ma_21_slope > 0", "buying_pressure > 0"), optimal_days = 14,
             score_expression = "((close > ma_21) * 0.4 + (ma_21_slope > 0) * 0.3 + (buying_pressure > 0) * 0.3) * 100"),
  "4" = list(name = "OVEREXTENDED", rules = c("price_vs_ma21 > 8", "rsi > 70", "volume > 2 * vol_ma_20"), optimal_days = 3,
             score_expression = "((price_vs_ma21 > 8) * 0.4 + (rsi > 70) * 0.3 + (volume > 2 * vol_ma_20) * 0.3) * 100"),
  "5" = list(name = "DISTRIBUTION", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 2,
             score_expression = "((close < ma_21) * 0.4 + (return_5d < -0.03) * 0.3 + (volume > vol_ma_20) * 0.3) * 100")
)

# Scenario 6: 21d High Breakout with Volume Confirmation
scenario_6 <- list(
  "0" = list(name = "COIL", rules = c("range_contraction < 0.4", "tight_range_count >= 2", "vol_ma_5 < vol_ma_20"), optimal_days = 4,
             score_expression = "((range_contraction < 0.4) * 0.4 + (tight_range_count >= 2) * 0.3 + (vol_ma_5 < vol_ma_20) * 0.3) * 100"),
  "1" = list(name = "BREAKOUT_SETUP", rules = c("close > 0.99 * high_21d", "price_vs_ma50 > -2", "volume > vol_ma_20"), optimal_days = 3,
             score_expression = "((close > 0.99 * high_21d) * 0.4 + (price_vs_ma50 > -2) * 0.3 + (volume > vol_ma_20) * 0.3) * 100"),
  "2" = list(name = "BREAKOUT", rules = c("close > high_21d", "volume > 1.8 * vol_ma_20", "return_5d > 0.04"), optimal_days = 7,
             score_expression = "((close > high_21d) * 0.5 + (volume > 1.8 * vol_ma_20) * 0.3 + (return_5d > 0.04) * 0.2) * 100"),
  "3" = list(name = "BASE_ABOVE_BH", rules = c("pct_from_21d_high > -2", "ma_21 > ma_63", "vol_ma_5 >= vol_ma_20"), optimal_days = 10,
             score_expression = "((pct_from_21d_high > -2) * 0.4 + (ma_21 > ma_63) * 0.3 + (vol_ma_5 >= vol_ma_20) * 0.3) * 100"),
  "4" = list(name = "EXTENSION", rules = c("price_vs_ma21 > 10", "rsi > 72", "volume > 2.2 * vol_ma_20"), optimal_days = 3,
             score_expression = "((price_vs_ma21 > 10) * 0.4 + (rsi > 72) * 0.3 + (volume > 2.2 * vol_ma_20) * 0.3) * 100"),
  "5" = list(name = "ROLL_OVER", rules = c("close < ma_21", "return_10d < -0.04", "volume > vol_ma_20"), optimal_days = 2,
             score_expression = "((close < ma_21) * 0.4 + (return_10d < -0.04) * 0.3 + (volume > vol_ma_20) * 0.3) * 100")
)

# Scenario 7: Inside Day/NR4 + Breakout
scenario_7 <- list(
  "0" = list(name = "NR4_COIL", rules = c("range_5d < quantile(range_5d, 0.25, na.rm = TRUE)", "is_tight_range == 1", "vol_ma_5 < vol_ma_20"), optimal_days = 3,
             score_expression = "((range_5d < quantile(range_5d, 0.25, na.rm = TRUE)) * 0.4 + (is_tight_range == 1) * 0.3 + (vol_ma_5 < vol_ma_20) * 0.3) * 100"),
  "1" = list(name = "INSIDE_DAY", rules = c("high < shift(high,1)", "low > shift(low,1)", "volume <= vol_ma_20 * 1.1"), optimal_days = 2,
             score_expression = "((high < shift(high,1)) * 0.4 + (low > shift(low,1)) * 0.3 + (volume <= vol_ma_20 * 1.1) * 0.3) * 100"),
  "2" = list(name = "BREAKUP", rules = c("close > shift(high,1)", "volume > 1.6 * vol_ma_20", "return_5d > 0.025"), optimal_days = 7,
             score_expression = "((close > shift(high,1)) * 0.5 + (volume > 1.6 * vol_ma_20) * 0.3 + (return_5d > 0.025) * 0.2) * 100"),
  "3" = list(name = "ADVANCE", rules = c("ma_21 > ma_63", "price_vs_ma21 > 0", "buying_pressure > 0"), optimal_days = 10,
             score_expression = "((ma_21 > ma_63) * 0.4 + (price_vs_ma21 > 0) * 0.3 + (buying_pressure > 0) * 0.3) * 100"),
  "4" = list(name = "CLIMAX", rules = c("macd_hist_slope < 0", "rsi > 73", "volume > 2 * vol_ma_20"), optimal_days = 3,
             score_expression = "((macd_hist_slope < 0) * 0.4 + (rsi > 73) * 0.3 + (volume > 2 * vol_ma_20) * 0.3) * 100"),
  "5" = list(name = "FADE", rules = c("close < ma_21", "stoch_overbought == TRUE", "return_5d < -0.03"), optimal_days = 2,
             score_expression = "((close < ma_21) * 0.4 + (stoch_overbought == TRUE) * 0.3 + (return_5d < -0.03) * 0.3) * 100")
)

# Scenario 8: 52w High Proximity + Volume Ladder
scenario_8 <- list(
  "0" = list(name = "NEAR_52W", rules = c("near_52wk_high == TRUE", "pct_from_21d_high > -5", "vol_ma_5 >= 0.8 * vol_ma_20"), optimal_days = 4,
             score_expression = "((near_52wk_high == TRUE) * 0.4 + (pct_from_21d_high > -5) * 0.3 + (vol_ma_5 >= 0.8 * vol_ma_20) * 0.3) * 100"),
  "1" = list(name = "VOL_LADDER", rules = c("vol_ma_5 > vol_ma_20", "vol_ma_20 > vol_ma_50", "volume_signal_20 == TRUE"), optimal_days = 6,
             score_expression = "((vol_ma_5 > vol_ma_20) * 0.4 + (vol_ma_20 > vol_ma_50) * 0.3 + (volume_signal_20 == TRUE) * 0.3) * 100"),
  "2" = list(name = "EXPAND_UP", rules = c("close > high_21d", "return_10d > 0.06", "volume > 1.7 * vol_ma_20"), optimal_days = 7,
             score_expression = "((close > high_21d) * 0.5 + (return_10d > 0.06) * 0.3 + (volume > 1.7 * vol_ma_20) * 0.2) * 100"),
  "3" = list(name = "TREND", rules = c("ma_21 > ma_63", "price_vs_ma50 > 0", "obv_trend == 'up'"), optimal_days = 14,
             score_expression = "((ma_21 > ma_63) * 0.4 + (price_vs_ma50 > 0) * 0.3 + (obv_trend == 'up') * 0.3) * 100"),
  "4" = list(name = "EXHAUST", rules = c("volume_spike == TRUE", "rsi_overbought == TRUE", "price_vs_ma21 > 12"), optimal_days = 3,
             score_expression = "((volume_spike == TRUE) * 0.4 + (rsi_overbought == TRUE) * 0.3 + (price_vs_ma21 > 12) * 0.3) * 100"),
  "5" = list(name = "COOL_OFF", rules = c("close < ma_21", "volume_accumulation == TRUE", "return_10d < -0.05"), optimal_days = 3,
             score_expression = "((close < ma_21) * 0.4 + (volume_accumulation == TRUE) * 0.3 + (return_10d < -0.05) * 0.3) * 100")
)

# Scenario 9: Gap and Go (Filtered)
scenario_9 <- list(
  "0" = list(name = "QUIET_PRE_GAP", rules = c("range_contraction < 0.5", "vol_ma_5 <= vol_ma_20", "return_5d between -0.02 & 0.03"), optimal_days = 3,
             score_expression = "((range_contraction < 0.5) * 0.4 + (vol_ma_5 <= vol_ma_20) * 0.3 + (return_5d between -0.02 & 0.03) * 0.3) * 100"),
  "1" = list(name = "GAP_UP", rules = c("open >= shift(high,1) * 1.02", "volume > 2 * vol_ma_20", "close > open"), optimal_days = 2,
             score_expression = "((open >= shift(high,1) * 1.02) * 0.4 + (volume > 2 * vol_ma_20) * 0.3 + (close > open) * 0.3) * 100"),
  "2" = list(name = "GO", rules = c("close > shift(high,1)", "return_5d > 0.03", "volume_signal_20 == TRUE"), optimal_days = 5,
             score_expression = "((close > shift(high,1)) * 0.5 + (return_5d > 0.03) * 0.3 + (volume_signal_20 == TRUE) * 0.2) * 100"),
  "3" = list(name = "TREND_HOLD", rules = c("price_vs_ma21 > 0", "ma_21 > ma_63", "obv_trend == 'up'"), optimal_days = 10,
             score_expression = "((price_vs_ma21 > 0) * 0.4 + (ma_21 > ma_63) * 0.3 + (obv_trend == 'up') * 0.3) * 100"),
  "4" = list(name = "BLOW_OFF", rules = c("volume_spike == TRUE", "macd_hist_trend == FALSE", "rsi > 74"), optimal_days = 3,
             score_expression = "((volume_spike == TRUE) * 0.4 + (macd_hist_trend == FALSE) * 0.3 + (rsi > 74) * 0.3) * 100"),
  "5" = list(name = "FADE_BACK", rules = c("close < ma_21", "return_10d < -0.05", "volume > vol_ma_20"), optimal_days = 3,
             score_expression = "((close < ma_21) * 0.4 + (return_10d < -0.05) * 0.3 + (volume > vol_ma_20) * 0.3) * 100")
)

# Scenario 10: Pullback to MA50 with Dry Volume and Reacceleration
scenario_10 <- list(
  "0" = list(name = "UPTREND", rules = c("ma_21 > ma_63", "ma_63 > ma_126", "price_vs_ma50 > 0"), optimal_days = 10,
             score_expression = "((ma_21 > ma_63) * 0.4 + (ma_63 > ma_126) * 0.3 + (price_vs_ma50 > 0) * 0.3) * 100"),
  "1" = list(name = "PULLBACK", rules = c("price_vs_ma50 between -3 & 0", "vol_ma_5 < 0.8 * vol_ma_20", "rsi > 45"), optimal_days = 5,
             score_expression = "((price_vs_ma50 between -3 & 0) * 0.4 + (vol_ma_5 < 0.8 * vol_ma_20) * 0.3 + (rsi > 45) * 0.3) * 100"),
  "2" = list(name = "REACCEL", rules = c("close > ma_21", "return_5d > 0.025", "volume > 1.4 * vol_ma_20"), optimal_days = 7,
             score_expression = "((close > ma_21) * 0.5 + (return_5d > 0.025) * 0.3 + (volume > 1.4 * vol_ma_20) * 0.2) * 100"),
  "3" = list(name = "FOLLOW_THROUGH", rules = c("price_vs_ma21 > 0", "obv_trend == 'up'", "volume_trend_strength > 0"), optimal_days = 10,
             score_expression = "((price_vs_ma21 > 0) * 0.4 + (obv_trend == 'up') * 0.3 + (volume_trend_strength > 0) * 0.3) * 100"),
  "4" = list(name = "OVERHEAT", rules = c("price_vs_ma21 > 10", "rsi_overbought == TRUE", "volume > 2 * vol_ma_20"), optimal_days = 3,
             score_expression = "((price_vs_ma21 > 10) * 0.4 + (rsi_overbought == TRUE) * 0.3 + (volume > 2 * vol_ma_20) * 0.3) * 100"),
  "5" = list(name = "ROLL", rules = c("close < ma_21", "stoch_bearish_cross == TRUE", "return_5d < -0.03"), optimal_days = 3,
             score_expression = "((close < ma_21) * 0.4 + (stoch_bearish_cross == TRUE) * 0.3 + (return_5d < -0.03) * 0.3) * 100")
)

# Scenario 11: Mean-Reversion Bounce off 21d Low with Absorption
scenario_11 <- list(
  "0" = list(name = "DECLINE_SLOWING", rules = c("return_10d between -0.08 & 0", "vol_ma_5 <= vol_ma_20", "absorption == TRUE"), optimal_days = 4,
             score_expression = "((return_10d between -0.08 & 0) * 0.4 + (vol_ma_5 <= vol_ma_20) * 0.3 + (absorption == TRUE) * 0.3) * 100"),
  "1" = list(name = "BOUNCE_SETUP", rules = c("close > low_21d * 1.01", "rsi_oversold == TRUE | stoch_oversold == TRUE", "volume_accumulation == TRUE"), optimal_days = 3,
             score_expression = "((close > low_21d * 1.01) * 0.4 + (rsi_oversold == TRUE | stoch_oversold == TRUE) * 0.3 + (volume_accumulation == TRUE) * 0.3) * 100"),
  "2" = list(name = "BOUNCE", rules = c("return_5d > 0.025", "close > ma_21", "volume > 1.3 * vol_ma_20"), optimal_days = 5,
             score_expression = "((return_5d > 0.025) * 0.5 + (close > ma_21) * 0.3 + (volume > 1.3 * vol_ma_20) * 0.2) * 100"),
  "3" = list(name = "RECOVERY", rules = c("ma_21_slope > 0", "price_vs_ma21 > 0", "price_vs_ma50 > -1"), optimal_days = 7,
             score_expression = "((ma_21_slope > 0) * 0.4 + (price_vs_ma21 > 0) * 0.3 + (price_vs_ma50 > -1) * 0.3) * 100"),
  "4" = list(name = "STRETCH", rules = c("price_vs_ma21 > 8", "rsi > 70", "volume_spike == TRUE"), optimal_days = 2,
             score_expression = "((price_vs_ma21 > 8) * 0.4 + (rsi > 70) * 0.3 + (volume_spike == TRUE) * 0.3) * 100"),
  "5" = list(name = "GIVEBACK", rules = c("return_5d < -0.03", "close < ma_21", "volume > vol_ma_20"), optimal_days = 2,
             score_expression = "((return_5d < -0.03) * 0.4 + (close < ma_21) * 0.3 + (volume > vol_ma_20) * 0.3) * 100")
)

# Scenario 12: NR7/Compression then Breakout with Follow-Through Day
scenario_12 <- list(
  "0" = list(name = "NR7", rules = c("range_5d < quantile(range_5d, 0.2, na.rm = TRUE)", "tight_range_count >= 3", "vol_ma_5 <= vol_ma_20"), optimal_days = 4,
             score_expression = "((range_5d < quantile(range_5d, 0.2, na.rm = TRUE)) * 0.4 + (tight_range_count >= 3) * 0.3 + (vol_ma_5 <= vol_ma_20) * 0.3) * 100"),
  "1" = list(name = "BO_SETUP", rules = c("close within 1 of high_21d", "volume >= vol_ma_20", "price_vs_ma21 > -2"), optimal_days = 3,
             score_expression = "((close within 1 of high_21d) * 0.4 + (volume >= vol_ma_20) * 0.3 + (price_vs_ma21 > -2) * 0.3) * 100"),
  "2" = list(name = "BO_DAY", rules = c("close > high_21d", "volume > 1.7 * vol_ma_20", "return_5d > 0.03"), optimal_days = 5,
             score_expression = "((close > high_21d) * 0.5 + (volume > 1.7 * vol_ma_20) * 0.3 + (return_5d > 0.03) * 0.2) * 100"),
  "3" = list(name = "FTD", rules = c("close > shift(close,1)", "volume > shift(volume,1)", "macd_bullish_cross == TRUE"), optimal_days = 7,
             score_expression = "((close > shift(close,1)) * 0.4 + (volume > shift(volume,1)) * 0.3 + (macd_bullish_cross == TRUE) * 0.3) * 100"),
  "4" = list(name = "EXT", rules = c("price_vs_ma21 > 10", "rsi > 72", "volume > 2 * vol_ma_20"), optimal_days = 3,
             score_expression = "((price_vs_ma21 > 10) * 0.4 + (rsi > 72) * 0.3 + (volume > 2 * vol_ma_20) * 0.3) * 100"),
  "5" = list(name = "DISTRIB", rules = c("LOW_DRAWDOWN == 0 | close < ma_21", "return_10d < -0.04", "volume > vol_ma_20"), optimal_days = 2,
             score_expression = "((LOW_DRAWDOWN == 0 | close < ma_21) * 0.4 + (return_10d < -0.04) * 0.3 + (volume > vol_ma_20) * 0.3) * 100")
)

# Scenario 13: High-Tight Flag
scenario_13 <- list(
  "0" = list(name = "IMPULSE", rules = c("return_21d > 0.25", "volume_surge == TRUE", "price_vs_ma50 > 0"), optimal_days = 7,
             score_expression = "((return_21d > 0.25) * 0.4 + (volume_surge == TRUE) * 0.3 + (price_vs_ma50 > 0) * 0.3) * 100"),
  "1" = list(name = "TIGHT_FLAG", rules = c("range_contraction < 0.35", "tight_range_count >= 3", "vol_ma_5 <= vol_ma_20"), optimal_days = 7,
             score_expression = "((range_contraction < 0.35) * 0.4 + (tight_range_count >= 3) * 0.3 + (vol_ma_5 <= vol_ma_20) * 0.3) * 100"),
  "2" = list(name = "BREAK_FLAG", rules = c("close > high_21d", "return_5d > 0.04", "volume > 1.6 * vol_ma_20"), optimal_days = 5,
             score_expression = "((close > high_21d) * 0.5 + (return_5d > 0.04) * 0.3 + (volume > 1.6 * vol_ma_20) * 0.2) * 100"),
  "3" = list(name = "RUN", rules = c("ma_21 > ma_63", "price_vs_ma21 > 0", "obv_trend == 'up'"), optimal_days = 10,
             score_expression = "((ma_21 > ma_63) * 0.4 + (price_vs_ma21 > 0) * 0.3 + (obv_trend == 'up') * 0.3) * 100"),
  "4" = list(name = "BLOW_OFF", rules = c("volume_spike == TRUE", "macd_hist_slope < 0", "rsi > 75"), optimal_days = 2,
             score_expression = "((volume_spike == TRUE) * 0.4 + (macd_hist_slope < 0) * 0.3 + (rsi > 75) * 0.3) * 100"),
  "5" = list(name = "FADE", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 2,
             score_expression = "((close < ma_21) * 0.4 + (return_5d < -0.03) * 0.3 + (volume > vol_ma_20) * 0.3) * 100")
)

# Scenario 14: Cup-and-Handle (Simplified PA/Vol proxy)
scenario_14 <- list(
  "0" = list(name = "LEFT_CUP", rules = c("drawdown_52wk < -20", "recovery_factor > 0", "volume_trend_strength >= 0"), optimal_days = 10,
             score_expression = "((drawdown_52wk < -20) * 0.4 + (recovery_factor > 0) * 0.3 + (volume_trend_strength >= 0) * 0.3) * 100"),
  "1" = list(name = "RIGHT_SIDE", rules = c("near_52wk_high == TRUE", "vol_ma_5 > vol_ma_20", "macd_above_zero == TRUE"), optimal_days = 10,
             score_expression = "((near_52wk_high == TRUE) * 0.4 + (vol_ma_5 > vol_ma_20) * 0.3 + (macd_above_zero == TRUE) * 0.3) * 100"),
  "2" = list(name = "HANDLE_TIGHT", rules = c("tight_range_count >= 3", "range_contraction < 0.5", "vol_ma_5 <= vol_ma_20"), optimal_days = 5,
             score_expression = "((tight_range_count >= 3) * 0.4 + (range_contraction < 0.5) * 0.3 + (vol_ma_5 <= vol_ma_20) * 0.3) * 100"),
  "3" = list(name = "BREAK_HANDLE", rules = c("close > high_21d", "volume > 1.7 * vol_ma_20", "return_5d > 0.03"), optimal_days = 7,
             score_expression = "((close > high_21d) * 0.5 + (volume > 1.7 * vol_ma_20) * 0.3 + (return_5d > 0.03) * 0.2) * 100"),
  "4" = list(name = "EXTENSION", rules = c("price_vs_ma21 > 9", "rsi > 70", "volume > 2 * vol_ma_20"), optimal_days = 3,
             score_expression = "((price_vs_ma21 > 9) * 0.4 + (rsi > 70) * 0.3 + (volume > 2 * vol_ma_20) * 0.3) * 100"),
  "5" = list(name = "DISTRIBUTE", rules = c("close < ma_21", "return_10d < -0.05", "volume > vol_ma_20"), optimal_days = 3,
             score_expression = "((close < ma_21) * 0.4 + (return_10d < -0.05) * 0.3 + (volume > vol_ma_20) * 0.3) * 100")
)

# Register all scenarios 0..14
rule_sets <- list(
  "momentum_0" = scenario_0,
  "momentum_1" = scenario_1,
  "momentum_2" = scenario_2,
  "momentum_3" = scenario_3,
  "momentum_4" = scenario_4,
  "momentum_5" = scenario_5,
  "momentum_6" = scenario_6,
  "momentum_7" = scenario_7,
  "momentum_8" = scenario_8,
  "momentum_9" = scenario_9,
  "momentum_10" = scenario_10,
  "momentum_11" = scenario_11,
  "momentum_12" = scenario_12,
  "momentum_13" = scenario_13,
  "momentum_14" = scenario_14
)

# Override: keep only core, stable scenarios registered
rule_sets <- list(
  "momentum_0" = scenario_0,
  "momentum_1" = scenario_1,
  "momentum_2" = scenario_2,
  "momentum_3" = scenario_3,
  "momentum_4" = scenario_4
)

# Helper to fetch a rule set by name
get_rule_set <- function(set_name) {
  if (is.null(rule_sets[[set_name]])) stop(sprintf("Unknown rule set: %s", set_name))
  rule_sets[[set_name]]
}
