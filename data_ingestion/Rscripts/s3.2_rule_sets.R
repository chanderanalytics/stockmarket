# Momentum Trading Rule Sets
# This file contains momentum trading rule configurations using raw expressions
# Each scenario defines different phases of a momentum trade with specific entry/exit rules

# ======================
# MOMENTUM RULE SETS
# ======================

# ============================================================================
# RULE SET DEFINITIONS
# ============================================================================

# Scenario 0: Technical Indicators (using raw expressions)
scenario_0 <- list(
  "1" = list(name = "LOW_VOLATILITY_COMPRESSION", rules = c("vol_21d < quantile(vol_21d, 0.2)", "is_tight_range == 1", "is_3day_tight == 1", "(volume_ratio < 0.8) & (vol_8d_avg < vol_63d_avg)"), optimal_days = 5),
  "2" = list(name = "HIGH_VOLUME_BREAKOUT_21D", rules = c("close > 0.99 * high_21d", "volume > 1.2 * vol_21d_avg", "return_5d > 0.02"), optimal_days = 10),
  "3" = list(name = "PRIMARY_UPTREND_CONFIRMATION", rules = c("close > ma_21", "ma_21 > ma_63", "return_21d > 0.10"), optimal_days = 21),
  "4" = list(name = "ESTABLISHED_UPTREND_WEAK_DRAWDOWN", rules = c("close > ma_126", "ma_21 > ma_63 & ma_63 > ma_126", "return_63d > 0.20", "drawdown > -0.10"), optimal_days = 42),
  "5" = list(name = "POTENTIAL_MEAN_REVERSION", rules = c("overextension > 0.075", "close > ma_21 & rsi < shift(rsi, 5)", "volume > 2 * vol_21d_avg"), optimal_days = 3),
  "6" = list(name = "DOWNSIDE_MOMENTUM_CONFIRMATION", rules = c("close < ma_21", "volume < 0.8 * vol_21d_avg", "return_5d < -0.03"), optimal_days = 2)
  )

# Scenario 1: Pure Momentum Strategy (using raw expressions)
scenario_1 <- list(
  "1" = list(name = "INITIAL_MOMENTUM_SIGNAL", rules = c("return_5d > 0.02", "volume > 1.2 * vol_21d_avg", "close > ma_21"), optimal_days = 5),
  "2" = list(name = "HIGH_MOMENTUM_BREAKOUT", rules = c("return_5d > 0.05", "volume > 1.5 * vol_21d_avg", "close > ma_50"), optimal_days = 10),
  "3" = list(name = "ESTABLISHED_MOMENTUM", rules = c("return_21d > 0.1", "rsi > 55 & rsi < 75", "close > ma_50"), optimal_days = 21),
  "4" = list(name = "HIGHER_TIMEFRAME_TREND", rules = c("return_63d > 0.2", "sharpe_ratio > 1.2", "close > ma_100"), optimal_days = 42),
  "5" = list(name = "OVERBOUGHT_CONDITION", rules = c("rsi > 70", "return_10d > 0.05", "volume > 2 * vol_21d_avg"), optimal_days = 3),
  "6" = list(name = "DOWNSIDE_MOMENTUM", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_21d_avg"), optimal_days = 2)
)

# Scenario 2: Momentum with Volume Confirmation
scenario_2 <- list(
  "1" = list(name = "VOLUME_DRIVEN_INITIATION", rules = c("volume > 1.5 * vol_21d_avg", "close > ma_21", "return_5d > 0.03"), optimal_days = 5),
  "2" = list(name = "VOLUME_SURGE_BREAKOUT", rules = c("volume > 2 * vol_21d_avg", "close > ma_50", "return_5d > 0.05"), optimal_days = 10),
  "3" = list(name = "VOLUME_ACCELERATION_PHASE", rules = c("volume > 1.8 * vol_21d_avg", "return_10d > 0.08", "rsi > 50 & rsi < 70"), optimal_days = 14),
  "4" = list(name = "VOLUME_SUPPORTED_UPTREND", rules = c("volume > vol_21d_avg", "return_21d > 0.15", "sharpe_ratio > 1"), optimal_days = 21),
  "5" = list(name = "VOLATILE_EXTENSION", rules = c("volume > 2.5 * vol_21d_avg", "rsi > 70", "return_5d > 0.08"), optimal_days = 3),
  "6" = list(name = "VOLUME_DISTRIBUTION", rules = c("volume > vol_21d_avg", "close < ma_21", "return_5d < -0.02"), optimal_days = 2)
)

# Scenario 3: Risk-Adjusted Momentum with Divergence
scenario_3 <- list(
  "1" = list(name = "RISK_EFFICIENT_ENTRY", rules = c("sharpe_ratio > 1", "return_5d > 0.02", "volume > vol_21d_avg"), optimal_days = 7),
  "2" = list(name = "CONFIRMED_RISK_ADJUSTED_BREAKOUT", rules = c("sharpe_ratio > 1.5", "return_5d > 0.05", "volume > 1.5 * vol_21d_avg"), optimal_days = 14),
  "3" = list(name = "DIVERGENCE_SIGNAL", rules = c("return_21d > 0.12", "sharpe_ratio > 1.2", "rsi > 50 & rsi < 70"), optimal_days = 21),
  "4" = list(name = "RISK_OPTIMIZED_TREND", rules = c("return_63d > 0.25", "sharpe_ratio > 1.3", "close > ma_50"), optimal_days = 35),
  "5" = list(name = "RISK_EXTREME", rules = c("rsi > 70", "return_5d > 0.1", "volume > 2 * vol_21d_avg"), optimal_days = 3),
  "6" = list(name = "RISK_DISTRIBUTION", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_21d_avg"), optimal_days = 2)
)

# Scenario 4: High Momentum Breakout
scenario_4 <- list(
  "1" = list(name = "HIGH_MOMENTUM_INITIATION", rules = c("return_10d > 0.05", "volume > vol_21d_avg", "close > ma_21"), optimal_days = 5),
  "2" = list(name = "ACCELERATED_MOMENTUM_BREAKOUT", rules = c("return_5d > 0.08", "volume > 2 * vol_21d_avg", "close > ma_50"), optimal_days = 10),
  "3" = list(name = "STRONG_UPTREND_CONFIRMATION", rules = c("return_21d > 0.15", "rsi > 60 & rsi < 80", "close > ma_50"), optimal_days = 14),
  "4" = list(name = "EXTENDED_MOMENTUM_PHASE", rules = c("return_63d > 0.3", "sharpe_ratio > 1.5", "close > ma_100"), optimal_days = 30),
  "5" = list(name = "MOMENTUM_EXTREME", rules = c("rsi > 75", "return_10d > 0.15", "volume > 3 * vol_21d_avg"), optimal_days = 3),
  "6" = list(name = "MOMENTUM_EXHAUSTION", rules = c("close < ma_21", "return_5d < -0.05", "volume > vol_21d_avg"), optimal_days = 2)
)

# Scenario 5: Pullback to MA21 with Volume Thrust
scenario_5 <- list(
  "1" = list(name = "CONSOLIDATION_PHASE", rules = c("is_3day_tight == 1", "range_contraction < 0.5", "vol_ma_5 < vol_ma_20"), optimal_days = 5),
  "2" = list(name = "MA21_PULLBACK", rules = c("price_vs_ma21 > -3 & price_vs_ma21 < 0", "rsi > 45 & rsi < 60", "volume < vol_ma_20 * 1.1"), optimal_days = 5),
  "3" = list(name = "VOLUME_THRUST_BREAKOUT", rules = c("close > high_5d * 0.99", "volume > 1.5 * vol_ma_20", "return_5d > 0.03"), optimal_days = 10),
  "4" = list(name = "TREND_RESUMPTION", rules = c("close > ma_21", "ma_21_slope > 0", "buying_pressure > 0"), optimal_days = 14),
  "5" = list(name = "PULLBACK_EXTREME", rules = c("price_vs_ma21 > 8", "rsi > 70", "volume > 2 * vol_ma_20"), optimal_days = 3),
  "6" = list(name = "TREND_REVERSAL", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 2)
)

# Scenario 6: 21d High Breakout with Volume Confirmation
scenario_6 <- list(
  "1" = list(name = "COIL", rules = c("range_contraction < 0.4", "tight_range_count >= 2", "vol_ma_5 < vol_ma_20"), optimal_days = 4),
  "2" = list(name = "BREAKOUT_SETUP", rules = c("close > 0.99 * high_21d", "price_vs_ma50 > -2", "volume > vol_ma_20"), optimal_days = 3),
  "3" = list(name = "BREAKOUT", rules = c("close > high_21d", "volume > 1.8 * vol_ma_20", "return_5d > 0.04"), optimal_days = 7),
  "4" = list(name = "BASE_ABOVE_BH", rules = c("pct_from_21d_high > -2", "ma_21 > ma_63", "vol_ma_5 >= vol_ma_20"), optimal_days = 10),
  "5" = list(name = "EXTENSION", rules = c("price_vs_ma21 > 10", "rsi > 72", "volume > 2.2 * vol_ma_20"), optimal_days = 3),
  "6" = list(name = "ROLL_OVER", rules = c("close < ma_21", "return_10d < -0.04", "volume > vol_ma_20"), optimal_days = 2)
)

# Scenario 7: Inside Day/NR4 + Breakout
scenario_7 <- list(
  "1" = list(name = "NR4_COIL", rules = c("range_5d < 0.25", "is_tight_range == 1", "vol_ma_5 < vol_ma_20"), optimal_days = 3),
  "2" = list(name = "INSIDE_DAY", rules = c("high < shift(high,1)", "low > shift(low,1)", "volume <= vol_ma_20 * 1.1"), optimal_days = 2),
  "3" = list(name = "BREAKUP", rules = c("close > shift(high,1)", "volume > 1.6 * vol_ma_20", "return_5d > 0.025"), optimal_days = 7),
  "4" = list(name = "ADVANCE", rules = c("ma_21 > ma_63", "price_vs_ma21 > 0", "buying_pressure > 0"), optimal_days = 10),
  "5" = list(name = "CLIMAX", rules = c("macd_hist_slope < 0", "rsi > 73", "volume > 2 * vol_ma_20"), optimal_days = 3),
  "6" = list(name = "FADE", rules = c("close < ma_21", "stoch_overbought == TRUE", "return_5d < -0.03"), optimal_days = 2)
)

# Scenario 8: 52w High Proximity + Volume Ladder
scenario_8 <- list(
  "1" = list(name = "NEAR_52W", rules = c("near_52wk_high == TRUE", "pct_from_21d_high > -5", "vol_ma_5 >= 0.8 * vol_ma_20"), optimal_days = 4),
  "2" = list(name = "VOL_LADDER", rules = c("vol_ma_5 > vol_ma_20", "vol_ma_20 > vol_ma_50", "volume_signal_20 == TRUE"), optimal_days = 6),
  "3" = list(name = "EXPAND_UP", rules = c("close > high_21d", "return_10d > 0.06", "volume > 1.7 * vol_ma_20"), optimal_days = 7),
  "4" = list(name = "TREND", rules = c("ma_21 > ma_63", "price_vs_ma50 > 0", "obv_trend == 'up'"), optimal_days = 14),
  "5" = list(name = "EXHAUST", rules = c("volume_spike == TRUE", "rsi_overbought == TRUE", "price_vs_ma21 > 12"), optimal_days = 3),
  "6" = list(name = "COOL_OFF", rules = c("close < ma_21", "volume_accumulation == TRUE", "return_10d < -0.05"), optimal_days = 3)
)

# Scenario 9: Gap and Go (Filtered)
scenario_9 <- list(
  "1" = list(name = "QUIET_PRE_GAP", rules = c("range_contraction < 0.5", "vol_ma_5 <= vol_ma_20", "return_5d between -0.02 & 0.03"), optimal_days = 3),
  "2" = list(name = "GAP_UP", rules = c("open >= shift(high,1) * 1.02", "volume > 2 * vol_ma_20", "close > open"), optimal_days = 2),
  "3" = list(name = "GO", rules = c("close > shift(high,1)", "return_5d > 0.03", "volume_signal_20 == TRUE"), optimal_days = 5),
  "4" = list(name = "TREND_HOLD", rules = c("price_vs_ma21 > 0", "ma_21 > ma_63", "obv_trend == 'up'"), optimal_days = 10),
  "5" = list(name = "BLOW_OFF", rules = c("volume_spike == TRUE", "macd_hist_trend == FALSE", "rsi > 74"), optimal_days = 3),
  "6" = list(name = "FADE_BACK", rules = c("close < ma_21", "return_10d < -0.05", "volume > vol_ma_20"), optimal_days = 3)
)

# Scenario 10: Pullback to MA50 with Dry Volume and Reacceleration
scenario_10 <- list(
  "1" = list(name = "UPTREND", rules = c("ma_21 > ma_63", "ma_63 > ma_126", "price_vs_ma50 > 0"), optimal_days = 10),
  "2" = list(name = "PULLBACK", rules = c("price_vs_ma50 between -3 & 0", "vol_ma_5 < 0.8 * vol_ma_20", "rsi > 45"), optimal_days = 5),
  "3" = list(name = "REACCEL", rules = c("close > ma_21", "return_5d > 0.025", "volume > 1.4 * vol_ma_20"), optimal_days = 7),
  "4" = list(name = "FOLLOW_THROUGH", rules = c("price_vs_ma21 > 0", "obv_trend == 'up'", "volume_trend_strength > 0"), optimal_days = 10),
  "5" = list(name = "OVERHEAT", rules = c("price_vs_ma21 > 10", "rsi_overbought == TRUE", "volume > 2 * vol_ma_20"), optimal_days = 3),
  "6" = list(name = "ROLL", rules = c("close < ma_21", "stoch_bearish_cross == TRUE", "return_5d < -0.03"), optimal_days = 3)
)

# Scenario 11: Mean-Reversion Bounce off 21d Low with Absorption
scenario_11 <- list(
  "1" = list(name = "DECLINE_SLOWING", rules = c("return_10d between -0.08 & 0", "vol_ma_5 <= vol_ma_20", "absorption == TRUE"), optimal_days = 4),
  "2" = list(name = "BOUNCE_SETUP", rules = c("close > low_21d * 1.01", "rsi_oversold == TRUE | stoch_oversold == TRUE", "volume_accumulation == TRUE"), optimal_days = 3),
  "3" = list(name = "BOUNCE", rules = c("return_5d > 0.025", "close > ma_21", "volume > 1.3 * vol_ma_20"), optimal_days = 5),
  "4" = list(name = "RECOVERY", rules = c("ma_21_slope > 0", "price_vs_ma21 > 0", "price_vs_ma50 > -1"), optimal_days = 7),
  "5" = list(name = "STRETCH", rules = c("price_vs_ma21 > 8", "rsi > 70", "volume_spike == TRUE"), optimal_days = 2),
  "6" = list(name = "GIVEBACK", rules = c("return_5d < -0.03", "close < ma_21", "volume > vol_ma_20"), optimal_days = 2)
)

# Scenario 12: NR7/Compression then Breakout with Follow-Through Day
scenario_12 <- list(
  "1" = list(name = "NR7", rules = c("range_5d < 0.2", "tight_range_count >= 3", "vol_ma_5 <= vol_ma_20"), optimal_days = 4),
  "2" = list(name = "BO_SETUP", rules = c("close within 1 of high_21d", "volume >= vol_ma_20", "price_vs_ma21 > -2"), optimal_days = 3),
  "3" = list(name = "BO_DAY", rules = c("close > high_21d", "volume > 1.7 * vol_ma_20", "return_5d > 0.03"), optimal_days = 5),
  "4" = list(name = "FTD", rules = c("close > shift(close,1)", "volume > shift(volume,1)", "macd_bullish_cross == TRUE"), optimal_days = 7),
  "5" = list(name = "EXT", rules = c("price_vs_ma21 > 10", "rsi > 72", "volume > 2 * vol_ma_20"), optimal_days = 3),
  "6" = list(name = "DISTRIB", rules = c("LOW_DRAWDOWN == 0 | close < ma_21", "return_10d < -0.04", "volume > vol_ma_20"), optimal_days = 2)
)

# Scenario 13: High-Tight Flag
scenario_13 <- list(
  "1" = list(name = "IMPULSE", rules = c("return_21d > 0.25", "volume_surge == TRUE", "price_vs_ma50 > 0"), optimal_days = 7),
  "2" = list(name = "TIGHT_FLAG", rules = c("range_contraction < 0.35", "tight_range_count >= 3", "vol_ma_5 <= vol_ma_20"), optimal_days = 7),
  "3" = list(name = "BREAK_FLAG", rules = c("close > high_21d", "return_5d > 0.04", "volume > 1.6 * vol_ma_20"), optimal_days = 5),
  "4" = list(name = "RUN", rules = c("ma_21 > ma_63", "price_vs_ma21 > 0", "obv_trend == 'up'"), optimal_days = 10),
  "5" = list(name = "BLOW_OFF", rules = c("volume_spike == TRUE", "macd_hist_slope < 0", "rsi > 75"), optimal_days = 2),
  "6" = list(name = "FADE", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 2)
)

# Scenario 14: Cup-and-Handle (Simplified PA/Vol proxy)
scenario_14 <- list(
  "1" = list(name = "LEFT_CUP", rules = c("drawdown_52wk < -20", "recovery_factor > 0", "volume_trend_strength >= 0"), optimal_days = 10),
  "2" = list(name = "RIGHT_SIDE", rules = c("near_52wk_high == TRUE", "vol_ma_5 > vol_ma_20", "macd_above_zero == TRUE"), optimal_days = 10),
  "3" = list(name = "HANDLE_TIGHT", rules = c("tight_range_count >= 3", "range_contraction < 0.5", "vol_ma_5 <= vol_ma_20"), optimal_days = 5),
  "4" = list(name = "BREAK_HANDLE", rules = c("close > high_21d", "volume > 1.7 * vol_ma_20", "return_5d > 0.03"), optimal_days = 7),
  "5" = list(name = "EXTENSION", rules = c("price_vs_ma21 > 9", "rsi > 70", "volume > 2 * vol_ma_20"), optimal_days = 3),
  "6" = list(name = "DISTRIBUTE", rules = c("close < ma_21", "return_10d < -0.05", "volume > vol_ma_20"), optimal_days = 3)
)

# Scenario 15: Volatility-Adjusted Breakout (ATR% filter + liquidity)
scenario_15 <- list(
  "1" = list(name = "LOW_VOLATILITY_SETUP", rules = c("atr_pct < 5", "range_contraction < 0.5", "dollar_vol_20d > 1e7"), optimal_days = 7),
  "2" = list(name = "BREAKOUT_TRIGGER", rules = c("close > high_21d", "volume > 1.5 * vol_ma_20", "return_5d > 0.02"), optimal_days = 5),
  "3" = list(name = "TREND_HOLD", rules = c("close > ma_21", "ma_21 > ma_63", "atr_pct < 8"), optimal_days = 14),
  "4" = list(name = "STRONG_TREND", rules = c("return_21d > 0.08", "price_vs_ma21 > 0", "volume_signal_20 == TRUE"), optimal_days = 21),
  "5" = list(name = "VOLATILITY_EXPANSION", rules = c("atr_pct > 8", "rsi > 70", "volume_spike == TRUE"), optimal_days = 3),
  "6" = list(name = "RISK_OFF_EXIT", rules = c("close < ma_21", "return_5d < -0.03", "atr_pct > 10"), optimal_days = 3)
)

# Scenario 16: VWAP Reclaim / Institutional Support Proxy
scenario_16 <- list(
  "1" = list(name = "UPTREND_BASE", rules = c("ma_21 > ma_63", "price_vs_ma50 > 0", "dollar_vol_20d > 1e7"), optimal_days = 14),
  "2" = list(name = "PULLBACK_BELOW_VWAP", rules = c("close < vwap_20d", "price_vs_ma21 between -5 & 0", "vol_ma_5 < vol_ma_20"), optimal_days = 7),
  "3" = list(name = "VWAP_RECLAIM", rules = c("close > vwap_20d", "volume > 1.3 * vol_ma_20", "macd_bullish_cross == TRUE"), optimal_days = 5),
  "4" = list(name = "FOLLOW_THROUGH", rules = c("close > shift(close,1)", "volume > shift(volume,1)", "rsi > 50"), optimal_days = 10),
  "5" = list(name = "EXTENDED", rules = c("price_vs_ma21 > 10", "rsi_overbought == TRUE", "volume_spike == TRUE"), optimal_days = 3),
  "6" = list(name = "FAIL_RECLAIM", rules = c("close < vwap_20d", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 3)
)

# Scenario 17: Risk-Score Filtered Momentum (lower risk regime)
scenario_17 <- list(
  "1" = list(name = "LOW_RISK_UNIVERSE", rules = c("risk_score < 40", "max_drawdown_252d > -0.25", "dollar_vol_20d > 1e7"), optimal_days = 21),
  "2" = list(name = "MOMENTUM_ENTRY", rules = c("return_10d > 0.04", "close > ma_50", "volume > 1.2 * vol_21d_avg"), optimal_days = 10),
  "3" = list(name = "RISK_EFFICIENT_TREND", rules = c("sharpe_ratio > 1", "return_21d > 0.08", "close > ma_21"), optimal_days = 21),
  "4" = list(name = "ADD_ON", rules = c("volume_signal_20 == TRUE", "price_vs_ma21 > 0", "LOW_DRAWDOWN == 1"), optimal_days = 21),
  "5" = list(name = "OVERHEAT", rules = c("rsi > 72", "volume_spike == TRUE", "atr_pct > 8"), optimal_days = 3),
  "6" = list(name = "DE_RISK", rules = c("risk_score > 70 | close < ma_21", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 3)
)

# Scenario 18: ADX Trend Strength Breakout (trend-quality filter)
scenario_18 <- list(
  "1" = list(name = "TREND_QUALITY", rules = c("adx > 20", "ma_21 > ma_63", "close > ma_21"), optimal_days = 14),
  "2" = list(name = "BREAKOUT", rules = c("close > high_21d", "volume > 1.3 * vol_ma_20", "adx > 25"), optimal_days = 7),
  "3" = list(name = "TREND_CONFIRM", rules = c("adx > 20", "macd_above_zero == TRUE", "obv_trend == 'up'"), optimal_days = 21),
  "4" = list(name = "RIDE", rules = c("return_21d > 0.06", "rsi between 50 & 75", "price_vs_ma21 > 0"), optimal_days = 21),
  "5" = list(name = "TREND_EXHAUST", rules = c("rsi > 75", "adx < shift(adx,5)", "volume_spike == TRUE"), optimal_days = 3),
  "6" = list(name = "EXIT", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 3)
)

# Scenario 19: Smart Money Accumulation then Breakout
scenario_19 <- list(
  "1" = list(name = "ACCUMULATION", rules = c("smart_money_score > 65", "volume_accumulation == TRUE", "close > ma_50"), optimal_days = 10),
  "2" = list(name = "CONTROLLED_PULLBACK", rules = c("price_vs_ma21 between -4 & 0", "vol_ma_5 < vol_ma_20", "smart_money_score > 60"), optimal_days = 7),
  "3" = list(name = "BREAKOUT", rules = c("close > high_21d", "volume > 1.5 * vol_ma_20", "return_5d > 0.02"), optimal_days = 7),
  "4" = list(name = "FOLLOW_THROUGH", rules = c("obv_trend == 'up'", "smart_money_score > 60", "return_10d > 0.03"), optimal_days = 14),
  "5" = list(name = "OVERHEAT", rules = c("price_vs_ma21 > 12", "rsi > 72", "volume_spike == TRUE"), optimal_days = 3),
  "6" = list(name = "DISTRIBUTION_EXIT", rules = c("volume_delta_ma < -0.2 | close < ma_21", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 3)
)

# Scenario 20: Block Trade + Volume Delta Breakout
scenario_20 <- list(
  "1" = list(name = "BLOCK_ACTIVITY", rules = c("block_trade == TRUE", "volume_delta_ma > 0.15", "close > ma_21"), optimal_days = 5),
  "2" = list(name = "COIL", rules = c("range_contraction < 0.5", "vol_ma_5 < vol_ma_20", "is_tight_range == 1"), optimal_days = 7),
  "3" = list(name = "BREAKOUT", rules = c("close > high_21d", "volume > 2 * vol_ma_20", "volume_delta_ma > 0.1"), optimal_days = 7),
  "4" = list(name = "TREND", rules = c("macd_above_zero == TRUE", "adx > 18", "obv_trend == 'up'"), optimal_days = 14),
  "5" = list(name = "BLOW_OFF", rules = c("volume_spike == TRUE", "rsi > 75", "volume_delta_ma < 0"), optimal_days = 3),
  "6" = list(name = "EXIT", rules = c("volume_delta_ma < -0.2 | close < ma_21", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 3)
)

# Scenario 21: Institutional Support Accumulation -> Breakout
scenario_21 <- list(
  "1" = list(name = "INSTITUTIONAL_SUPPORT", rules = c("institutional_support == TRUE", "close > ma_50", "dollar_vol_20d > 1e7"), optimal_days = 10),
  "2" = list(name = "CONTROLLED_PULLBACK", rules = c("price_vs_ma21 between -5 & 0", "vol_ma_5 < vol_ma_20", "LOW_DRAWDOWN == 1"), optimal_days = 7),
  "3" = list(name = "BREAKOUT", rules = c("close > high_21d", "volume > 1.5 * vol_ma_20", "return_5d > 0.02"), optimal_days = 7),
  "4" = list(name = "FOLLOW_THROUGH", rules = c("obv_trend == 'up'", "macd_above_zero == TRUE", "return_10d > 0.03"), optimal_days = 14),
  "5" = list(name = "OVERHEAT", rules = c("price_vs_ma21 > 12", "rsi > 72", "volume_spike == TRUE"), optimal_days = 3),
  "6" = list(name = "EXIT", rules = c("close < ma_21 | institutional_support == FALSE", "return_5d < -0.03", "volume > vol_ma_20"), optimal_days = 3)
)

# PMPS-Based Strategy (momentum_22)
# Pre-Move Probability Score strategy - measures pressure buildup for big moves
scenario_22 <- list(
  "1" = list(name = "PMPS_PRESSURE_BUILDUP", rules = c(
    "pmps_score >= 60",  # Pre-move zone (75+ on 0-100 scale)
    "extreme_persistence_score >= 0.10",  # Stock capable of big moves
    "accumulation_score >= 0.25"  # Whale accumulation present
  ), optimal_days = 10),
  
  "2" = list(name = "PMPS_COMPRESSION_CONFIRM", rules = c(
    "pmps_score >= 75",  # Imminent expansion (85+ score)
    "volume_efficiency_ratio < 0.02",  # High volume, low movement
    "whale_behavior_mode %in% c('BUYING', 'PAUSING')"  # Not distributing
  ), optimal_days = 7),
  
  "3" = list(name = "PMPS_BREAKOUT_TRIGGER", rules = c(
    "pmps_score >= 85",  # High alert zone (85+ score)
    "close > high_21d",  # Breakout confirmation
    "volume > 1.5 * vol_ma_20",  # Volume expansion
    "return_1d > 0.02"  # Strong momentum
  ), optimal_days = 5),
  
  "4" = list(name = "PMPS_MOMENTUM_FOLLOW", rules = c(
    "pmps_score >= 70",  # Ready zone (70+ score)
    "ma_21_slope > 0",  # Trend confirmation
    "obv_trend == 'up'",  # Volume support
    "smart_money_score > 50"  # Smart money participation
  ), optimal_days = 8),
  
  "5" = list(name = "PMPS_EXHAUSTION_WARNING", rules = c(
    "pmps_score >= 90",  # Maximum pressure (90+ score)
    "return_5d > 0.15",  # Strong recent move
    "rsi > 75",  # Overbought
    "volume_spike == TRUE"  # Climax volume
  ), optimal_days = 3),
  
  "6" = list(name = "PMPS_EXIT_SIGNALS", rules = c(
    "pmps_score < 50",  # Pressure dropping below ready zone
    "whale_behavior_mode == 'DISTRIBUTING'",  # Whale distribution
    "return_5d < -0.05",  # Momentum failure (using 5d instead of 3d)
    "volume_efficiency_ratio > 0.05"  # Volume expansion without price movement
  ), optimal_days = 3)
)

# Register all scenarios 0..23 (removed momentum_22 - keeping PMPS strategy only)
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
  "momentum_14" = scenario_14,
  "momentum_15" = scenario_15,
  "momentum_16" = scenario_16,
  "momentum_17" = scenario_17,
  "momentum_18" = scenario_18,
  "momentum_19" = scenario_19,
  "momentum_20" = scenario_20,
  "momentum_21" = scenario_21,
  "momentum_22" = scenario_22
)

# Helper to fetch a rule set by name
get_rule_set <- function(set_name) {
  if (is.null(rule_sets[[set_name]])) stop(sprintf("Unknown rule set: %s", set_name))
  rule_sets[[set_name]]
}
