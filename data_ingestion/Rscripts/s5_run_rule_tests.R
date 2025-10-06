#!/usr/bin/env R
# Script to test different rule sets and compare their performance

# Load required libraries
library(data.table)
library(ggplot2)
library(parallel)
library(jsonlite)

# Source the rule sets and testing script
source("data_ingestion/Rscripts/rule_sets.R")

# Create output directory if it doesn't exist
if (!dir.exists("output/rule_tests")) {
  dir.create("output/rule_tests", recursive = TRUE, showWarnings = FALSE)
}

# Function to run a single test with a given rule set
run_rule_test <- function(rule_set_name) {
  # Run the test
  cmd <- sprintf("Rscript data_ingestion/Rscripts/mmtm_rule_testing.R %s", rule_set_name)
  system(cmd, intern = FALSE)
  
  # The mmtm_rule_testing.R script already saves its output to output/{rule_set_name}/
  # We'll use that output directly
  output_file <- file.path("output", rule_set_name, "momentum_cycle_signals.csv")
  
  if (file.exists(output_file)) {
    results <- fread(output_file)
    
    # Calculate basic metrics
    metrics <- list(
      rule_set = rule_set_name,
      timestamp = Sys.time(),
      total_signals = nrow(results),
      buy_signals = sum(results$status == "BUY", na.rm = TRUE),
      sell_signals = sum(results$status == "SELL", na.rm = TRUE),
      avg_pnl = mean(results$pnl_pct, na.rm = TRUE),
      win_rate = mean(results$pnl_pct > 0, na.rm = TRUE) * 100
    )
    
    return(metrics)
  } else {
    warning(sprintf("Output file not found for rule set: %s at %s", rule_set_name, output_file))
    return(NULL)
  }
}

# Function to compare results from different rule sets
compare_results <- function() {
  # Get all metrics files from all test runs
  test_dirs <- list.dirs("output/rule_tests", recursive = FALSE, full.names = TRUE)
  metrics_files <- file.path(test_dirs, "metrics.json")
  metrics_files <- metrics_files[file.exists(metrics_files)]
  
  if (length(metrics_files) == 0) {
    stop("No metrics files found. Run some tests first.")
  }
  
  # Load and combine all metrics
  all_metrics <- rbindlist(lapply(metrics_files, function(f) {
    m <- fromJSON(f)
    as.data.table(m)
  }), fill = TRUE)
  
  # Create comparison plot
  p <- ggplot(all_metrics, aes(x = rule_set, y = avg_pnl, fill = rule_set)) +
    geom_bar(stat = "identity") +
    labs(title = "Average PnL by Rule Set",
         x = "Rule Set",
         y = "Average PnL (%)") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  # Create comparison directory
  comparison_dir <- file.path("output/rule_tests/comparisons")
  dir.create(comparison_dir, showWarnings = FALSE, recursive = TRUE)
  
  # Save the plot with timestamp
  plot_file <- file.path(comparison_dir, 
                        sprintf("rule_set_comparison_%s.png", 
                               format(Sys.time(), "%Y%m%d_%H%M%S")))
  ggsave(plot_file, p, width = 10, height = 6)
  
  # Print summary
  cat("\n=== Rule Set Comparison ===\n")
  print(all_metrics[, .(rule_set, total_signals, buy_signals, sell_signals, 
                       avg_pnl = round(avg_pnl, 2), 
                       win_rate = round(win_rate, 1))], 
        row.names = FALSE)
  
  # Save detailed comparison with timestamp
  comparison_file <- file.path(comparison_dir, 
                             sprintf("detailed_comparison_%s.csv", 
                                    format(Sys.time(), "%Y%m%d_%H%M%S")))
  fwrite(all_metrics, comparison_file)
  
  # Also save as the latest comparison for easy reference
  fwrite(all_metrics, file.path(comparison_dir, "latest_comparison.csv"))
  
  return(all_metrics)
}

# Main execution
main <- function() {
  # Get available rule sets
  rule_sets <- names(rule_sets)
  cat("Available rule sets:", paste(rule_sets, collapse = ", "), "\n")
  
  # Run tests for each rule set
  results <- lapply(rule_sets, function(rs) {
    cat("\n=== Testing rule set:", rs, "===\n")
    tryCatch({
      run_rule_test(rs)
    }, error = function(e) {
      message(sprintf("Error testing rule set %s: %s", rs, e$message))
      NULL
    })
  })
  
  # Compare results
  comparison <- compare_results()
  
  # Print best performing rule set
  best <- comparison[which.max(avg_pnl)]
  cat("\n=== Best Performing Rule Set ===\n")
  print(best)
}

# Run the main function if script is executed directly
if (sys.nframe() == 0) {
  main()
}
