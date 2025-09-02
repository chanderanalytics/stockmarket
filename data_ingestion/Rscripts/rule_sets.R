# Momentum Trading Rule Sets
# This file contains momentum trading rule configurations
# Each scenario defines different phases of a momentum trade with specific entry/exit rules

# ======================
# MOMENTUM RULE SETS
# ======================

# Scenario 1: Pure Momentum Strategy
scenario_1 <- list(
  "0" = list(name = "SETUP", rules = c("return_5d > 0.02", "volume > vol_21d_avg", "close > ma_21"), optimal_days = 5),
  "1" = list(name = "BREAKOUT", rules = c("return_5d > 0.05", "volume > 1.5 * vol_21d_avg", "close > ma_50"), optimal_days = 10),
  "2" = list(name = "EARLY_MOM", rules = c("return_21d > 0.1", "rsi > 55 & rsi < 75", "close > ma_50"), optimal_days = 21),
  "3" = list(name = "SUSTAINED", rules = c("return_63d > 0.2", "sharpe_ratio > 1.2", "close > ma_100"), optimal_days = 42),
  "4" = list(name = "EXTENDED", rules = c("rsi > 70", "return_10d > 0.1", "volume > 2 * vol_21d_avg"), optimal_days = 3),
  "5" = list(name = "DISTRIBUTION", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_21d_avg"), optimal_days = 2)
)

# Scenario 2: Momentum with Volume Confirmation
scenario_2 <- list(
  "0" = list(name = "SETUP", rules = c("volume > 1.5 * vol_21d_avg", "close > ma_21", "return_5d > 0.03"), optimal_days = 5),
  "1" = list(name = "BREAKOUT", rules = c("volume > 2 * vol_21d_avg", "close > ma_50", "return_5d > 0.05"), optimal_days = 10),
  "2" = list(name = "EARLY_MOM", rules = c("volume > 1.8 * vol_21d_avg", "return_10d > 0.08", "rsi > 50 & rsi < 70"), optimal_days = 14),
  "3" = list(name = "SUSTAINED", rules = c("volume > vol_21d_avg", "return_21d > 0.15", "sharpe_ratio > 1"), optimal_days = 21),
  "4" = list(name = "EXTENDED", rules = c("volume > 2.5 * vol_21d_avg", "rsi > 70", "return_5d > 0.08"), optimal_days = 3),
  "5" = list(name = "DISTRIBUTION", rules = c("volume > vol_21d_avg", "close < ma_21", "return_5d < -0.02"), optimal_days = 2)
)

# Scenario 3: Risk-Adjusted Momentum with Divergence
scenario_3 <- list(
  "0" = list(name = "SETUP", rules = c("sharpe_ratio > 1", "return_5d > 0.02", "volume > vol_21d_avg"), optimal_days = 7),
  "1" = list(name = "BREAKOUT", rules = c("sharpe_ratio > 1.5", "return_5d > 0.05", "volume > 1.5 * vol_21d_avg"), optimal_days = 14),
  "2" = list(name = "EARLY_MOM", rules = c("return_21d > 0.12", "sharpe_ratio > 1.2", "rsi > 50 & rsi < 70"), optimal_days = 21),
  "3" = list(name = "SUSTAINED", rules = c("return_63d > 0.25", "sharpe_ratio > 1.3", "close > ma_50"), optimal_days = 35),
  "4" = list(name = "EXTENDED", rules = c("rsi > 70", "return_5d > 0.1", "volume > 2 * vol_21d_avg"), optimal_days = 3),
  "5" = list(name = "DISTRIBUTION", rules = c("close < ma_21", "return_5d < -0.03", "volume > vol_21d_avg"), optimal_days = 2)
)

# Scenario 4: High Momentum Breakout
scenario_4 <- list(
  "0" = list(name = "SETUP", rules = c("return_10d > 0.05", "volume > vol_21d_avg", "close > ma_21"), optimal_days = 5),
  "1" = list(name = "BREAKOUT", rules = c("return_5d > 0.08", "volume > 2 * vol_21d_avg", "close > ma_50"), optimal_days = 10),
  "2" = list(name = "EARLY_MOM", rules = c("return_21d > 0.15", "rsi > 60 & rsi < 80", "close > ma_50"), optimal_days = 14),
  "3" = list(name = "SUSTAINED", rules = c("return_63d > 0.3", "sharpe_ratio > 1.5", "close > ma_100"), optimal_days = 30),
  "4" = list(name = "EXTENDED", rules = c("rsi > 75", "return_10d > 0.15", "volume > 3 * vol_21d_avg"), optimal_days = 3),
  "5" = list(name = "DISTRIBUTION", rules = c("close < ma_21", "return_5d < -0.05", "volume > vol_21d_avg"), optimal_days = 2)
)

# Define all available rule sets
rule_sets <- list(
  "momentum_1" = scenario_1,  # Pure Momentum Strategy
  "momentum_2" = scenario_2,  # Momentum with Volume Confirmation
  "momentum_3" = scenario_3,  # Risk-Adjusted Momentum with Divergence
  "momentum_4" = scenario_4   # High Momentum Breakout
)

#' Get a specific momentum trading rule set
#' 
#' @param set_name Name of the rule set to retrieve (default: "base")
#' @return The specified rule set or the base rule set if not found
#' @export
get_rule_set <- function(set_name = "base") {
  if (!set_name %in% names(rule_sets)) {
    warning(paste("Rule set", set_name, "not found. Using base rules."))
    return(scenario_1)
  }
  return(rule_sets[[set_name]])
}
