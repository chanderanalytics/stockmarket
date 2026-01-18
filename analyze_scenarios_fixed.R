# Load required libraries
if (!requireNamespace("data.table", quietly = TRUE)) install.packages("data.table")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("scales", quietly = TRUE)) install.packages("scales")

library(data.table)
library(dplyr)
library(scales)

# Directory containing the performance metrics files
output_dir <- "/Users/chanderbhushan/stockmkt/output/mmtm"

# List all performance metrics files
perf_files <- list.files(path = output_dir, 
                        pattern = "performance_metrics_momentum_\\d+_2025-12-29\\.csv",
                        full.names = TRUE)

# Function to safely read and aggregate scenario metrics
read_scenario_metrics <- function(file) {
  tryCatch({
    # Extract scenario number from filename
    scenario_num <- as.integer(gsub(".*momentum_(\\d+)_.*", "\\1", basename(file)))
    
    # Read the CSV file
    dt <- fread(file)
    
    # Calculate aggregate metrics across all companies
    metrics <- dt[, .(
      total_trades = sum(total_trades, na.rm = TRUE),
      winning_trades = sum(winning_trades, na.rm = TRUE),
      losing_trades = sum(losing_trades, na.rm = TRUE),
      open_trades = sum(open_trades, na.rm = TRUE),
      total_pnl = sum(avg_pnl * total_trades, na.rm = TRUE),
      total_win_pnl = sum(avg_win * winning_trades, na.rm = TRUE),
      total_loss_pnl = sum(avg_loss * losing_trades, na.rm = TRUE),
      avg_days_held = mean(avg_days_held, na.rm = TRUE)
    )]
    
    # Calculate derived metrics
    metrics[, `:=`(
      scenario = paste0("momentum_", scenario_num),
      win_rate = ifelse(total_trades > 0, winning_trades / total_trades, 0),
      avg_pnl = ifelse(total_trades > 0, total_pnl / total_trades, 0),
      profit_factor = ifelse(abs(total_loss_pnl) > 0, total_win_pnl / abs(total_loss_pnl), NA_real_)
    )]
    
    # For risk metrics, we'll use the median across companies
    risk_metrics <- dt[, .(
      sharpe_ratio = median(sharpe_ratio, na.rm = TRUE),
      sortino_ratio = median(sortino_ratio, na.rm = TRUE),
      max_drawdown = median(max_drawdown, na.rm = TRUE)
    )]
    
    # Combine all metrics
    cbind(metrics[, .(scenario, total_trades, win_rate, avg_pnl, profit_factor, avg_days_held)], risk_metrics)
    
  }, error = function(e) {
    message(sprintf("Error processing %s: %s", basename(file), e$message))
    return(NULL)
  })
}

# Read and combine all scenarios
all_metrics <- rbindlist(lapply(perf_files, read_scenario_metrics), fill = TRUE)

# Remove any scenarios that failed to load
all_metrics <- all_metrics[!is.na(scenario)]

# Calculate composite score (weighted average of normalized metrics)
safe_scale <- function(x) {
  if (all(is.na(x)) || sd(x, na.rm = TRUE) == 0) {
    return(rep(0, length(x)))
  }
  scale(x)[,1]
}

# Calculate normalized metrics
all_metrics[, `:=`(
  norm_win_rate = safe_scale(win_rate),
  norm_avg_pnl = safe_scale(avg_pnl),
  norm_profit_factor = safe_scale(ifelse(is.na(profit_factor), 0, profit_factor)),
  norm_sharpe = safe_scale(ifelse(is.na(sharpe_ratio), 0, sharpe_ratio)),
  norm_sortino = safe_scale(ifelse(is.na(sortino_ratio), 0, sortino_ratio)),
  norm_drawdown = -safe_scale(ifelse(is.na(max_drawdown), 0, max_drawdown))
)]

# Calculate composite score (higher is better)
all_metrics[, composite_score := 
              norm_win_rate * 0.2 +
              norm_avg_pnl * 0.3 +
              norm_profit_factor * 0.2 +
              norm_sharpe * 0.15 +
              norm_sortino * 0.15]

# Rank scenarios by composite score
all_metrics[, rank := frank(-composite_score)]

# Order by rank
setorder(all_metrics, rank)

# Print summary to console
cat("=== SCENARIO PERFORMANCE SUMMARY ===\n\n")

# Format numbers for display
format_pct <- function(x) ifelse(is.na(x), "N/A", percent(x, accuracy = 0.1))
format_num <- function(x, digits = 2) ifelse(is.na(x), "N/A", round(x, digits))

# Best performing scenarios
cat("TOP 5 SCENARIOS (by composite score):\n")
top_scenarios <- head(all_metrics[, .(
  Scenario = scenario,
  `Total Trades` = total_trades, 
  `Win Rate` = format_pct(win_rate),
  `Avg P&L` = format_pct(avg_pnl),
  `Profit Factor` = format_num(profit_factor),
  `Sharpe` = format_num(sharpe_ratio),
  `Sortino` = format_num(sortino_ratio),
  `Max DD` = format_pct(max_drawdown),
  `Avg Days` = format_num(avg_days_held, 1),
  `Score` = format_num(composite_score, 2)
)], 5)

print(top_scenarios, row.names = FALSE)

# Worst performing scenarios
cat("\nBOTTOM 5 SCENARIOS (by composite score):\n")
bottom_scenarios <- tail(all_metrics[, .(
  Scenario = scenario,
  `Total Trades` = total_trades, 
  `Win Rate` = format_pct(win_rate),
  `Avg P&L` = format_pct(avg_pnl),
  `Profit Factor` = format_num(profit_factor),
  `Sharpe` = format_num(sharpe_ratio),
  `Sortino` = format_num(sortino_ratio),
  `Max DD` = format_pct(max_drawdown),
  `Avg Days` = format_num(avg_days_held, 1),
  `Score` = format_num(composite_score, 2)
)], 5)

print(bottom_scenarios, row.names = FALSE)

# Save the full comparison to a CSV
output_file <- file.path(output_dir, "scenario_comparison_summary.csv")
fwrite(all_metrics, output_file)
cat(sprintf("\nFull comparison saved to: %s\n", output_file))
