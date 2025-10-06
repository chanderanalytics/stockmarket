#!/usr/bin/env Rscript
# mmtm_runscenarios.R
# This script loads pre-calculated indicators and runs momentum cycle signals for multiple scenarios.
# Each scenario's output is saved to a dedicated directory.

source("data_ingestion/Rscripts/0_setup_renv.R")

# 1.1 Configure logging system
# ----------------------------------------------------------------------------
if (!dir.exists("log")) {
  dir.create("log", recursive = TRUE)
}

log_file <- file.path("log", sprintf("mmtm_runscenarios_%s.log", 
                                   format(Sys.time(), "%Y%m%d_%H%M%S")))
file.create(log_file)

log_message <- function(msg, level = "INFO") {
  if (length(msg) > 1) {
    msg <- paste(msg, collapse = " ")
  }
  
  if (level == "INFO" && any(grepl("company", tolower(msg)))) {
    return()
  }
  
  log_line <- sprintf("[%s] [%s] %s\n", 
                     format(Sys.time(), "%Y-%m-%d %H:%M:%S"), 
                     level, 
                     msg)
  
  if (level %in% c("ERROR", "WARN", "INFO")) {
    cat(log_line)
  }
  
  if (exists("log_file")) {
    cat(log_line, file = log_file, append = TRUE)
  }
  flush.console()
}

timer <- function(expr, message_text = "") {
  start <- Sys.time()
  log_message(paste0("START: ", message_text))
  res <- eval(expr)
  elapsed <- round(as.numeric(difftime(Sys.time(), start, units = "secs")), 2)
  log_message(paste0("COMPLETE: ", message_text, " (", elapsed, "s)"))
  res
}

# Try to source enriched indicators module if present (needed for some rule expressions)
if (file.exists("data_ingestion/Rscripts/calculate_indicators_module.R")) {
  tryCatch({
    source("data_ingestion/Rscripts/calculate_indicators_module.R", local = FALSE)
    log_message("Loaded calculate_indicators_enriched module for runscenarios")
  }, error = function(e) {
    log_message(sprintf("Failed to load calculate_indicators_enriched in runscenarios: %s", e$message), "WARN")
  })
}

# Attempt to load external rule sets once
.try_load_rule_sets <- function() {
  paths <- c(
    "data_ingestion/Rscripts/rule_sets.R",
    "/Users/chanderbhushan/stockmkt/data_ingestion/Rscripts/rule_sets.R"
  )
  for (p in paths) {
    if (file.exists(p)) {
      tryCatch({
        source(p, local = FALSE)
        return(TRUE)
      }, error = function(e) {
        log_message(sprintf("Failed to source rule_sets.R: %s", e$message), "WARN")
        return(FALSE)
    }
  }
  return(FALSE)
}

.rule_sets_available <- .try_load_rule_sets()


# 2.2 Argument Parsing (simplified for run scenarios)
# ----------------------------------------------------------------------------
#' Parse Command Line Arguments
#' 
#' Parses command line arguments to get reference date, scenario, and limit_companies.
#' @return List containing script parameters
parse_arguments <- function() {
 args <- commandArgs(trailingOnly = TRUE)
 
 # Default values
 params <- list(
  ref_date = Sys.Date(),
  output_dir = "output",
  scenario = NA_character_,
  limit_companies = NULL
 )
 
 # Parse reference date if provided
 if (length(args) > 0) {
  ref_date <- tryCatch(
   as.Date(args[1]),
   error = function(e) {
    log_message(sprintf("Invalid date format: %s. Using current date.", args[1]), "WARN")
    return(Sys.Date())
   }
  )
  params$ref_date <- ref_date
 }
 
 # Parse additional flags
 if (length(args) > 1) {
  scen_arg <- grep("^--scenario=", args, value = TRUE)
  if (length(scen_arg) == 1) {
    params$scenario <- sub("^--scenario=", "", scen_arg)
  }
  limit_arg <- grep("^--limit_companies=", args, value = TRUE)
  if (length(limit_arg) == 1) {
    params$limit_companies <- as.integer(sub("^--limit_companies=", "", limit_arg))
    if (is.na(params$limit_companies) || params$limit_companies <= 0) {
      log_message(sprintf("Invalid limit_companies value: %s. Ignoring limit.", sub("^--limit_companies=", "", limit_arg)), "WARN")
      params$limit_companies <- NULL
    }
  }
 }
 
 return(params)
}

# Parse command line arguments
params <- parse_arguments()
ref_date <- params$ref_date
selected_rule_set_name <- if (!is.null(params$scenario) && !is.na(params$scenario)) params$scenario else NA_character_

log_message(sprintf("Reference date set to: %s", ref_date))

# ============================================================================
# 3. CORE ANALYSIS FUNCTIONS (adapted from mmtm.R)
# ============================================================================

# Materialize rules from a rule_set into boolean columns and rebuild stage_defs
materialize_rule_set <- function(dt, rule_set) {
  if (!is.list(rule_set) || length(rule_set) == 0) {
    stop("Invalid rule_set provided")
  }
  setorder(dt, company_id, date)
  new_stage_defs <- list()
  for (s in names(rule_set)) {
    stage_info <- rule_set[[s]]
    rules <- stage_info$rules
    generated_cols <- character(0)
    idx <- 0L
    for (expr in rules) {
      idx <- idx + 1L
      col_name <- sprintf("RULE_S%s_%02d", s, idx)
      # Safely evaluate the expression per row → integer 0/1
      val <- tryCatch({
        res <- dt[, eval(parse(text = expr))]
        as.integer(res == TRUE | res == 1)
      }, error = function(e) {
        log_message(sprintf("Rule eval failed for stage %s expr '%s': %s", s, expr, e$message), "WARN")
        rep.int(0L, nrow(dt))
      })
      dt[, (col_name) := val]
      generated_cols <- c(generated_cols, col_name)
    }
    new_stage_defs[[s]] <- list(
      stage = as.integer(s),
      name = if (!is.null(stage_info$name)) stage_info$name else sprintf("STAGE_%s", s),
      rules = generated_cols,
      optimal_days = if (!is.null(stage_info$optimal_days)) stage_info$optimal_days else 5,
      score_expression = if (!is.null(stage_info$score_expression)) stage_info$score_expression else "0"
    )
  }
  # Store stage_defs as an attribute to dt to avoid global modification
  attr(dt, "scenario_stage_defs") <- new_stage_defs
  attr(dt, "rules_materialized") <- TRUE
  dt
}

#' Evaluate Trading Rules
#' 
#' Applies trading rules to identify potential entry and exit points.
#' @param dt data.table with price and indicator data
#' @return data.table with rule evaluation results
#' @details
#' This function now either skips evaluation if rules are already materialized
#' from a scenario, or applies the default 'momentum_0' scenario rules if no
#' scenario was explicitly selected.
evaluate_rules <- function(dt) {
  # If rules have already been materialized by a selected scenario, just return.
  if (isTRUE(attr(dt, "rules_materialized"))) {
    log_message("Rules already materialized from scenario. Skipping evaluate_rules.", "DEBUG")
    return(dt)
  }
  
  # If no scenario was selected and rules are not materialized, return dt as is.
  log_message("No scenario explicitly selected or rules not materialized. Returning data without applying default rules.", "INFO")
 return(dt)
}

# Helper function to check if a stock is close to a stage (missing only one rule)
# @param dt data.table with rule evaluation results
# @param target_stage Integer (0-5) representing the stage to check
# @return Logical vector indicating if each row is close to the target stage
is_close_to_stage <- function(dt, target_stage) {
 # Retrieve rules directly from the scenario_stage_defs attribute
 stage_defs_local <- attr(dt, "scenario_stage_defs")
 rules <- if (as.character(target_stage) %in% names(stage_defs_local)) {
  stage_defs_local[[as.character(target_stage)]]$rules
 } else {
  character(0)
 }
 
 # Check which rules exist in the data
 existing_rules <- intersect(rules, names(dt))
 if (length(existing_rules) == 0) {
  return(rep(FALSE, nrow(dt)))
 }
 
 # Check if all or all but one rule is met
 rules_met <- rowSums(dt[, ..existing_rules] == 1, na.rm = TRUE)
 total_rules <- length(existing_rules)
 return(rules_met >= pmax(1, total_rules - 1))
}

# Function to calculate stage scores based on underlying metrics
# @param dt data.table with price and indicator data
# @return data.table with added stage score columns (stage_0_score through stage_5_score)
calculate_stage_scores <- function(dt) {
 log_message("Calculating stage scores dynamically...")
 
 # Retrieve stage_defs from dt attributes
 stage_defs_local <- attr(dt, "scenario_stage_defs")
 if (is.null(stage_defs_local)) {
  log_message("Error: scenario_stage_defs attribute not found on dt. Cannot calculate scores.", "ERROR")
  return(dt)
 }

 # Initialize score columns based on defined stages
 for (s_char in names(stage_defs_local)) {
  score_col <- paste0('stage_', s_char, '_score')
  dt[, (score_col) := 0]
 }

 # Dynamically calculate scores for each defined stage
 for (s_char in names(stage_defs_local)) {
  stage_info <- stage_defs_local[[s_char]]
  score_expression <- stage_info$score_expression
  score_col <- paste0('stage_', s_char, '_score')

  if (!is.null(score_expression) && nchar(score_expression) > 0) {
   log_message(sprintf(" Evaluating score for Stage %s: %s", s_char, score_expression), "DEBUG")
   tryCatch({
    # Use `dt[, eval(parse(text = score_expression))]` to evaluate the expression within the data.table context
    dt[, (score_col) := eval(parse(text = score_expression))]
   }, error = function(e) {
    log_message(sprintf("Error calculating score for stage %s: %s", s_char, e$message), "ERROR")
    dt[, (score_col) := 0]
   })
 } else {
   log_message(sprintf("No score_expression defined for stage %s. Score set to 0.", s_char), "WARN")
  }
 }
 
 # Ensure scores are between 0 and 100
 for (s_char in names(stage_defs_local)) {
  score_col <- paste0('stage_', s_char, '_score')
  if (score_col %in% names(dt)) {
   dt[, (score_col) := pmin(100, pmax(0, get(score_col)))]
  }
 }
 
 log_message("Completed dynamic stage score calculation", "DEBUG")
 return(dt)
}

# Function to evaluate close-to-stage conditions
# @param dt data.table with stage assignments and rule evaluations
# @return data.table with added close_to_stage_X columns and best_partial_stage
evaluate_partial_signals <- function(dt) {
 log_message("Starting evaluation of partial signals", "INFO")
 start_time <- Sys.time()
 
 # Retrieve stage_defs from dt attributes
 stage_defs_local <- attr(dt, "scenario_stage_defs")
 if (is.null(stage_defs_local)) {
  log_message("Error: scenario_stage_defs attribute not found on dt. Cannot evaluate partial signals.", "ERROR")
  return(dt)
 }

 # Initialize all close_to_stage_X columns with 0
 log_message("Initializing close_to_stage_X columns", "DEBUG")
 for (s_char in names(stage_defs_local)) {
  col_name <- paste0('close_to_stage_', s_char)
  dt[, (col_name) := 0L]
  log_message(sprintf(" Initialized column: %s", col_name), "TRACE")
 }
 
 # Process each stage
 for (s_char in names(stage_defs_local)) {
  s <- as.integer(s_char)
  rules <- stage_defs_local[[s_char]]$rules
  existing_rules <- intersect(rules, names(dt))
  if (length(existing_rules) == 0) next
  
  # Check if rows are close to this stage (not current stage and meets all or all but one rule)
  rules_met <- rowSums(dt[, ..existing_rules] == 1, na.rm = TRUE)
  total_rules <- length(existing_rules)
  
  is_close <- ((!is.na(dt$stage) & !(dt$stage %in% s)) | is.na(dt$stage)) &
       (rules_met >= pmax(1, total_rules - 1))
  
  # Update the close_to_stage column
  dt[is_close, (paste0('close_to_stage_', s)) := 1L]
 }
 
 # Set best_partial_stage to 0 for all records (temporary solution)
 dt[, best_partial_stage := 0L]
 
 log_message(sprintf("Completed partial signal evaluation in %.2f seconds", 
          as.numeric(difftime(Sys.time(), start_time, units = "secs"))), 
      "INFO")
 
 return(dt)
}

#' Assign Momentum Stages
#' 
#' Determines the current momentum stage for each stock based on rule evaluations.
#' @param dt data.table with rule evaluation results
#' @return data.table with assigned stages and rule metrics
#' @details
#' Stages progress from 0 (low volatility) to 4 (extended trend).
#' Each stage requires a minimum number of rules to be satisfied.
#' The function tracks:
#' - Current stage
#' - Best partial stage 
#' - Stage assignment based on rule conditions
assign_stage <- function(dt) {
 log_message("Assigning momentum stages...")
 
 # Retrieve stage_defs from dt attributes
 stage_defs_local <- attr(dt, "scenario_stage_defs")
 if (is.null(stage_defs_local)) {
  log_message("Error: scenario_stage_defs attribute not found on dt. Cannot assign stages.", "ERROR")
  return(dt)
 }

 # Initialize stage tracking columns
 dt[, `:=`(
  stage = NA_integer_,      # Current stage (0-5)
  best_partial_stage = NA_character_ # Comma-separated list of stages this is close to
 )]
 
 # Log initial state
 log_message(sprintf(" Processing %d companies with %d rows total", 
          dt[, uniqueN(company_id)], nrow(dt)), "INFO")
 
 # Precompute rule names for ease
 log_message("\nSTAGE ASSIGNMENT SUMMARY", "INFO")
 log_message(paste(rep("-", 50), collapse = ""), "INFO")
 
 for (s in names(stage_defs_local)) {
  if (!s %in% names(stage_defs_local)) {
   log_message(paste0("Warning: Stage definition not found for stage: ", s))
   next
  }
  
  # Safely get rules for this stage
  rules <- tryCatch({
   stage_defs_local[[s]]$rules
  }, error = function(e) {
   log_message(paste0("Error accessing rules for stage ", s, ": ", e$message))
   NULL
  })
  
  if (is.null(rules) || length(rules) == 0) {
   log_message(paste0("No rules defined for stage ", s))
   next
  }
  
  log_message(sprintf("\nProcessing stage %s with %d rules: %s", 
           s, length(rules), paste(rules, collapse = ", ")), "DEBUG")
  
  # Check which rules exist in the data
  present_rules <- rules[rules %in% names(dt)]
  missing_rules <- setdiff(rules, present_rules)
  
  if (length(present_rules) == 0) {
   log_message(sprintf(" No valid rules found in data for stage %s. Missing rules: %s", 
            s, paste(missing_rules, collapse = ", ")), "WARN")
   next
  }
  
  if (length(missing_rules) > 0) {
   log_message(sprintf(" Warning: %d rules missing for stage %s: %s", 
            length(missing_rules), s, 
            paste(missing_rules, collapse = ", ")), "WARN")
  }
  
  # Count met per row
  met_mat <- tryCatch({
   dt[, .SD, .SDcols = present_rules]
  }, error = function(e) {
   log_message(paste0("Error accessing rule columns for stage ", s, ": ", e$message))
   NULL
  })
  
  if (is.null(met_mat)) next
  
  met_count <- rowSums(as.matrix(met_mat) == 1, na.rm = TRUE)
  total <- length(present_rules)
  
  # Log rule statistics
  rule_stats <- colSums(met_mat == 1, na.rm = TRUE)
  rule_pct <- round(rule_stats / nrow(met_mat) * 100, 1)
  rule_summary <- data.table(
   rule = names(rule_stats),
   count = rule_stats,
   pct = rule_pct
  )
  
  log_message(sprintf(" Rule statistics for stage %s (showing rules met in >0%% of rows):", s), "DEBUG")
  log_message(capture.output(print(rule_summary[count > 0], nrows = 20)), "DEBUG")
  
  # Full matches -> assign stage
  full_idx <- which(met_count == total & total > 0)
  if (length(full_idx) > 0) {
   dt[full_idx, stage := as.integer(s)]
   log_message(sprintf(" Assigned stage %s to %d rows (%.1f%% of data)", 
            s, length(full_idx), 
            length(full_idx)/nrow(dt)*100), "DEBUG")
  } else {
   log_message(sprintf(" No full matches for stage %s (0 rows met all %d rules)", 
            s, total), "DEBUG")
  }
 }
 
 # Carry forward stage (locf) to avoid gaps
 dt[, stage := nafill(stage, type = "locf", fill = 0), by = company_id]
 
 # Replace NA stages with "NO_STAGE"
 dt[is.na(stage), stage := 0] # Use 0 as a placeholder for NO_STAGE
 
 # Log final stage distribution
 stage_dist <- dt[, .N, by = stage][order(stage)]
 total_rows <- nrow(dt)
 
 log_message("\nFINAL STAGE DISTRIBUTION", "INFO")
 log_message(paste(rep("-", 50), collapse = ""), "INFO")
 
 for (i in 1:nrow(stage_dist)) {
  stage_name <- if(stage_dist$stage[i] == -1) {
   "NO_STAGE"
  } else {
   # Use stage_defs_local for dynamic stage names
   s_char <- as.character(stage_dist$stage[i])
   if (s_char %in% names(stage_defs_local)) {
    stage_defs_local[[s_char]]$name
   } else {
    as.character(stage_dist$stage[i]) # Fallback
   }
  }
  
  pct <- round(stage_dist$N[i] / total_rows * 100, 1)
  log_message(sprintf(" Stage %s (%s): %d rows (%.1f%%)", 
           stage_dist$stage[i], stage_name, 
           stage_dist$N[i], pct), "INFO")
 }
 
 log_message(sprintf(" Total assigned stages: %d rows (%.1f%% of total data)", 
          total_rows, total_rows/nrow(dt)*100), "INFO")
 
 return(dt)
}

add_stage_history <- function(dt) {
  setorder(dt, company_id, date)
  
  # Retrieve stage_defs from dt attributes
  stage_defs_local <- attr(dt, "scenario_stage_defs")
  if (is.null(stage_defs_local)) {
    log_message("Error: scenario_stage_defs attribute not found on dt. Cannot add stage history.", "ERROR")
    return(dt)
  }

  # Ensure stage has locf filled
  dt[, stage_ff := nafill(stage, type = "locf"), by = company_id]
  
  # Track last 3 stage changes
  dt[, stage_history := {
    # Get only the stage changes (where stage is different from previous)
    changes <- which(c(TRUE, diff(stage_ff) != 0))
    
    # Get the last 3 changes (or fewer if not enough changes)
    last_changes <- tail(changes, 3)
    
    # Get the stages and their start dates
    stages <- stage_ff[last_changes]
    
    # Calculate days in each stage
    ends <- c(last_changes[-1] - 1, length(stage_ff))
    days_in_stage <- ends - last_changes + 1
    
    # Create stage names mapping dynamically from stage_defs_local
    stage_names_map <- sapply(names(stage_defs_local), function(s) stage_defs_local[[s]]$name)
    names(stage_names_map) <- names(stage_defs_local)
    
    # Format each stage change
    stage_strings <- mapply(
      function(s, d) {
        stage_name <- stage_names_map[as.character(s)]
        if (is.na(stage_name)) stage_name <- paste("Stage", s)
        sprintf("%s (%d day%s)", stage_name, d, ifelse(d > 1, "s", ""))
      },
      stages,
      days_in_stage
    )
    
    # Combine with arrows and repeat for all rows
    history <- paste(rev(stage_strings), collapse = " → ")
    rep(history, .N)
  }, by = company_id]
  
  return(dt)
}

#' Calculate Dynamic Support/Resistance
#' 
#' Identifies key price levels for stop-loss and take-profit calculations.
#' @param dt data.table with price data and indicators
#' @return data.table with dynamic levels added
#' @details
#' Calculates:
#' - Swing highs/lows using local maxima/minima
#' - Support/resistance zones based on recent price action
#' - Stop-loss and take-profit levels using ATR and recent volatility
calculate_dynamic_levels <- function(dt) {
 log_message("Calculating dynamic price levels...")
 
 # Retrieve stage_defs from dt attributes
 stage_defs_local <- attr(dt, "scenario_stage_defs")
 if (is.null(stage_defs_local)) {
  log_message("Error: scenario_stage_defs attribute not found on dt. Cannot calculate dynamic levels.", "ERROR")
  return(dt)
 }

 # 5.4.1 Data Preparation
 # Ensure data is ordered by company and date
 setorder(dt, company_id, date)
 
 # Calculate swing lows/highs with error handling
 dt[, `:=`(
  swing_low_5d = tryCatch({
   frollapply(low, 5, min, align = "right", fill = NA)
  }, error = function(e) {
   log_message("Error calculating swing_low_5d: ", e$message)
   rep(NA_real_, .N)
  }),
  swing_low_10d = tryCatch({
   frollapply(low, 10, min, align = "right", fill = NA)
  }, error = function(e) {
   log_message("Error calculating swing_low_10d: ", e$message)
   rep(NA_real_, .N)
  }),
  swing_high_5d = tryCatch({
   frollapply(high, 5, max, align = "right", fill = NA)
  }, error = function(e) {
   log_message("Error calculating swing_high_5d: ", e$message)
   rep(NA_real_, .N)
  })
 ), by = company_id]
 
 # Base stop multiplier by stage with safe access to stage_defs (vectorized version)
 dt[, base_stop_pct := {
  # Use fifelse for vectorized conditional logic
  fifelse(
   is.na(stage), 2.0, # Default if stage is NA
   fifelse(
    as.character(stage) %in% names(stage_defs_local),
    fcase(
     stage == 0, 1.5,
     stage == 1, 2.0,
     stage == 2, 2.5,
     stage == 3, 3.0,
     stage == 4, 1.0,
     default = 2.0 # Default if stage number is unexpected
    ),
    2.0 # Default if stage not found in stage_defs_local
   )
  )
 }]
 
 # Time factor and vol/momentum factors with error handling
 # First calculate optimal_holding_days using vectorized operations
 dt[, optimal_holding_days := {
  fifelse(
   is.na(stage), NA_integer_,
   fifelse(
    as.character(stage) %in% names(stage_defs_local),
    {
     # Safely get optimal_days for each stage
     sapply(as.character(stage), function(s) {
      if (s %in% names(stage_defs_local)) {
       stage_defs_local[[s]]$optimal_days
      } else {
       NA_integer_
      }
     })
    },
    NA_integer_
   )
  )
 }]
 
 # Now calculate the remaining factors
 dt[, `:=`(
  stage_age = seq_len(.N),
  time_factor = pmax(0.5, 1 - (seq_len(.N) / pmax(optimal_holding_days, 1)) * 0.5),
  vol_factor = pmin(pmax(vol_21d, 0.001, na.rm = TRUE) / 0.20, 1.5, na.rm = TRUE),
  momentum_factor = 1 + pmin(pmax(return_21d * 10, 0, na.rm = TRUE), 1, na.rm = TRUE)
 ), by = .(company_id, rleid(stage))]
 
 # Compute base stop with error handling
 dt[, base_stop := {
  tryCatch({
   close - (atr * base_stop_pct * time_factor * vol_factor / pmax(momentum_factor, 1e-6))
  }, error = function(e) {
   log_message(paste0("Error calculating base_stop: ", e$message))
   close * 0.9 # Default to 10% below close on error
  })
 }]
 
 # Stage-specific stop levels with error handling
 dt[, stop_loss := base_stop] # Default to base_stop
 
 # First, ensure base_stop is calculated for all rows
 dt[, base_stop := {
  tryCatch({
   close - (atr * base_stop_pct * time_factor * vol_factor / pmax(momentum_factor, 1e-6))
  }, error = function(e) {
   log_message(paste0("Error calculating base_stop: ", e$message))
   close * 0.9 # Default to 10% below close on error
  })
 }]
 
 # Initialize stop_loss with base_stop
 dt[, stop_loss := base_stop]
 
 # Update stop losses by stage with safety checks
 update_stop_loss <- function(condition, new_value_expr) {
  tryCatch({
   dt[eval(parse(text = condition)), stop_loss := eval(parse(text = new_value_expr))]
  }, error = function(e) {
   log_message(paste0("Error updating stop loss for condition ", condition, ": ", e$message))
  })
 }
 
 # Apply stop loss rules by stage
 update_stop_loss("stage == 0 & !is.na(swing_low_5d)", "pmax(base_stop, swing_low_5d * 0.99, na.rm = TRUE)")
 update_stop_loss("stage == 1 & !is.na(swing_low_5d)", "pmax(base_stop, swing_low_5d * 0.98, na.rm = TRUE)")
 update_stop_loss("stage == 2 & !is.na(ma_21)", "pmax(base_stop, ma_21 * 0.97, na.rm = TRUE)")
 
 # More complex stage 3 stop with fallbacks - vectorized version
 dt[stage == 3, stop_loss := {
  tryCatch({
   ma_stop <- ma_50 * 0.95
   swing_stop <- swing_low_10d * 0.95
   pmax(base_stop, ma_stop, swing_stop, na.rm = TRUE)
  }, error = function(e) {
   log_message(paste0("Error calculating stage 3 stop loss: ", e$message))
   base_stop
  })
 }]
 
 # Ensure stop is never below previous stop for same stage group (trail up)
 dt[, stop_loss := {
  tryCatch({
   cummax(nafill(stop_loss, type = "locf"))
  }, error = function(e) {
   log_message(paste0("Error in cummax for stop_loss: ", e$message))
   stop_loss
  })
 }, by = .(company_id, rleid(stage))]
 
 dt[, stop_pct := tryCatch({
    # Ensure stop is below current price for long positions
    stop_loss <- pmin(stop_loss, close * 0.99)  # Force stop to be at least 1% below current price
    # Calculate percentage distance
    ((close - stop_loss) / close) * 100
  }, 
  error = function(e) {
    log_message(paste0("Error calculating stop_pct: ", e$message))
    rep(NA_real_, .N)
  }
)]

 # Ensure stop_loss is properly defined and below current price
 if (!"stop_loss" %in% names(dt)) {
   dt[, stop_loss := close * 0.95]  # Default to 5% below close if not set
 } else {
   dt[, stop_loss := pmin(stop_loss, close * 0.99)]
 }
 
 # Calculate take profit with 2:1 reward-to-risk ratio
 dt[, take_profit := {
   tryCatch({
     close + (close - stop_loss) * 2
   }, error = function(e) {
     log_message(paste0("Error calculating take_profit: ", e$message))
     close * 1.1 # Default to 10% above close on error
   })
 }]
 
 # Calculate take profit percentage
 dt[, take_profit_pct := ((take_profit - close) / close) * 100]
 
 # Calculate risk/reward ratio with proper vectorization
 dt[, risk_reward := {
   tryCatch({
     risk <- close - stop_loss
     reward <- take_profit - close
     ifelse(abs(risk) < 1e-6, NA_real_, reward / risk)
   }, error = function(e) {
     log_message(paste0("Error calculating risk_reward: ", e$message))
     rep(NA_real_, .N)
   })
 }]
 
 return(dt)
}

add_metadata <- function(dt) {
 setorder(dt, company_id, date)
 
 # Retrieve stage_defs from dt attributes
 stage_defs_local <- attr(dt, "scenario_stage_defs")
 if (is.null(stage_defs_local)) {
  log_message("Error: scenario_stage_defs attribute not found on dt. Cannot add metadata.", "ERROR")
  return(dt)
 }

 # stage change using locf stage for stability - handle vectorized operations
 dt[, stage_ff := {
  if (.N > 0) nafill(stage, type = "locf") else NA_integer_
 }, by = company_id]
 
 # Calculate stage changes safely
 dt[, stage_change := {
  prev_stage <- shift(stage_ff, 1, type = "lag")
  !is.na(stage_ff) & !is.na(prev_stage) & (stage_ff != prev_stage)
 }, by = company_id]
 
 # Calculate stage group
 dt[, stage_group := rleid(stage_ff), by = company_id]
 
 # Calculate stage_age with proper run-length encoding - memory efficient version
 dt[, stage_age := {
  # Create a run-length ID for each stage per company
  rl <- rleid(stage_ff)
  # Calculate run lengths within each company group
  unlist(by(rl, company_id, function(x) {
   if (length(x) == 0) return(rep(NA_integer_, length(x)))
   r <- rle(x)
   sequence(r$lengths)
  }, simplify = FALSE))
 }]
 
 # Calculate optimal_holding_days based on stage_ff
 dt[, optimal_holding_days := {
  sapply(stage_ff, function(s) {
   if (is.na(s)) return(NA_integer_)
   s_char <- as.character(s)
   if (s_char %in% names(stage_defs_local)) {
    return(stage_defs_local[[s_char]]$optimal_days)
   } else {
    log_message(paste0("Warning: Invalid stage_ff value: ", s))
    return(NA_integer_)
   }
  })
 }]
 
 # Calculate days_remaining with proper NA handling
 dt[, days_remaining := {
  if (all(is.na(optimal_holding_days))) {
   rep(NA_integer_, .N)
  } else {
   pmax(0, optimal_holding_days - stage_age + 1, na.rm = TRUE)
  }
 }]
 
 # Dynamic factors already computed, pack progress factor
 dt[, progress_factor := pmin((close / shift(close, 21) - 1) / 0.2, 1)]
 
 # Initialize trade tracking columns if they don't exist (just the columns, no logic yet)
 trade_cols <- c('entry_price', 'exit_price', 'entry_date', 'exit_date', 'pnl_pct')
 for (col in trade_cols) {
  if (!col %in% names(dt)) {
   if (col %in% c('entry_date', 'exit_date')) {
    dt[, (col) := as.character(NA)]
   } else {
    dt[, (col) := NA_real_]
   }
  }
 }
 
 # Entry/exit signals
 dt[, is_entry := (!is.na(stage_ff) & stage_change == TRUE)]
 dt[, is_exit := (shift(stage_change, type = "lead") == TRUE) | 
   (stage_age >= optimal_holding_days & !is.na(optimal_holding_days)), by = company_id]
 
 # Evaluate close-to-stage conditions
 log_message(sprintf("DEBUG: Starting partial signal evaluation..."))
 dt <- evaluate_partial_signals(dt)
 log_message(sprintf("DEBUG: Completed partial signal evaluation"))
  # Log data structure after partial signals
  log_message(sprintf("DEBUG: Data dimensions after partial signals: %d rows, %d columns", nrow(dt), ncol(dt)))
  log_message(sprintf("DEBUG: Sample of stage_ff values: %s", paste(head(unique(na.omit(dt$stage_ff))), collapse=", ")))
  log_message(sprintf("DEBUG: Sample of close_to_stage_X columns: %s", 
              paste(grep("close_to_stage_", names(dt), value=TRUE), collapse=", ")))
  
  # Check for any NA values in key columns
  log_message(sprintf("DEBUG: NA check - stage_ff: %d of %d (%.2f%%)", 
                     sum(is.na(dt$stage_ff)), nrow(dt), 
                     round(mean(is.na(dt$stage_ff))*100, 2)))
 
 # Status assignment with risk-reward based conditions
 log_message(sprintf("DEBUG: Starting status assignment..."))
 dt[, `:=`(status = {
  # Initialize with NO_ACTION
  result <- rep("NO_ACTION", .N)
  
  # 1. ENTRY Conditions (Long only)
  entry_conditions <- 
   (close > stop_loss) &        # Price must be above stop loss (long only)
   (stage_ff %in% c(0, 1, 2, 3)) & # Enter in setup/accumulation/advancement stages
   (stop_pct <= 10) &          # Reasonable stop distance (max 10%)
   (stop_pct >= 1)             # Minimum stop distance (at least 1%)
  
  # 2. EXIT Conditions
  # Stage-based targets and holding periods
  stage_targets_df <- data.table(
    stage = 0:5,
    min_return_pct = c(0, 5, 10, 15, 20, 0),  # More conservative minimum returns
    max_return_pct = c(0, 15, 25, 30, 40, 0),  # More realistic maximum returns
    # Use optimal_days from stage_defs_local instead of hardcoding
    optimal_days = sapply(0:5, function(s) {
      s_char <- as.character(s)
      if (s_char %in% names(stage_defs_local)) {
        return(stage_defs_local[[s_char]]$optimal_days)
      } else {
        return(NA_integer_)
      }
    })
  )
  
  # Calculate current return since entry and days in position
  current_return <- (close / entry_price - 1) * 100
  days_in_position <- as.numeric(difftime(date, entry_date, units = "days"))
  
  # Initialize exit conditions as FALSE
  exit_conditions <- rep(FALSE, length(close))
  
  # Process each stage separately to ensure vector alignment
  for(s_val in 0:5) {
    # Get indices for current stage
    stage_mask <- !is.na(stage_ff) & stage_ff == s_val
    if(any(stage_mask)) {
      # Get targets for current stage dynamically
      stage_info <- stage_targets_df[stage == s_val]
      
      # Calculate exit conditions for this stage
      stage_exits <- 
        (close[stage_mask] <= stop_loss[stage_mask]) |  # Hit stop loss
        (s_val == 5) |  # In distribution stage
        (s_val == 4 & close[stage_mask] < shift(close[stage_mask], type = "lag")) |  # Early signs of topping
        (current_return[stage_mask] >= stage_info$max_return_pct) |  # Reached max target
        (days_in_position[stage_mask] >= stage_info$optimal_days &  # Held long enough
         current_return[stage_mask] >= stage_info$min_return_pct)  # With minimum return
      
      # Update exit conditions for this stage
      exit_conditions[stage_mask] <- stage_exits
    }
  }
  
  # Add debug logging
  log_message(sprintf("Exit conditions: %d rows (%.1f%% of data)", 
                     sum(exit_conditions, na.rm = TRUE),
                     mean(exit_conditions, na.rm = TRUE) * 100))
  
  # 3. HOLD Conditions (only for positions not hitting exit conditions)
  hold_conditions <-
   !is.na(entry_price) & # In a position
   !exit_conditions    # Not hitting exit conditions

  # Apply signals in order of priority
  result[exit_conditions] <- "EXIT"
  result[entry_conditions] <- "ENTRY"
  result[hold_conditions] <- "HOLD"
  
  # Add stage information to non-NO_ACTION statuses
  non_action_idx <- which(result != "NO_ACTION")
  if (length(non_action_idx) > 0) {
   result[non_action_idx] <- sapply(non_action_idx, function(i) {
    s <- stage_ff[i]
    if (is.na(s)) return(result[i])
    s_char <- as.character(s)
    stage_name <- if (s_char %in% names(stage_defs_local)) {
     stage_defs_local[[s_char]]$name
    } else {
     "UNKNOWN_STAGE"
    }
    paste0(result[i], "_S", s, "_", stage_name)
   })
  }
  
  result
 })]
 
 # Track entry/exit prices and dates for current stage trade
 dt[, c("entry_price", "exit_price", "entry_date", "exit_date") := {
   # Initialize with current values
   new_entry_price <- entry_price
   new_entry_date <- entry_date
   new_exit_price <- exit_price
   new_exit_date <- exit_date
   
   # Get current stage
   current_stage <- stage_ff
   prev_stage <- shift(stage_ff, 1, type = "lag")
   
   # Check for stage changes
   stage_changed <- !is.na(current_stage) & (is.na(prev_stage) | current_stage != prev_stage)
   
   # On new stage, clear previous trade data
   new_entry_price[stage_changed] <- NA_real_
   new_entry_date[stage_changed] <- NA_character_
   new_exit_price[stage_changed] <- NA_real_
   new_exit_date[stage_changed] <- NA_character_
   
   # Update entry on ENTRY status for current stage
   is_entry <- startsWith(status, "ENTRY_")
   new_entry_price[is_entry] <- close[is_entry]
   new_entry_date[is_entry] <- as.character(date[is_entry])
   
   # Update exit on EXIT status for current stage
   is_exit <- startsWith(status, "EXIT_")
   new_exit_price[is_exit] <- close[is_exit]
   new_exit_date[is_exit] <- as.character(date[is_exit])
   
   # Return updated columns
   list(new_entry_price, new_exit_price, new_entry_date, new_exit_date)
 }, by = company_id]
  
 # Function to generate data quality summary
 generate_data_quality_summary <- function(dt, context = "") {
  log_message(paste0("\n=== Data Quality Summary ", context, " ==="))
  
  # Basic info
  log_message(sprintf("Total Rows: %d", nrow(dt)))
  log_message(sprintf("Unique Companies: %d", length(unique(dt$company_id))))
  log_message(sprintf("Date Range: %s to %s", 
           min(dt$date, na.rm = TRUE), 
           max(dt$date, na.rm = TRUE)))
  
  # Key column checks
  key_cols <- c("company_id", "date", "close", "status", 
        "entry_price", "exit_price", "pnl_pct", "stage_ff")
  
  log_message("\nMissing Values in Key Columns:")
  na_summary <- sapply(key_cols, function(col) {
   na_count <- sum(is.na(dt[[col]]))
   pct_na <- round(na_count / nrow(dt) * 100, 2)
   sprintf(" %-15s: %8d (%5.2f%%)", col, na_count, pct_na)
  })
  log_message(paste(na_summary, collapse = "\n"))
  
  # Status distribution
  log_message("\nStatus Distribution:")
  status_dist <- dt[, .N, by = status][order(-N)]
  for (i in 1:nrow(status_dist)) {
   pct <- round(status_dist$N[i] / nrow(dt) * 100, 2)
   log_message(sprintf(" %-20s: %8d (%5.2f%%)", 
            status_dist$status[i], 
            status_dist$N[i],
            pct))
  }
  
  # Stage distribution
  if ("stage_ff" %in% names(dt)) {
   log_message("\nStage Distribution:")
   stage_dist <- dt[, .N, by = stage_ff][order(-N)]
   for (i in 1:nrow(stage_dist)) {
    pct <- round(stage_dist$N[i] / nrow(dt) * 100, 2)
    log_message(sprintf(" Stage %-15s: %8d (%5.2f%%)", 
             stage_dist$stage_ff[i], 
             stage_dist$N[i],
             pct))
   }
  }
  
  # Numeric columns summary
  num_cols <- names(dt)[sapply(dt, is.numeric)]
  log_message("\nNumeric Columns Summary:")
  num_summary <- lapply(num_cols, function(col) {
   data.table(
    column = col,
    min = min(dt[[col]], na.rm = TRUE),
    mean = mean(dt[[col]], na.rm = TRUE),
    median = median(dt[[col]], na.rm = TRUE),
    max = max(dt[[col]], na.rm = TRUE),
    na_count = sum(is.na(dt[[col]]))
   )
  })
  
  # Print top 10 numeric columns by NA count
  na_summary <- rbindlist(num_summary)[order(-na_count)]
  log_message("Top 10 numeric columns with most NAs:")
  print(na_summary[1:min(10, nrow(na_summary)), 
          .(column, na_count, 
           pct_na = round(na_count/nrow(dt)*100, 2))])
  
  log_message("\n")
  return(invisible(TRUE))
 }
 
 # Generate initial data quality report
 generate_data_quality_summary(dt, "Before Trade Summary Generation")
 
 # Create trade summary for clear position tracking
 dt[, trade_summary := {
  tryCatch({
   # Debug info
   message("Starting trade summary generation for company: ", company_id[1])
   
   # Base information that's always present - using fifelse for vectorization
   message("Creating base_info...")
   entry_str <- fifelse(!is.na(entry_price),
             paste0("Entry: ", sprintf("%.2f", entry_price)),
             "Entry: -",
             na = "Entry: -")
   
   current_str <- fifelse(!is.na(close),
             paste0("Current: ", sprintf("%.2f", close)),
             "Current: -",
             na = "Current: -")
   
   base_info <- paste(status, entry_str, current_str, sep = " | ")
   
   # PnL information (only if pnl_pct exists)
   message("Creating pnl_info...")
   pnl_info <- fifelse(!is.na(pnl_pct),
            fifelse(!is.na(take_profit_pct),
                paste0("PnL: ", sprintf("%+.1f%% (Target: %+.1f%%)", pnl_pct, take_profit_pct)),
                paste0("PnL: ", sprintf("%+.1f%%", pnl_pct))),
            "")
   
   # Risk information (only if all components exist)
   message("Creating risk_info...")
   risk_info <- fifelse(!is.na(stop_loss) & !is.na(stop_pct) & !is.na(risk_reward),
             paste0("Stop: ", sprintf("%.2f (%.1f%%) | R:R %.1f", 
                        stop_loss, -stop_pct, risk_reward)),
             "")
   
   # Time information (only if all components exist)
   message("Creating time_info...")
   time_info <- fifelse(!is.na(stage_age) & !is.na(optimal_holding_days) & !is.na(days_remaining),
             paste0("Days: ", sprintf("%d/%d (Remaining: %d)", 
                        stage_age, optimal_holding_days, days_remaining)),
             "")
   
   # Debug intermediate results
   message("Intermediate results - ")
   message("base_info length: ", length(base_info))
   message("pnl_info length: ", length(pnl_info))
   message("risk_info length: ", length(risk_info))
   message("time_info length: ", length(time_info))
   
   # Combine all parts conditionally
   message("Combining results...")
   result <- fifelse(startsWith(status, "NO_ACTION"),
           "NO_ACTION",
           fifelse(nchar(pnl_info) > 0 | nchar(risk_info) > 0 | nchar(time_info) > 0,
               paste(base_info, pnl_info, risk_info, time_info, sep = " | "),
               base_info))
   
   # Clean up any double separators or trailing separators
   message("Cleaning up separators...")
   result <- gsub("\\| \\| ", "| ", result)
   result <- gsub(" \\| $", "", result)
   result <- gsub("^ \\| ", "", result)
   result <- gsub("^\\| ", "", result)
   
   message("Trade summary generation complete")
   return(result)
  })
 }]
 
 # Create trade summary for clear position tracking
 message("Generating trade summaries...")
 
 tryCatch({
  # First, create all the components using data.table operations
  dt[, `:=`(
   # Entry price string
   entry_str = fifelse(!is.na(entry_price) & entry_price > 0,
            paste0("Entry: ", format(round(entry_price, 2), nsmall = 2)),
            "Entry: -",
            na = "Entry: -"),
   
   # Current price string
   current_str = fifelse(!is.na(close) & close > 0,
             paste0("Current: ", format(round(close, 2), nsmall = 2)),
             "Current: -",
             na = "Current: -")
  )]
  
  # PnL information (handled separately to avoid complex nested fifelse)
  dt[, pnl_info := ""]
  if (all(c("pnl_pct", "entry_price", "take_profit_pct") %in% names(dt))) {
   dt[!is.na(pnl_pct) & !is.na(entry_price) & entry_price > 0,
    pnl_info := fifelse(!is.na(take_profit_pct),
              paste0("PnL: ", format(round(pnl_pct, 1), nsmall = 1), "%",
                 " (Target: ", format(round(take_profit_pct, 1), nsmall = 1), "%)"),
              paste0("PnL: ", format(round(pnl_pct, 1), nsmall = 1), "%"))]
  }
  
  # Risk information
  dt[, risk_info := ""]
  if (all(c("stop_loss", "stop_pct", "risk_reward", "entry_price") %in% names(dt))) {
   dt[!is.na(stop_loss) & !is.na(stop_pct) & !is.na(risk_reward) & 
     !is.na(entry_price) & entry_price > 0,
    risk_info := paste0("Stop: ", format(round(stop_loss, 2), nsmall = 2), " (",
              format(round(stop_pct, 1), nsmall = 1), "%) | R:R 1:",
              format(round(risk_reward, 1), nsmall = 1))]
  }
  
  # Stage information
  dt[, stage_info := ""]
  if (all(c("stage_ff", "stage_age", "optimal_holding_days", "days_remaining") %in% names(dt))) {
   dt[!is.na(stage_ff) & !is.na(stage_age) & 
     !is.na(optimal_holding_days) & !is.na(days_remaining),
    stage_info := paste0("Stage ", stage_ff, 
              " (Day ", stage_age, 
              "/", optimal_holding_days, 
              ", ", days_remaining, " left)")]
  }
  
  # Now combine all components
  dt[, trade_summary := paste(na.omit(c(status, entry_str, current_str, pnl_info, risk_info, stage_info)), 
               collapse = " | "), by = 1:nrow(dt)]
  
  # Clean up the combined string
  dt[, trade_summary := gsub("\\| \\| ", "| ", trade_summary)]
  dt[, trade_summary := gsub(" \\| $", "", trade_summary)]
  dt[, trade_summary := gsub("^ \\| ", "", trade_summary)]
  dt[, trade_summary := gsub("^\\| ", "", trade_summary)]
  
 }, error = function(e) {
  warning("Error generating trade summaries: ", e$message)
  dt[, trade_summary := "Error generating trade summary"]
 })
 
 # Clean up temporary columns
 temp_cols <- c("entry_str", "current_str", "pnl_info", "risk_info", "stage_info")
 dt[, c(temp_cols) := NULL]
 
 # Generate final data quality report
 generate_data_quality_summary(dt, "After Trade Summary Generation")
 
 # Add data quality flags
 dt[, `:=`(
  has_missing_prices = fifelse(startsWith(status, "NO_ACTION") & 
                (is.na(entry_price) | is.na(exit_price)), 
               1L, 0L, na = 0L),
  has_invalid_dates = fifelse(startsWith(status, "NO_ACTION") & 
                (is.na(entry_date) | is.na(exit_date)), 
               1L, 0L, na = 0L),
  has_na_pnl = fifelse(startsWith(status, "NO_ACTION") & is.na(pnl_pct), 1L, 0L, na = 0L)
 )]
 
 # Log data quality issues
 data_issues <- dt[, .(
  total_rows = .N,
  missing_prices = sum(has_missing_prices, na.rm = TRUE),
  invalid_dates = sum(has_invalid_dates, na.rm = TRUE),
  na_pnl = sum(has_na_pnl, na.rm = TRUE)
 )]
 
 log_message("\n=== Data Quality Issues ===")
 log_message(sprintf("Rows with missing prices: %d (%.2f%%)", 
          data_issues$missing_prices,
          data_issues$missing_prices / data_issues$total_rows * 100))
 log_message(sprintf("Rows with invalid dates: %d (%.2f%%)",
          data_issues$invalid_dates,
          data_issues$invalid_dates / data_issues$total_rows * 100))
 log_message(sprintf("Rows with NA PnL: %d (%.2f%%)",
          data_issues$na_pnl,
          data_issues$na_pnl / data_issues$total_rows * 100))
 
 
 # Clean up temporary columns
 dt[, `:=`(potential_breakout = NULL, 
      potential_exhaustion = NULL, 
      potential_accumulation = NULL)]
 
 # Log status assignment summary
 status_summary <- dt[, .N, by = status][order(-N)]
 log_message("Status assignment summary:")
 for (i in 1:nrow(status_summary)) {
  pct <- status_summary$N[i] / nrow(dt) * 100
  log_message(sprintf(" - %-20s: %6d (%5.1f%%)", 
           status_summary$status[i], 
           status_summary$N[i],
           pct))
 }
 
 # Add detailed logging of data structure
 log_message("\nData structure details:")
 log_message(sprintf("Total rows: %d", nrow(dt)))
 log_message(sprintf("Number of companies: %d", length(unique(dt$company_id))))
 log_message("\nColumn types and NA counts:")
 
 # Get column info
 col_info <- data.table(
  column = names(dt),
  type = sapply(dt, class),
  na_count = sapply(dt, function(x) sum(is.na(x)))
 )
 
 # Log column info
 for (i in 1:nrow(col_info)) {
  log_message(sprintf(" %-20s %-15s NAs: %d (%.1f%%)", 
           col_info$column[i], 
           paste(col_info$type[[i]], collapse = ","),
           col_info$na_count[i],
           col_info$na_count[i] / nrow(dt) * 100))
 }
 
 # Check for potential issues in key columns
 log_message("\nChecking for potential issues in key columns:")
 
 # Check entry_price
 if (any(is.na(dt$entry_price) & startsWith(dt$status, "NO_ACTION"))) {
  log_message(sprintf(" - Found %d rows with NA entry_price but non-NO_ACTION status",
           sum(is.na(dt$entry_price) & startsWith(dt$status, "NO_ACTION"))))
 }
 
 # Check date columns
 date_cols <- c("entry_date", "exit_date")
 for (col in date_cols) {
  if (any(is.na(dt[[col]]) & startsWith(dt$status, "NO_ACTION"))) {
   log_message(sprintf(" - Found %d rows with NA %s but non-NO_ACTION status",
            sum(is.na(dt[[col]]) & startsWith(dt$status, "NO_ACTION")),
            col))
  }
 }
 
 # Check for any non-finite values in numeric columns
 num_cols <- names(dt)[sapply(dt, is.numeric)]
 for (col in num_cols) {
  if (any(!is.finite(dt[[col]]), na.rm = TRUE)) {
   log_message(sprintf(" - Found %d non-finite values in %s",
            sum(!is.finite(dt[[col]])),
            col))
  }
 }
 
 # Log sample of data for debugging
 log_message("\nSample data for debugging:")
 sample_rows <- dt[sample(.N, min(5, .N))]
 print(sample_rows[, .(company_id, date, status, entry_price, exit_price, pnl_pct
 )])
 
 
 # Add stage name safely
 dt[, stage_name := {
  sapply(stage_ff, function(s) {
   if (is.na(s)) return(NA_character_)
   s_char <- as.character(s)
   if (s_char %in% names(stage_defs_local)) {
    return(stage_defs_local[[s_char]]$name)
   } else {
    log_message(paste0("Warning: No stage definition found for stage: ", s_char))
    return(NA_character_)
   }
  })
 }]
 
 # Create trade log safely
 dt[, trade_log := {
  sn <- sapply(stage_ff, function(s) {
   if (is.na(s)) return(NA_character_)
   s_char <- as.character(s)
   if (s_char %in% names(stage_defs_local)) {
    return(stage_defs_local[[s_char]]$name)
   } else {
    return(NA_character_)
   }
  })
  rs <- ""
  paste0("Stage: ", sn, " | Rules: ", rs)
 }]
 
 # set entry/exit price/date
 dt[startsWith(status, "ENTRY_"), `:=`(entry_price = close, entry_date = as.character(date))]
 dt[startsWith(status, "EXIT_"), `:=`(exit_price = close, exit_date = as.character(date))]
 
 # Handle entry/exit prices and dates with carry forward logic
 # First ensure entry_date and exit_date are Date type
 if (!is.null(dt$entry_date)) dt[, entry_date := as.Date(entry_date)]
 if (!is.null(dt$exit_date)) dt[, exit_date := as.Date(exit_date)]
 
 # Handle numeric columns with nafill
 dt[, `:=`(
  # Carry forward entry price until exit
  entry_price = nafill(as.numeric(entry_price), type = 'locf'),
  # Carry forward exit price if set
  exit_price = nafill(as.numeric(exit_price), type = 'locf')
 ), by = company_id]
 
 # Handle date columns with data.table's shift and fill
 dt[, `:=`(
  entry_date = {
   # Convert to integer for carry forward, then back to Date
   entry_int <- as.integer(entry_date)
   entry_int_filled <- nafill(entry_int, type = 'locf')
   as.Date(entry_int_filled, origin = '1970-01-01')
  },
  exit_date = {
   # Convert to integer for carry forward, then back to Date
   exit_int <- as.integer(exit_date)
   exit_int_filled <- nafill(exit_int, type = 'locf')
   as.Date(exit_int_filled, origin = '1970-01-01')
  }
 ), by = company_id]
 
 # Calculate PnL percentage using vectorized operations
 dt[, pnl_pct := {
  fifelse(!is.na(entry_price),
     fifelse(!is.na(exit_price),
         # For closed positions
         (exit_price - entry_price) / entry_price * 100,
         # For open positions
         (close - entry_price) / entry_price * 100),
     # If entry_price is NA
     NA_real_)
 }]
 
 dt[, stage_ff := NULL]
 return(dt)
}

generate_final_output <- function(dt, companies = NULL) {
 log_message("Generating final output...")
 
 # Retrieve stage_defs from dt attributes
 stage_defs_local <- attr(dt, "scenario_stage_defs")
 if (is.null(stage_defs_local)) {
  log_message("Error: scenario_stage_defs attribute not found on dt. Cannot generate final output.", "ERROR")
  # Attempt to proceed with default names if stage_defs_local is critical
  stage_defs_local <- list(
    `0` = list(name = "SETUP"),
    `1` = list(name = "BREAKOUT"),
    `2` = list(name = "EARLY_MOM"),
    `3` = list(name = "SUSTAINED"),
    `4` = list(name = "EXTENDED"),
    `5` = list(name = "DISTRIBUTION")
  )
 }

 # Ensure all required columns exist in the input data.table
 required_cols <- c("company_id", "stage", "best_partial_stage", "date", "open", "high", 
          "low", "close", "volume", "vol_21d", "vol_63d_avg", "volume_ratio",
          "status", "stage_age", "optimal_holding_days", "days_remaining",
          "entry_price", "entry_date", "exit_price", "exit_date",
          "stop_loss", "stop_pct", "take_profit", "take_profit_pct", "risk_reward",
          "block_trade", "institutional_support", "accumulation_day", "buying_pressure",
          "absorption", "volume_delta", "smart_money_score", "var_1d", 
          "max_drawdown_252d", "sharpe_ratio", "kelly_fraction", "rsi", "adx", "atr",
          "range_contraction", "overextension", "drawdown", "ma_21", "ma_50", "ma_63",
          "ma_126", "ma_252", "high_21d", "low_21d", "vol_factor", "momentum_factor",
          "time_factor", "progress_factor",
          # Dynamic rules need to be included here as well
          grep("^RULE_S", names(dt), value = TRUE),
          "trade_log", "stage_history")
 
 # Initialize missing columns with appropriate defaults
 for (col in required_cols) {
  if (!col %in% names(dt)) {
   if (col %in% c("company_id", "status")) {
    dt[, (col) := as.character(NA)]
   } else if (col %in% c("open", "high", "low", "close", "volume", "vol_21d", "vol_63d_avg", 
             "volume_ratio", "entry_price", "exit_price", "stop_loss", "stop_pct",
             "take_profit", "take_profit_pct", "risk_reward", "buying_pressure",
             "volume_delta", "smart_money_score", "var_1d", "max_drawdown_252d",
             "sharpe_ratio", "kelly_fraction", "rsi", "adx", "atr", "range_contraction",
             "overextension", "drawdown", "ma_21", "ma_50", "ma_63", "ma_126", "ma_252",
             "high_21d", "low_21d", "vol_factor", "momentum_factor", "time_factor",
             "progress_factor", "pnl_pct")) {
    dt[, (col) := as.numeric(NA)]
   } else if (col %in% c("stage", "best_partial_stage", "stage_age", "optimal_holding_days",
             "days_remaining")) {
    dt[, (col) := as.integer(NA)]
   } else if (col %in% c("date", "entry_date", "exit_date")) {
    dt[, (col) := as.Date(NA)]
   } else if (col %in% c("block_trade", "institutional_support", "accumulation_day")) {
    dt[, (col) := 0L] # Initialize as integer with 0 (FALSE)
   } else if (startsWith(col, "RULE_S")) { # Handle dynamically generated rule columns
    dt[, (col) := 0L]
   } else if (col %in% c("trade_log", "stage_history", "risk_category")) {
    dt[, (col) := as.character(NA)]
   } else {
    dt[, (col) := NA] # Generic fallback
   }
   log_message(sprintf(" Initialized missing column: %s as %s", 
            col, class(dt[[col]])[1]), "DEBUG")
  }
 }
 
 # latest row per company (non-NA stage or partial)
 latest <- dt[!is.na(stage) | !is.na(best_partial_stage), .SD[.N], by = company_id]
 
 log_message(sprintf(" Processing %d companies with valid stages", nrow(latest)))
 
 # If companies data is provided and contains ticker column, join it
 if (!is.null(companies) && "ticker" %in% names(companies)) {
  # Ensure companies is a data.table
  if (!is.data.table(companies)) companies <- as.data.table(companies)
  # Join with companies to get ticker and name
  latest <- merge(latest, 
         companies[, .(company_id, ticker, name)], 
         by = "company_id", 
         all.x = TRUE)
 } else if (!"ticker" %in% names(latest)) {
  # If no ticker column, create a dummy one
  latest[, ticker := as.character(company_id)]
  if (!"name" %in% names(latest)) latest[, name := ticker]
 }
 
 # Ensure all required columns exist in the output
 for (col in required_cols) {
  if (!col %in% names(latest)) {
   latest[, (col) := NA]
   log_message(sprintf(" Added missing column to output: %s", col), "DEBUG")
  }
 }
 
 # Build output table with necessary fields
 out <- data.table(
  company_id = latest$company_id,
  ticker = if ("ticker" %in% names(latest)) latest$ticker else as.character(NA),
  name = if ("name" %in% names(latest)) latest$name else as.character(NA),
  date = latest$date,
  open = latest$open,
  high = latest$high,
  low = latest$low,
  close = latest$close,
  volume = latest$volume,
  stage = ifelse(!is.na(latest$stage), latest$stage, latest$best_partial_stage),
  stage_name = {
   sapply(seq_along(latest$stage), function(i) {
    s <- ifelse(!is.na(latest$stage[i]), latest$stage[i], latest$best_partial_stage[i])
    if (is.na(s)) return(NA_character_)
    s_char <- as.character(s)
    if (s_char %in% names(stage_defs_local)) {
     return(stage_defs_local[[s_char]]$name)
    } else {
     return(NA_character_)
    }
   })
  },
  status = latest$status,
  stage_age = latest$stage_age,
  optimal_holding_days = latest$optimal_holding_days,
  days_remaining = latest$days_remaining,
  entry_price = latest$entry_price,
  entry_date = latest$entry_date,
  exit_price = latest$exit_price,
  exit_date = latest$exit_date,
  pnl_pct = latest$pnl_pct,
  stop_loss = latest$stop_loss,
  stop_pct = latest$stop_pct,
  take_profit = latest$take_profit,
  take_profit_pct = latest$take_profit_pct,
  risk_reward = latest$risk_reward,
  vol_21d_avg = latest$vol_21d,
  vol_63d_avg = latest$vol_63d_avg,
  volume_ratio = latest$volume_ratio,
  vol_vs_avg = (latest$volume / (latest$vol_21d + 1e-9) - 1) * 100,
  block_trade = latest$block_trade,
  institutional_support = latest$institutional_support,
  accumulation_day = latest$accumulation_day,
  buying_pressure = latest$buying_pressure,
  absorption = latest$absorption,
  ofi = NA_real_,
  volume_delta = latest$volume_delta,
  hidden_accumulation = NA,
  smart_money_score = latest$smart_money_score,
  risk_score = NA_real_,
  risk_category = NA_character_,
  var_1d = latest$var_1d,
  max_drawdown = ifelse(!is.na(latest$max_drawdown_252d), latest$max_drawdown_252d * 100, NA_real_),
  sharpe_ratio = latest$sharpe_ratio,
  kelly_fraction = latest$kelly_fraction,
  rsi = latest$rsi,
  adx = latest$adx,
  atr = latest$atr,
  vol_21d = ifelse(!is.na(latest$vol_21d), latest$vol_21d * 100, NA_real_),
  range_contraction = ifelse(!is.na(latest$range_contraction), latest$range_contraction * 100, NA_real_),
  overextension = ifelse(!is.na(latest$overextension), latest$overextension * 100, NA_real_),
  drawdown = ifelse(!is.na(latest$drawdown), latest$drawdown * 100, NA_real_),
  ma_21 = latest$ma_21,
  ma_50 = latest$ma_50,
  ma_63 = latest$ma_63,
  ma_126 = latest$ma_126,
  ma_252 = latest$ma_252,
  high_21d = latest$high_21d,
  low_21d = latest$low_21d,
  pct_from_21d_high = ifelse(!is.na(latest$close) & !is.na(latest$high_21d) & latest$high_21d > 0,
               (latest$close / latest$high_21d - 1) * 100, NA_real_),
  pct_from_21d_low = ifelse(!is.na(latest$close) & !is.na(latest$low_21d) & latest$low_21d > 0,
              (latest$close / latest$low_21d - 1) * 100, NA_real_),
  vol_factor = latest$vol_factor,
  momentum_factor = latest$momentum_factor,
  time_factor = latest$time_factor,
  progress_factor = ifelse(!is.na(latest$progress_factor), pmax(0, latest$progress_factor * 100), NA_real_),

  # Stage-specific rules (as integer columns), dynamically picked
  # Only include RULE_S_XX_YY columns that exist in latest
  # This dynamically creates columns for rules materialized in the current scenario
  setNames(lapply(grep("^RULE_S", names(latest), value = TRUE), function(col_name) latest[[col_name]]),
           grep("^RULE_S", names(latest), value = TRUE)),
  trade_log = latest$trade_log,
  stage_history = latest$stage_history
 )
 
 # format trade_summary
 # Safely format trade summary with proper error handling
 out[, trade_summary := {
  tryCatch({
   sprintf("STAGE%d:%s %s @%.2f | DAY:%d/%d | PNL:%.1f%% | R:R %.2f | STOP:%.1f%% | TARGET:%.1f%%",
       stage, stage_name, status, close, stage_age, optimal_holding_days,
       ifelse(is.na(pnl_pct), 0, pnl_pct),
       ifelse(is.na(risk_reward), 0, risk_reward),
       ifelse(is.na(stop_pct), 0, stop_pct),
       ifelse(is.na(take_profit_pct), 0, take_profit_pct))
  }, error = function(e) {
   log_message(sprintf("Error formatting trade summary: %s", e$message), "ERROR")
   return(NA_character_)
  })
 }]
 
 # set order of important columns (removed entry_price and exit_price as they're already in the data.table)
 setcolorder(out, c("ticker", "date", "close", "volume", "status", "stage", "stage_name", "stage_age", "optimal_holding_days",
          "days_remaining", "pnl_pct", "risk_reward", "stop_loss", "stop_pct", "take_profit",
          "take_profit_pct", "smart_money_score", "institutional_support", "accumulation_day",
          "risk_score", "risk_category", "max_drawdown", "sharpe_ratio", "rsi", "adx", "atr", "vol_21d",
          "range_contraction", "trade_summary", "trade_log", "stage_history"))
 return(out)
}

#' Save Results to CSV
#' 
#' Saves the final output data.table to a CSV file in the specified output directory.
#' @param output_dt The data.table to save.
#' @param output_dir The directory where the CSV file will be saved.
#' @param ref_date The reference date, used to name the output file.
#' @return Invisible NULL.
save_results <- function(output_dt, output_dir, ref_date) {
  file_name <- sprintf("momentum_cycle_signals_%s.csv", format(ref_date, "%Y%m%d"))
  file_path <- file.path(output_dir, file_name)
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  fwrite(output_dt, file_path)
  log_message(sprintf("Results saved to: %s", file_path))
}

# ============================================================================
# 4. MAIN EXECUTION - RUN SCENARIOS
# ============================================================================

#' Main Execution Function for Running Scenarios
#' 
#' Orchestrates loading intermediate data and running the momentum signal pipeline
#' for each scenario or a selected scenario.
#' @return Invisible NULL
main_run_scenarios <- function() {
  log_message("Momentum cycle signal generation - Run Scenarios (v2) starting")
  start_time <- Sys.time()
  
  # Debug: Print session info
  log_message("Session Info:")
  log_message(sessionInfo()$R.version$version.string)
  log_message(sprintf("Working directory: %s", getwd()))
  
  # Load the intermediate dataset
  load_file_path <- "data/mmtm_intermediate_data.RData"
  if (!file.exists(load_file_path)) {
    stop(sprintf("Intermediate indicators file not found: %s. Please run mmtm_preparedata.R first.", load_file_path))
  }
  log_message(sprintf("Loading intermediate dataset from %s", load_file_path))
  intermediate_data <- readRDS(file = load_file_path)
  dt_base <- intermediate_data$dt
  companies_base <- intermediate_data$companies
  log_message(sprintf("Intermediate dataset loaded with %d rows and %d columns.", nrow(dt_base), ncol(dt_base)))
  
  # Filter companies (if limit_companies is passed during run_scenario, filter the loaded dt)
  if (!is.null(params$limit_companies)) {
    unique_company_ids <- unique(dt_base$company_id)
    if (length(unique_company_ids) > params$limit_companies) {
      companies_to_keep <- unique_company_ids[1:params$limit_companies]
      dt_base <- dt_base[company_id %in% companies_to_keep]
      companies_base <- companies_base[company_id %in% companies_to_keep]
      log_message(sprintf("Limited loaded data to %d companies for scenario run.", params$limit_companies))
    }
  }
  
  # Ensure rule_sets are loaded
  if (!.rule_sets_available || is.null(rule_sets) || length(rule_sets) == 0) {
    stop("Rule sets not found or rule_sets.R not loaded. Exiting.")
  }
  
  scenarios_to_run <- if (!is.na(selected_rule_set_name)) {
    if (selected_rule_set_name %in% names(rule_sets)) {
      setNames(list(rule_sets[[selected_rule_set_name]]), selected_rule_set_name)
    } else {
      stop(sprintf("Specified scenario '%s' not found in rule_sets.R.", selected_rule_set_name))
    }
  } else {
    log_message(sprintf("No specific scenario provided. Running all %d available scenarios.", length(rule_sets)))
    rule_sets
  }
  
  for (scenario_name in names(scenarios_to_run)) {
    log_message(sprintf("\n--- Processing Scenario: %s ---", scenario_name))
    current_rule_set <- scenarios_to_run[[scenario_name]]
    
    # Create a fresh copy of the base data for each scenario to avoid side effects
    dt_scenario <- copy(dt_base)
    companies_scenario <- copy(companies_base)
    
    tryCatch({
      # 4.1 Data Validation (minimal, as already done in prepare)
      log_message("Validating scenario data structure...")
      required_cols <- c("company_id", "date", "open", "high", "low", "close", "volume")
      missing_cols <- setdiff(required_cols, names(dt_scenario))
      if (length(missing_cols) > 0) {
        log_message(sprintf("Missing required columns in scenario data: %s", paste(missing_cols, collapse = ", ")), "ERROR")
        stop("Scenario data is missing required price/volume columns")
      }
      
      # 4.2 Materialize Rules for the current scenario
      log_message("Step 1/8: Materializing scenario rules...")
      dt_scenario <- timer({ materialize_rule_set(dt_scenario, current_rule_set) }, 
                           sprintf("Materializing Rules for %s", scenario_name))
      
      # 4.3 Evaluate Trading Rules (now just passes through if rules are materialized)
      log_message("Step 2/8: Evaluating trading rules...")
      dt_scenario <- timer({ evaluate_rules(dt_scenario) }, 
                           sprintf("Evaluating Rules for %s", scenario_name))
      
      # 4.4 Assign Stages
      log_message("Step 3/8: Assigning momentum stages...")
      dt_scenario <- timer({ assign_stage(dt_scenario) }, 
                           sprintf("Assigning Stages for %s", scenario_name))
      log_message(sprintf("  Assigned stages. Distribution: %s", 
                          paste(table(dt_scenario$stage, useNA = "ifany"), collapse = ", ")))
      
      # 4.5 Add Stage History
      log_message("Step 4/8: Adding stage history...")
      dt_scenario <- timer({ add_stage_history(dt_scenario) }, 
                           sprintf("Adding Stage History for %s", scenario_name))
      log_message("  Stage history added")
      
      # 4.6 Calculate Dynamic Levels
      log_message("Step 5/8: Calculating dynamic price levels...")
      dt_scenario <- timer({ calculate_dynamic_levels(dt_scenario) }, 
                           sprintf("Calculating Dynamic Levels for %s", scenario_name))
      log_message("  Dynamic levels calculated")
      
      # 4.7 Add Metadata (includes evaluate_partial_signals, status, pnl calc)
      log_message("Step 6/8: Adding metadata and evaluating signals...")
      dt_scenario <- timer({ add_metadata(dt_scenario) }, 
                           sprintf("Adding Metadata for %s", scenario_name))
      log_message("  Metadata and signals evaluated")

      # 4.8 Calculate Stage Scores (dynamically using scenario_stage_defs)
      log_message("Step 7/8: Calculating stage scores...")
      dt_scenario <- timer({ calculate_stage_scores(dt_scenario) }, 
                           sprintf("Calculating Stage Scores for %s", scenario_name))
      log_message("  Stage scores calculated")
      
      # Note: evaluate_partial_signals is now called within add_metadata
      # No need for a separate call here.
      
      # 4.9 Generate Final Output for this scenario
      log_message("Step 8/8: Generating final output for scenario...")
      
      # Determine output directory for this scenario
      scenario_output_dir <- file.path(params$output_dir, "mmtm", scenario_name)
      if (!dir.exists(scenario_output_dir)) {
        dir.create(scenario_output_dir, recursive = TRUE, showWarnings = FALSE)
        log_message(sprintf("Created output directory: %s", scenario_output_dir))
      }
      
      output_scenario <- generate_final_output(dt_scenario, companies_scenario)
      log_message(sprintf("Generated output for scenario %s with %d rows and %d columns", 
                          scenario_name, nrow(output_scenario), ncol(output_scenario)))
      
      # Save results to scenario-specific directory
      save_results(output_scenario, scenario_output_dir, ref_date)
      log_message(sprintf("Results saved for scenario: %s", scenario_name))
      
      # Log completion for this scenario
      elapsed_scenario <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      log_message(sprintf("Scenario %s completed successfully in %.1f seconds", scenario_name, elapsed_scenario))
      
    }, error = function(e) {
      log_message(sprintf("Error processing scenario %s: %s", scenario_name, e$message), "ERROR")
    })
  }
  
  log_message("All scenarios processed. Pipeline execution complete.")
  
  elapsed_total <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 2)
  log_message(paste("Total pipeline execution time:", elapsed_total, "seconds"))
  
  return(invisible(NULL))
}

# ============================================================================
# 5. SCRIPT EXECUTION
# ============================================================================

# 5.1 Main Execution Block
# ----------------------------------------------------------------------------
# Only execute if run as a script (not sourced)
if (identical(environment(), globalenv())) {
  tryCatch({
    # Execute Main Function
    main_run_scenarios()
    
    # Final Status
    log_message("Script completed successfully", "SUCCESS")
  }, error = function(e) {
    error_msg <- if (is.null(e$message)) {
      if (inherits(e, "simpleError")) {
        as.character(e)
      }
    } else {
      e$message
    }
    
    log_message(sprintf("Fatal error in execution: %s", error_msg), "ERROR")
    
    if (exists(".traceback")) {
      log_message("Stack trace:", "ERROR")
      log_message(utils::capture.output(print(.traceback())), "ERROR")
    }
    
    stop(simpleError(error_msg, call = sys.calls()[[1]]))
  })
} 