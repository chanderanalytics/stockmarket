#!/usr/bin/env Rscript
# momentum_cycle_signals_v2.R
# Cleaned, runnable version of your momentum cycle pipeline.
# Dependencies: data.table, DBI, RPostgres (optional for DB write), TTR
# Usage: set PG* env vars for DB write, or let script run and only produce CSV.

source("data_ingestion/Rscripts/0_setup_renv.R")

# 2.2 Argument Parsing for main orchestrator
# ----------------------------------------------------------------------------
#' Parse Command Line Arguments for Orchestration
#' 
#' Parses command line arguments to get reference date, optional scenario and limit_companies.
#' @return List containing script parameters
parse_arguments <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  if (any(args %in% c("--help", "-h"))) {
    cat(paste0(
      "Usage: Rscript data_ingestion/Rscripts/s1_mmtm.R <YYYY-MM-DD> [--scenario=momentum_0] [--all_scenarios] [--limit_companies=N] [--execute_next_day]\n\n",
      "Default behavior:\n",
      "  scenario: momentum_0 (if not specified)\n",
      "  limit_companies: all companies\n",
      "  all_scenarios: false (single scenario)\n",
      "  execute_next_day: true (trades executed next day)\n"
    ))
    quit(save = "no", status = 0)
  }

  is_truthy <- function(x) {
    tolower(trimws(x)) %in% c("1", "true", "t", "yes", "y")
  }
  
  # Default values
  params <- list(
    ref_date = Sys.Date(),
    scenario = NA_character_,
    limit_companies = NULL,
    all_scenarios = FALSE,
    execute_next_day = TRUE
  )
  
  # Parse reference date if provided
  if (length(args) > 0) {
    ref_date <- tryCatch(
      as.Date(args[1]),
      error = function(e) {
        # Simplified error handling without log_message
        warning(sprintf("Invalid date format: %s. Using current date.", args[1]))
        return(Sys.Date())
      }
    )
    params$ref_date <- ref_date
  }
  
  # Parse scenario and limit_companies flags if provided
  if (length(args) > 1) {
    scen_arg <- grep("^--scenario=", args, value = TRUE)
    if (length(scen_arg) == 1) {
      params$scenario <- sub("^--scenario=", "", scen_arg)
    }
    limit_arg <- grep("^--limit_companies=", args, value = TRUE)
    if (length(limit_arg) == 1) {
      params$limit_companies <- as.integer(sub("^--limit_companies=", "", limit_arg))
      if (is.na(params$limit_companies) || params$limit_companies <= 0) {
        warning(sprintf("Invalid limit_companies value: %s. Ignoring limit.", sub("^--limit_companies=", "", limit_arg)))
        params$limit_companies <- NULL
      }
    }
    
    # Check for all_scenarios flag
    if (any(grepl("^--all_scenarios$", args))) {
      params$all_scenarios <- TRUE
      # If both --scenario and --all_scenarios are provided, --all_scenarios takes precedence
      if (!is.na(params$scenario)) {
        message("Note: --all_scenarios flag overrides --scenario")
      }
    }

    if (any(grepl("^--execute_next_day$", args))) {
      params$execute_next_day <- TRUE
    }
  }
  
  return(params)
}


# ============================================================================
# 3. MAIN ORCHESTRATOR FUNCTION
# ============================================================================

#' Main Orchestration Function
#' 
#' Orchestrates the execution of mmtm_preparedata.R and mmtm_runscenarios.R.
#' This script acts as the entry point for the entire momentum signal generation pipeline.
#' @return Invisible NULL
main_orchestrator <- function() {
  message("Momentum Cycle Signal Generation Orchestrator starting (v2)")
  start_time <- Sys.time()
  
  # Parse arguments once for the orchestrator
  params <- parse_arguments()
  ref_date <- params$ref_date
  selected_scenario <- params$scenario
  limit_companies <- params$limit_companies
  
  message(sprintf("Orchestrator Reference Date: %s", ref_date))
  if (!is.na(selected_scenario)) {
    message(sprintf("Orchestrator Selected Scenario: %s", selected_scenario))
  } else {
    message("Orchestrator will run default pipeline (no scenario override).")
  }
  if (!is.null(limit_companies)) {
    message(sprintf("Orchestrator Limiting companies to: %d", limit_companies))
  }
  
  # 3.1 Execute mmtm_preparedata.R (only if needed)
  prepared_data_file <- sprintf("output/mmtm/prepared_data_%s.csv", format(ref_date, "%Y-%m-%d"))
  
  if (file.exists(prepared_data_file)) {
    message(sprintf("✅ Prepared data file already exists: %s", basename(prepared_data_file)))
    message("Skipping data preparation - using existing prepared data")
  } else {
    message("Running mmtm_preparedata.R to generate intermediate dataset...")
    prepare_command <- sprintf("Rscript data_ingestion/Rscripts/s2_mmtm_preparedata.R \"%s\"", format(ref_date, "%Y-%m-%d"))
    if (!is.null(limit_companies)) {
      prepare_command <- paste0(prepare_command, sprintf(" --limit_companies=%d", limit_companies))
    }
    
    # Use `system2` with wait=TRUE to ensure we wait for completion
    prep_status <- system2("Rscript", 
                          args = unlist(strsplit(prepare_command, " "))[-1], 
                          stdout = "", 
                          stderr = "", 
                          wait = TRUE)
    
    if (prep_status != 0) {
      message(sprintf("❌ ERROR: s2_mmtm_preparedata.R failed with exit code %d", prep_status))
      message("🛑 Halting pipeline execution due to data preparation failure.")
      quit(save = "no", status = prep_status)
    }
    message("✅ Data preparation completed successfully")
  }
  
  # 3.2 Execute mmtm_runscenarios.R
  # Skip initial run - orchestrator loop handles all scenarios individually
  tracker_script <- "data_ingestion/Rscripts/s4_mmtm_clean_trade_tracker_fixed.R"
  
  if (!file.exists(tracker_script)) {
    warning("Trade tracker script not found at: ", tracker_script)
    return(invisible(NULL))
  }
  
  # Function to run tracker for a single scenario
  run_tracker_for_scenario <- function(scenario_name) {
    message(sprintf("\nRunning trade tracker for scenario: %s", scenario_name))
    tracker_args <- c(tracker_script, format(ref_date, "%Y-%m-%d"), paste0("--scenario=", scenario_name))
    if (!is.null(limit_companies)) {
      tracker_args <- c(tracker_args, sprintf("--limit_companies=%d", limit_companies))
    }
    
    tracker_status <- system2("Rscript", 
                            args = tracker_args, 
                            stdout = "", 
                            stderr = "", 
                            wait = TRUE)
    
    if (tracker_status != 0) {
      message(sprintf("❌ ERROR: Trade tracker for scenario %s failed with exit code %d", scenario_name, tracker_status))
      message("🛑 Halting pipeline execution due to trade tracker failure.")
      quit(save = "no", status = tracker_status)
    } else {
      message(sprintf("✅ Trade tracker for scenario %s completed successfully.", scenario_name))
      return(TRUE)
    }
  }
  
  # Process scenarios: Step 1 - Create momentum files, Step 2 - Run trade analysis
  message("🚀 Processing scenarios with simplified pipeline...")
  
  if (!exists("rule_sets")) {
    source("data_ingestion/Rscripts/s3.2_rule_sets.R", local = TRUE)
  }
  
  # Define scenarios to process - use specific scenario if provided, otherwise all scenarios
  if (!is.na(params$scenario) && nzchar(params$scenario)) {
    # Run specific scenario only
    scenarios_to_process <- params$scenario
    message(sprintf("Running specific scenario: %s", params$scenario))
  } else {
    # Run all available scenarios from rule sets
    scenarios_to_process <- names(rule_sets)
    message(sprintf("Found %d scenarios to process: %s", length(scenarios_to_process), paste(scenarios_to_process, collapse = ", ")))
  }
  
  # Process each scenario completely (momentum + trade analysis) one by one
  message("\n=== Processing scenarios completely (momentum + trade analysis) ===")
  for (scenario in scenarios_to_process) {
    message(sprintf("\n=== Processing scenario: %s ===", scenario))
    
    # STEP 1: Create momentum file for this scenario
    message(sprintf("--- Creating momentum file for scenario: %s ---", scenario))
    scenario_command <- sprintf("Rscript data_ingestion/Rscripts/s3_mmtm_runscenarios.R %s --scenario=%s --execute_next_day", 
                                     format(ref_date, "%Y-%m-%d"), scenario)
    
    # Add limit_companies only if specified
    if (!is.null(limit_companies)) {
      scenario_command <- paste0(scenario_command, sprintf(" --limit_companies=%d", limit_companies))
    }
    
    message(sprintf("DEBUG: Running command: %s", scenario_command))
    
    # Capture stderr to see the error
    result <- system2("Rscript", 
                      args = unlist(strsplit(scenario_command, " "))[2:length(strsplit(scenario_command, " ")[[1]])], 
                      stdout = "", 
                      stderr = TRUE, 
                      wait = TRUE)
    
    prep_status <- ifelse(is.null(attr(result, "status")), 0, attr(result, "status"))
    stderr_output <- result
    
    message(sprintf("DEBUG: s3_mmtm_runscenarios.R exit status: %d", prep_status))
    if (length(stderr_output) > 0) {
      message(sprintf("DEBUG: s3_mmtm_runscenarios.R stderr: %s", paste(stderr_output, collapse = "\n")))
    }
    
    if (prep_status != 0) {
      message(sprintf("❌ ERROR: s3_mmtm_runscenarios.R failed for scenario %s with exit code %d", scenario, prep_status))
      message("🛑 Halting pipeline execution due to scenario processing failure.")
      quit(save = "no", status = prep_status)
    }
    message(sprintf("✅ Momentum file created for scenario %s", scenario))
    
    # STEP 2: Run trade analysis for this scenario
    message(sprintf("--- Running trade analysis for scenario: %s ---", scenario))
    tracker_command <- sprintf("Rscript data_ingestion/Rscripts/s4_mmtm_clean_trade_tracker_fixed.R %s --scenario=%s", 
                                     format(ref_date, "%Y-%m-%d"), scenario)
    
    # Add limit_companies only if specified
    if (!is.null(limit_companies)) {
      tracker_command <- paste0(tracker_command, sprintf(" --limit_companies=%d", limit_companies))
    }
    
    message(sprintf("DEBUG: Running command: %s", tracker_command))
    tracker_status <- system2("Rscript", 
                            args = unlist(strsplit(tracker_command, " "))[2:length(strsplit(tracker_command, " ")[[1]])], 
                            stdout = "", 
                            stderr = "", 
                            wait = TRUE)
    
    if (tracker_status != 0) {
      message(sprintf("❌ ERROR: s4_mmtm_clean_trade_tracker_fixed.R failed for scenario %s with exit code %d", scenario, tracker_status))
      message("🛑 Halting pipeline execution due to trade tracker failure.")
      quit(save = "no", status = tracker_status)
    }
    message(sprintf("✅ Trade analysis completed for scenario %s", scenario))
    
    # Clean up: Remove momentum file after all 3 trade analysis files are created
    momentum_file <- sprintf("output/mmtm/%s_%s.csv", scenario, format(ref_date, "%Y-%m-%d"))
    trade_details_file <- sprintf("output/mmtm/trade_details_%s_%s.csv", scenario, format(ref_date, "%Y-%m-%d"))
    performance_metrics_file <- sprintf("output/mmtm/performance_metrics_%s_%s.csv", scenario, format(ref_date, "%Y-%m-%d"))
    atr_volatility_file <- sprintf("output/mmtm/atr_volatility_performance_%s_%s.csv", scenario, format(ref_date, "%Y-%m-%d"))
    
    # Check if all 3 trade analysis files exist before removing momentum file
    trade_files_exist <- file.exists(trade_details_file) &&
                        file.exists(performance_metrics_file) &&
                        file.exists(atr_volatility_file)
    
    if (trade_files_exist && file.exists(momentum_file)) {
      file_size <- file.info(momentum_file)$size
      file.remove(momentum_file)
      message(sprintf("🗑️ Removed momentum file %s (%.1f MB) after all trade analysis files created", 
                      basename(momentum_file), file_size / 1024^2))
    } else {
      message(sprintf("⚠️  WARNING: Not removing momentum file - some trade analysis files may be missing"))
      message(sprintf("   Trade details exists: %s", file.exists(trade_details_file)))
      message(sprintf("   Performance metrics exists: %s", file.exists(performance_metrics_file)))
      message(sprintf("   ATR volatility exists: %s", file.exists(atr_volatility_file)))
    }
    
    message(sprintf("✅ Complete pipeline finished for scenario %s", scenario))
    Sys.sleep(0.1)  # Small delay between scenarios
  }
  
  message(sprintf("\n🎉 All %d scenarios processed successfully!", length(scenarios_to_process)))
  
  # STEP 4: Run consolidation after all scenarios are complete
  message("\n=== Running consolidation for all scenarios ===")
  consolidation_command <- "Rscript data_ingestion/Rscripts/s4.2_consolidate_scenarios.R"
  
  message(sprintf("DEBUG: Running command: %s", consolidation_command))
  consolidation_status <- system2("Rscript", 
                                 args = unlist(strsplit(consolidation_command, " "))[2:length(strsplit(consolidation_command, " ")[[1]])], 
                                 stdout = "", 
                                 stderr = "", 
                                 wait = TRUE)
  
  if (consolidation_status != 0) {
    message(sprintf("❌ ERROR: s4.2_consolidate_scenarios.R failed with exit code %d", consolidation_status))
    message("⚠️  Continuing pipeline execution - consolidation failure is not critical")
  } else {
    message("✅ Consolidation completed for all scenarios")
  }
  
  }

# ============================================================================
# 4. SCRIPT EXECUTION
# ============================================================================

# 4.1 Main Execution Block
# ----------------------------------------------------------------------------
# Only execute if run as a script (not sourced)
if (identical(environment(), globalenv())) {
  main_orchestrator()
  message("Orchestration completed successfully")
}
