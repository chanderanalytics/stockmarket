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
  
  # Default values
  params <- list(
    ref_date = Sys.Date(),
    scenario = NA_character_,
    limit_companies = NULL
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
    message("Orchestrator will run all scenarios.")
  }
  if (!is.null(limit_companies)) {
    message(sprintf("Orchestrator Limiting companies to: %d", limit_companies))
  }
  
  # 3.1 Execute mmtm_preparedata.R
  message("Running mmtm_preparedata.R to generate intermediate dataset...")
  prepare_command <- sprintf("Rscript data_ingestion/Rscripts/s2_mmtm_preparedata.R \"%s\"", format(ref_date, "%Y-%m-%d"))
  if (!is.null(limit_companies)) {
    prepare_command <- paste0(prepare_command, sprintf(" --limit_companies=%d", limit_companies))
  }
  
  # Use `system2` for better error handling and capturing stderr separately
  prep_result <- system2("Rscript", args = unlist(strsplit(prepare_command, " "))[-1], stdout = TRUE, stderr = TRUE)
  prep_status <- attr(prep_result, "status")
  
  if (!is.null(prep_status) && prep_status != 0) {
    message(paste("s2_mmtm_preparedata.R failed. Output:\n", paste(prep_result, collapse = "\n")))
    stop("Data preparation failed.")
  }
  message("s2_mmtm_preparedata.R completed successfully.")
  
  # 3.2 Execute mmtm_runscenarios.R
  message("Running s2_mmtm_runscenarios.R to process scenarios...")
  run_command <- sprintf("Rscript data_ingestion/Rscripts/s2_mmtm_runscenarios.R \"%s\"", format(ref_date, "%Y-%m-%d"))
  if (!is.na(selected_scenario)) {
    run_command <- paste0(run_command, sprintf(" --scenario=%s", selected_scenario))
  }
  if (!is.null(limit_companies)) {
    run_command <- paste0(run_command, sprintf(" --limit_companies=%d", limit_companies))
  }
  
  run_result <- system2("Rscript", args = unlist(strsplit(run_command, " "))[-1], stdout = TRUE, stderr = TRUE)
  run_status <- attr(run_result, "status")
  
  if (!is.null(run_status) && run_status != 0) {
    message(paste("s2_mmtm_runscenarios.R failed. Output:\n", paste(run_result, collapse = "\n")))
    stop("Scenario execution failed.")
  }
  message("s2_mmtm_runscenarios.R completed successfully.")
  
  elapsed_total <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 2)
  message(paste("Total orchestration execution time:", elapsed_total, "seconds"))
  
  return(invisible(NULL))
}

# ============================================================================
# 4. SCRIPT EXECUTION
# ============================================================================

# 4.1 Main Execution Block
# ----------------------------------------------------------------------------
# Only execute if run as a script (not sourced)
if (identical(environment(), globalenv())) {
  tryCatch({
    main_orchestrator()
    message("Orchestration completed successfully")
  }, error = function(e) {
    error_msg <- if (is.null(e$message)) {
      if (inherits(e, "simpleError")) {
        as.character(e)
      } else {
        "Unknown error occurred"
      }
    } else {
      e$message
    }
    
    message(sprintf("Fatal error in orchestration: %s", error_msg))
    
    if (exists(".traceback")) {
      message("Stack trace:")
      message(utils::capture.output(print(.traceback())))
    }
    
    stop(simpleError(error_msg, call = sys.calls()[[1]]))
  })
}
