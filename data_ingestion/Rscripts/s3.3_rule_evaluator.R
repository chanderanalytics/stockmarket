# rule_evaluator.R
# This script contains functions to evaluate trading rules defined in rule_sets.R

#' Evaluate and store individual rule conditions
#'
#' @param dt data.table containing the data
#' @param rule_expr Character string of the rule expression to evaluate
#' @param col_name Name to assign to the resulting column
#' @return data.table with the evaluated rule added as a new column
#' @export
evaluate_individual_rule <- function(dt, rule_expr, col_name) {
  # Skip if column already exists
  if (col_name %in% names(dt)) {
    return(dt)
  }

  normalize_rule_expr <- function(x) {
    x2 <- x
    if (grepl("shift\\(", x2)) {
      x2 <- gsub("shift\\(", "data.table::shift(", x2)
    }
    if (grepl("\\bbetween\\b", x2)) {
      x2 <- gsub("\\b([A-Za-z0-9_\\.]+)\\s+between\\s+([-0-9\\.]+)\\s*&\\s*([-0-9\\.]+)", "(\\1 >= \\2 & \\1 <= \\3)", x2, perl = TRUE)
    }
    if (grepl("\\bwithin\\b", x2)) {
      x2 <- gsub("\\b(.+?)\\s+within\\s+([-0-9\\.]+)\\s+of\\s+(.+)$", "(abs((\\1) - (\\3)) <= (\\2/100) * abs(\\3))", x2, perl = TRUE)
    }
    x2
  }
  
  tryCatch({
    safe_rule_expr <- normalize_rule_expr(rule_expr)

    modified_expr <- safe_rule_expr
    if (grepl('quantile\\s*\\(', modified_expr, fixed = FALSE)) {
      modified_expr <- gsub('quantile\\s*\\(\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)',
                           'quantile(\\1, \\2, na.rm = TRUE)',
                           modified_expr, perl = TRUE)
    }

    group_cols <- character(0)
    if (grepl("data\\.table::shift\\(", modified_expr) || grepl("\\bshift\\(", modified_expr)) {
      group_cols <- c("company_id")
    } else if (grepl("quantile\\s*\\(", modified_expr)) {
      group_cols <- c("date")
    }

    result <- tryCatch({
      if (length(group_cols) == 0) {
        dt[, eval(parse(text = modified_expr))]
      } else {
        dt[, eval(parse(text = modified_expr)), by = group_cols]
      }
    }, error = function(e) {
      warning(sprintf("Error evaluating rule '%s': %s", col_name, e$message))
      data.table::data.table(V1 = rep(NA, nrow(dt)))
    })

    result <- result[[1]]
    
    # Convert to binary (1/0) and handle NAs
    result_binary <- as.integer(as.logical(result))
    result_binary[is.na(result_binary)] <- 0
    
    # Add to the data.table
    dt[, (col_name) := result_binary]
    
    return(dt)
    
  }, error = function(e) {
    warning(sprintf("Error in evaluate_individual_rule for '%s': %s", col_name, e$message))
    dt[, (col_name) := NA_integer_]
    return(dt)
  })
}


#' Evaluate a single rule expression on a data.table
#' 
#' @param dt data.table containing the data
#' @param rule_expr Character string of the rule expression to evaluate
#' @param rule_name Name to assign to the resulting column
#' @return data.table with the evaluated rule added as a new column
#' @export
evaluate_rule <- function(dt, rule_expr, rule_name) {
  tryCatch({
    normalize_rule_expr <- function(x) {
      x2 <- x
      if (grepl("shift\\(", x2)) {
        x2 <- gsub("shift\\(", "data.table::shift(", x2)
      }
      if (grepl("\\bbetween\\b", x2)) {
        x2 <- gsub("\\b([A-Za-z0-9_\\.]+)\\s+between\\s+([-0-9\\.]+)\\s*&\\s*([-0-9\\.]+)", "(\\1 >= \\2 & \\1 <= \\3)", x2, perl = TRUE)
      }
      if (grepl("\\bwithin\\b", x2)) {
        x2 <- gsub("\\b(.+?)\\s+within\\s+([-0-9\\.]+)\\s+of\\s+(.+)$", "(abs((\\1) - (\\3)) <= (\\2/100) * abs(\\3))", x2, perl = TRUE)
      }
      x2
    }

    safe_rule_expr <- normalize_rule_expr(rule_expr)

    # Evaluate the rule expression with proper column context
    tryCatch({
      modified_expr <- safe_rule_expr
      if (grepl('quantile\\s*\\(', modified_expr, fixed = FALSE)) {
        modified_expr <- gsub('quantile\\s*\\(\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)',
                             'quantile(\\1, \\2, na.rm = TRUE)',
                             modified_expr, perl = TRUE)
      }

      group_cols <- character(0)
      if (grepl("data\\.table::shift\\(", modified_expr) || grepl("\\bshift\\(", modified_expr)) {
        group_cols <- c("company_id")
      } else if (grepl("quantile\\s*\\(", modified_expr)) {
        group_cols <- c("date")
      }

      if (length(group_cols) == 0) {
        dt[, (rule_name) := eval(parse(text = modified_expr))]
      } else {
        dt[, (rule_name) := eval(parse(text = modified_expr)), by = group_cols]
      }
    }, error = function(e) {
      # If evaluation fails, set to NA and log warning
      warning(sprintf("Failed to evaluate rule '%s': %s", rule_name, e$message))
      dt[, (rule_name) := NA_integer_]
    })

    # Convert to integer (1 for TRUE, 0 for FALSE, NA otherwise)
    dt[, (rule_name) := as.integer(as.logical(get(rule_name)))]

    # Set up debug log file
    debug_log <- file("rule_evaluation_debug.log", "a")
    on.exit(close(debug_log))
    
    # Log detailed information about the rule evaluation
    writeLines(sprintf("\n[%s] Evaluating rule: %s", Sys.time(), rule_expr), debug_log)
    
    # Show available columns for debugging
    writeLines(sprintf("Available columns in data: %s", 
                      paste(names(dt), collapse=", ")), debug_log)
    
    # Show data types of columns used in the rule
    rule_vars <- tryCatch({
      all.vars(parse(text=rule_expr))
    }, error = function(e) {
      writeLines(sprintf("Error parsing rule: %s", e$message), debug_log)
      character(0)
    })
    
    rule_vars <- rule_vars[rule_vars %in% names(dt)]
    
    if (length(rule_vars) > 0) {
      writeLines(sprintf("Variables used in rule: %s", 
                        paste(rule_vars, collapse=", ")), debug_log)
      
      # Log data types
      writeLines("Data types:", debug_log)
      capture.output(sapply(dt[, ..rule_vars], class), file = debug_log, append = TRUE)
      
      # Log first few values of variables used in the rule
      writeLines("\nFirst 3 rows of relevant data:", debug_log)
      capture.output({
        cat("\n")
        print(head(dt[, .SD, .SDcols = c("date", rule_vars)], 3))
      }, file = debug_log, append = TRUE)
    } else {
      writeLines(sprintf("[WARN] No matching variables found in data for rule: %s", 
                        rule_expr), debug_log)
    }
    
    # Log the result of the rule evaluation
    writeLines("\nRule evaluation results:", debug_log)
    capture.output({
      cat("\n")
      print(head(dt[, .SD, .SDcols = c("date", "close", rule_name)], 5))
    }, file = debug_log, append = TRUE)
    
    # Also print a summary to console
    if (rule_name %in% names(dt)) {
      true_count <- sum(dt[[rule_name]] == 1, na.rm = TRUE)
      false_count <- sum(dt[[rule_name]] == 0, na.rm = TRUE)
      na_count <- sum(is.na(dt[[rule_name]]))
      total <- nrow(dt)
      
      writeLines(sprintf("\nRule evaluation summary for '%s':", rule_expr), debug_log)
      writeLines(sprintf("  TRUE: %d (%.1f%%)", true_count, true_count/total*100), debug_log)
      writeLines(sprintf("  FALSE: %d (%.1f%%)", false_count, false_count/total*100), debug_log)
      writeLines(sprintf("  NA: %d (%.1f%%)", na_count, na_count/total*100), debug_log)
      
      # Print a warning if all values are NA
      if (na_count == total) {
        warning(sprintf("Rule '%s' resulted in all NA values", rule_expr))
      }
    }

    return(dt)
  }, error = function(e) {
    warning(sprintf("Error evaluating rule '%s': %s", rule_name, e$message))
    dt[, (rule_name) := NA_integer_]
    return(dt)
  })
}

#' Evaluate all rules for a specific stage
#' 
#' @param dt data.table containing the data
#' @param stage List containing stage definition (name, rules, optimal_days)
#' @param stage_num Stage number/identifier
#' @return data.table with all rules for the stage evaluated
#' @export
evaluate_stage_rules <- function(dt, stage, rule_prefix = NULL) {
  # Set up debug log file
  debug_log <- file("rule_evaluation_debug.log", "a")
  on.exit(close(debug_log))
  
  # Log the start of stage evaluation
  writeLines(sprintf("\n[%s] ===== Evaluating stage: %s =====", 
                    Sys.time(), 
                    if (!is.null(stage$name)) stage$name else "UNNAMED_STAGE"), 
             debug_log)
  
  # Input validation
  if (!is.data.table(dt)) {
    stop("Input 'dt' must be a data.table")
  }
  if (!is.list(stage) || is.null(stage$rules)) {
    stop("Input 'stage' must be a list with a 'rules' element")
  }
  if (length(stage$rules) == 0) {
    msg <- "No rules defined for this stage"
    writeLines(paste0("[WARN] ", msg), debug_log)
    if (exists("log_message")) {
      log_message(msg, "WARN")
    } else {
      cat(paste0("[WARN] ", msg, "\n"))
    }
    return(dt)
  }
  
  # Debug logging
  stage_name <- if (!is.null(stage$name)) stage$name else "UNNAMED_STAGE"
  if (exists("log_message")) {
    log_message(sprintf("Evaluating stage: %s with %d rules", stage_name, length(stage$rules)))
  } else {
    cat(sprintf("\n[DEBUG] Evaluating stage: %s with %d rules\n", stage_name, length(stage$rules)))
  }
  
  # Make sure stage name is valid
  if (is.null(stage$name) || !is.character(stage$name) || nchar(stage$name) == 0) {
    stage$name <- paste0("STAGE_", rule_prefix)
  }
  
  # Sanitize stage name for column names
  stage_name_clean <- gsub("[^A-Z0-9_]", "", toupper(stage$name))
  
  # Evaluate each rule in the stage
  rule_results <- list()
  for (i in seq_along(stage$rules)) {
    rule_expr <- stage$rules[i]
    if (is.na(rule_expr) || nchar(trimws(rule_expr)) == 0) next
    
    # Use the provided rule_prefix if available, otherwise use stage_name_clean
    rule_name <- if (!is.null(rule_prefix)) {
      paste0(rule_prefix, "_", i)
    } else {
      paste0("RULE_S", stage_name_clean, "_", i)
    }
    
    # Log the rule being evaluated
    writeLines(sprintf("\n[%s] Evaluating rule %d: %s", 
                      Sys.time(), i, rule_expr), 
               debug_log)
    
    tryCatch({
      # Debug log the rule being evaluated
      # Check if this is a pre-calculated column (like "LOW_VOL", "PRICE_BREAKOUT", etc.)
      if (rule_expr %in% names(dt)) {
        # Use the pre-calculated column directly
        dt[, (rule_name) := get(rule_expr)]
        rule_results[[rule_name]] <- rule_name
        
        # Log the use of pre-calculated column
        writeLines(sprintf("Using pre-calculated column: %s", rule_expr), debug_log)
        
        # Calculate statistics for the rule
        true_count <- sum(dt[[rule_name]], na.rm = TRUE)
        total_count <- sum(!is.na(dt[[rule_name]]))
        pct_true <- if (total_count > 0) round(true_count / total_count * 100, 1) else 0
        
        if (exists("log_message")) {
          log_message(sprintf("    Using pre-calculated column: %s (%.1f%% TRUE, %d/%d)", 
                            rule_expr, pct_true, true_count, total_count))
        } else {
          cat(sprintf("    Using pre-calculated column: %s (%.1f%% TRUE, %d/%d)\n", 
                     rule_expr, pct_true, true_count, total_count))
        }
      } else {
        # Check if the rule contains invalid ... usage
        if (grepl("\\.\\.\\.", rule_expr)) {
          msg <- sprintf("Rule %d in stage %s contains '...' which is not supported. Skipping this rule.", 
                        i, if (!is.null(stage$name)) stage$name else "UNNAMED_STAGE")
          writeLines(paste0("[WARN] ", msg), debug_log)
          warning(msg)
          next
        }
        
        # Log the rule evaluation
        writeLines(sprintf("Evaluating rule expression: %s", rule_expr), debug_log)
        
        # Check if all variables in the rule exist in the data
        rule_vars <- all.vars(parse(text=rule_expr))
        missing_vars <- setdiff(rule_vars, names(dt))
        
        if (length(missing_vars) > 0) {
          msg <- sprintf("Missing variables in data for rule '%s': %s", 
                        rule_expr, paste(missing_vars, collapse=", "))
          writeLines(paste0("[ERROR] ", msg), debug_log)
          stop(msg)
        }
        
        # Evaluate the rule as an expression
        writeLines(sprintf("Calling evaluate_rule for: %s", rule_expr), debug_log)
        dt <- evaluate_rule(dt, rule_expr, rule_name)
        
        # Log the result of the rule evaluation
        if (rule_name %in% names(dt)) {
          result_summary <- dt[, .(
            total = .N,
            true = sum(get(rule_name) == 1, na.rm = TRUE),
            false = sum(get(rule_name) == 0, na.rm = TRUE),
            na = sum(is.na(get(rule_name)))
          )]
          
          writeLines(sprintf("Rule evaluation result for '%s':", rule_expr), debug_log)
          writeLines(sprintf("  TRUE: %d (%.1f%%)", 
                           result_summary$true, 
                           result_summary$true / result_summary$total * 100), 
                   debug_log)
          writeLines(sprintf("  FALSE: %d (%.1f%%)", 
                           result_summary$false, 
                           result_summary$false / result_summary$total * 100), 
                   debug_log)
          writeLines(sprintf("  NA: %d (%.1f%%)", 
                           result_summary$na, 
                           result_summary$na / result_summary$total * 100), 
                   debug_log)
        }
        rule_results[[rule_name]] <- rule_name
        
        # Calculate statistics for the rule
        if (rule_name %in% names(dt)) {
          true_count <- sum(dt[[rule_name]] == 1, na.rm = TRUE)
          total_count <- sum(!is.na(dt[[rule_name]]))
          pct_true <- if (total_count > 0) round(true_count / total_count * 100, 1) else 0
          
          if (exists("log_message")) {
            log_message(sprintf("    Rule evaluation: %s = %.1f%% TRUE (%d/%d)", 
                              rule_name, pct_true, true_count, total_count))
          } else {
            cat(sprintf("    Rule evaluation: %s = %.1f%% TRUE (%d/%d)\n", 
                       rule_name, pct_true, true_count, total_count))
          }
        }
      }
    }, error = function(e) {
      warning(sprintf("Error evaluating rule %d in stage %s: %s", i, stage$name, e$message))
    })
  }
  
  # Combine all rules with AND logic
  if (length(rule_results) > 0) {
    # Get the names of all rule result columns
    rule_cols <- names(rule_results)
    
    # Log which rules we're combining
    msg <- sprintf("Combining %d rules with AND logic: %s", 
                  length(rule_cols), paste(rule_cols, collapse = ", "))
    writeLines(msg, debug_log)
    
    if (exists("log_message")) {
      log_message(msg)
    } else {
      cat(paste0(msg, "\n"))
    }
    
    # Create a logical vector indicating which rows match all rules
    writeLines("Creating combined rule result...", debug_log)
    
    # Check for NA values in rule columns
    na_counts <- sapply(rule_cols, function(x) sum(is.na(dt[[x]])))
    if (any(na_counts > 0)) {
      msg <- sprintf("Warning: Found NA values in rule results: %s", 
                    paste(sprintf("%s (%d NAs)", names(na_counts[na_counts > 0]), 
                                na_counts[na_counts > 0]), 
                         collapse = ", "))
      writeLines(paste0("[WARN] ", msg), debug_log)
      warning(msg)
    }
    
    # Combine rules with AND logic, treating NA as FALSE
    dt[, all_rules := Reduce(`&`, lapply(rule_cols, function(x) {
      val <- get(x) == 1
      val[is.na(val)] <- FALSE  # Treat NA as FALSE
      val
    }))]
    
    # Log the combined result
    result_summary <- dt[, .(
      total = .N,
      true = sum(all_rules, na.rm = TRUE),
      false = sum(!all_rules, na.rm = TRUE),
      na = sum(is.na(all_rules))
    )]
    
    writeLines("\nCombined rule evaluation result:", debug_log)
    writeLines(sprintf("  TRUE: %d (%.1f%%)", 
                      result_summary$true, 
                      result_summary$true / result_summary$total * 100), 
              debug_log)
    writeLines(sprintf("  FALSE: %d (%.1f%%)", 
                      result_summary$false, 
                      result_summary$false / result_summary$total * 100), 
              debug_log)
    
    # Log the combined results
    true_count <- sum(dt$all_rules, na.rm = TRUE)
    total_count <- sum(!is.na(dt$all_rules))
    pct_true <- if (total_count > 0) round(true_count / total_count * 100, 1) else 0
    
    if (exists("log_message")) {
      log_message(sprintf("  Combined rules: %.1f%% TRUE (%d/%d) for stage %s", 
                         pct_true, true_count, total_count, stage_name))
    } else {
      cat(sprintf("  Combined rules: %.1f%% TRUE (%d/%d) for stage %s\n", 
                 pct_true, true_count, total_count, stage_name))
    }
    
    # Clean up individual rule columns
    dt[, (rule_cols) := NULL]
    
    return(dt)
  }
  
  # Create stage score column
  score_col <- if (!is.null(rule_prefix)) {
    paste0(rule_prefix, "_score")
  } else {
    paste0("stage_", stage_name_clean, "_score")
  }
  
  dt[, (score_col) := rowSums(.SD, na.rm = TRUE), .SDcols = unlist(rule_results)]
  
  return(dt)
}

#' Evaluate all rules for all stages in a rule set
#' 
#' @param dt data.table containing the data
#' @param rule_set_name Name of the rule set to use (e.g., "momentum_2")
#' @return data.table with all rules and stage scores
#' @export
evaluate_all_rules <- function(dt, rule_set_name = "momentum_2") {
  # Load the rule sets if not already loaded
  if (!exists('rule_sets')) {
    rule_sets <- source('data_ingestion/Rscripts/rule_sets.R')$value
  }
  
  # Get the specified rule set
  rule_set <- rule_sets[[rule_set_name]]
  if (is.null(rule_set)) {
    stop(sprintf("Rule set '%s' not found in rule_sets.R", rule_set_name))
  }
  
  # Evaluate rules for each stage
  for (stage_num in names(rule_set)) {
    stage <- rule_set[[stage_num]]
    dt <- evaluate_stage_rules(dt, stage, stage_num)
  }
  
  # Ensure scores are between 0 and 100
  score_cols <- paste0("stage_", names(rule_set), "_score")
  for (col in score_cols) {
    if (col %in% names(dt)) {
      dt[, (col) := pmin(100, pmax(0, get(col)))]
    }
  }
  
  return(dt)
}


#' Check if a stock is close to a stage (missing only one rule)
#' 
#' @param dt data.table with rule evaluation results
#' @param target_stage Integer (1-6) representing the stage to check
#' @param rule_set_name Name of the rule set to use (e.g., "momentum_2")
#' @param rule_prefix Prefix used for rule column names (e.g., "scenario_momentum_0_stage_1_rules")
#' @return Logical vector indicating if each row is close to the target stage
#' @export
is_close_to_stage <- function(dt, target_stage, rule_set_name = "momentum_2", rule_prefix = NULL) {
  # Load the rule sets if not already loaded
  if (!exists('rule_sets')) {
    rule_sets <- source('data_ingestion/Rscripts/rule_sets.R')$value
  }
  
  # Get the specified rule set
  rule_set <- rule_sets[[rule_set_name]]
  if (is.null(rule_set)) {
    stop(sprintf("Rule set '%s' not found in rule_sets.R", rule_set_name))
  }
  
  # Get the target stage
  stage <- rule_set[[as.character(target_stage)]]
  if (is.null(stage) || length(stage$rules) == 0) {
    return(rep(FALSE, nrow(dt)))
  }
  
  # Get the rule columns for this stage - use new naming convention if rule_prefix provided
  rule_columns <- if (!is.null(rule_prefix)) {
    paste0(rule_prefix, "_", sprintf("%02d", seq_along(stage$rules)))
  } else {
    # Fallback to old naming convention
    paste0("RULE_S", target_stage, "_", sprintf("%02d", seq_along(stage$rules)))
  }
  
  existing_rules <- intersect(rule_columns, names(dt))
  
  if (length(existing_rules) == 0) {
    return(rep(FALSE, nrow(dt)))
  }
  
  # Check if all or all but one rule is met
  rules_met <- rowSums(dt[, ..existing_rules] == 1, na.rm = TRUE)
  total_rules <- length(existing_rules)
  
  return(rules_met >= pmax(1, total_rules - 1))
}

#' Generate trade status (ENTRY, EXIT, HOLD, NO_ACTION) based on stage and conditions
#' 
#' @param dt data.table with price data, stage assignments, and indicators
#' @param scenario_name Name of the scenario (e.g., "momentum_0")
#' @return data.table with updated status column
#' @export
generate_trade_status <- function(dt, scenario_name = "momentum_0") {
  if (!is.data.table(dt)) {
    stop("Input 'dt' must be a data.table")
  }
  
  # Ensure required columns exist
  req_cols <- c("company_id", "date", "close", "stage")
  missing_cols <- setdiff(req_cols, names(dt))
  if (length(missing_cols) > 0) {
    stop(sprintf("Missing required columns: %s", paste(missing_cols, collapse = ", ")))
  }
  
  # Make sure data is ordered by company and date
  setorder(dt, company_id, date)
  
  # Initialize status column if it doesn't exist
  if (!"status" %in% names(dt)) {
    dt[, status := "NO_ACTION"]
  }
  
  # Initialize entry_price and stop_loss if they don't exist
  if (!"entry_price" %in% names(dt)) {
    dt[, entry_price := NA_real_]
  }
  if (!"stop_loss" %in% names(dt)) {
    dt[, stop_loss := close * 0.95]  # Default 5% stop loss
  }
  
  # Load the scenario to get stage names
  if (!exists('rule_sets')) {
    rule_sets <- source('data_ingestion/Rscripts/s3.2_rule_sets.R')$value
  }
  
  # Get the scenario definition
  scenario <- rule_sets[[scenario_name]]
  if (is.null(scenario)) {
    stop(sprintf("Scenario '%s' not found in rule sets", scenario_name))
  }
  
  # Extract stage names from the scenario
  stage_names <- sapply(1:6, function(s) {
    stage_def <- scenario[[as.character(s)]]
    if (is.null(stage_def) || is.null(stage_def$name)) {
      return(paste("STAGE", s))
    }
    return(stage_def$name)
  })
  names(stage_names) <- 1:6
  
  # Initialize entry and exit conditions
  dt[, `:=`(
    is_entry = FALSE,
    is_exit = FALSE
  )]
  
  # Add stage transition tracking columns
  dt[, `:=`(
    prev_stage = data.table::shift(stage, type = "lag"),
    next_stage = data.table::shift(stage, type = "lead"),
    prev_close = data.table::shift(close, type = "lag"),
    is_stage_change = !is.na(stage) & (is.na(data.table::shift(stage, type = "lag")) | stage != data.table::shift(stage, type = "lag"))
  ), by = company_id]
  
  # Process each company separately with progress tracking
  companies <- unique(dt$company_id)
  num_companies <- length(companies)
  
  log_message(sprintf("Processing %d companies...", num_companies))
  
  # Process in chunks to show progress
  chunk_size <- max(1, floor(num_companies / 10))  # Update progress every 10%
  
  for (i in seq_along(companies)) {
    company_id_val <- companies[i]
    
    # Show progress
    if (i %% chunk_size == 0 || i == num_companies) {
      log_message(sprintf("  Processed %d of %d companies (%.1f%%)", 
                         i, num_companies, i/num_companies * 100))
    }
    
    # Process this company's data
    company_rows <- which(dt$company_id == company_id_val)
    
    # Skip if no data for this company
    if (length(company_rows) == 0) next
    
    # Get company data
    company_data <- dt[company_rows]
    
    # Generate entry signals based on stage transitions
    for (s in 1:6) {
      # Get the stage name
      stage_name <- ifelse(s %in% names(stage_names), stage_names[as.character(s)], paste0("STAGE_", s))
      
      # Find rows where stage is s and it's a stage change
      entry_rows <- which(company_data$stage == s & company_data$is_stage_change == TRUE)
      if (length(entry_rows) > 0) {
        # Update status for entries
        set(dt, company_rows[entry_rows], "status", 
            paste0("ENTRY_S", s, "_", gsub(" ", "_", toupper(stage_name))))
            
        # Set entry price and stop loss for new entries
        new_entry_rows <- entry_rows[is.na(company_data$entry_price[entry_rows])]
        if (length(new_entry_rows) > 0) {
          set(dt, company_rows[new_entry_rows], "entry_price", 
              company_data$close[new_entry_rows])
          set(dt, company_rows[new_entry_rows], "stop_loss", 
              company_data$close[new_entry_rows] * 0.95)
        }
      }
    }
    
    # Generate exit signals
    # 1. Exit when price hits stop loss
    stop_loss_rows <- which(!is.na(company_data$entry_price) & 
                            company_data$close <= company_data$stop_loss)
    if (length(stop_loss_rows) > 0) {
      set(dt, company_rows[stop_loss_rows], "status", "EXIT_STOP_LOSS")
      set(dt, company_rows[stop_loss_rows], "is_exit", TRUE)
    }
    
    # 2. Exit when moving to a lower stage
    stage_drop <- !is.na(company_data$stage) & 
                 !is.na(company_data$prev_stage) & 
                 company_data$stage < company_data$prev_stage
    exit_rows <- which(stage_drop & !is.na(company_data$entry_price))
    if (length(exit_rows) > 0) {
      for (j in exit_rows) {
        stage_num <- company_data$stage[j]
        stage_name <- if (stage_num %in% names(stage_names)) {
          gsub(" ", "_", toupper(stage_names[as.character(stage_num)]))
        } else {
          paste0("STAGE_", stage_num)
        }
        set(dt, company_rows[j], "status", 
            paste0("EXIT_STAGE_DROP_S", stage_num, "_", stage_name))
        set(dt, company_rows[j], "is_exit", TRUE)
      }
    }
    
    # 3. Exit when reaching stage 6 (distribution)
    dist_exit_rows <- which(company_data$stage == 6 & 
                           !is.na(company_data$stage) & 
                           !is.na(company_data$entry_price))
    if (length(dist_exit_rows) > 0) {
      set(dt, company_rows[dist_exit_rows], "status", "EXIT_DISTRIBUTION")
      set(dt, company_rows[dist_exit_rows], "is_exit", TRUE)
    }
  }
  
  # Clean up temporary columns
  temp_cols <- c("prev_stage", "next_stage", "prev_close", "is_stage_change", 
                "stage_drop", "is_entry", "is_exit")
  dt[, (temp_cols) := NULL]
  
  return(dt)
}
