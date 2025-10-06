# rule_evaluator.R
# This script contains functions to evaluate trading rules defined in rule_sets.R

#' Evaluate a single rule expression on a data.table
#' 
#' @param dt data.table containing the data
#' @param rule_expr Character string of the rule expression to evaluate
#' @param rule_name Name to assign to the resulting column
#' @return data.table with the evaluated rule added as a new column
#' @export
evaluate_rule <- function(dt, rule_expr, rule_name) {
  tryCatch({
    # Evaluate the rule expression in the data.table environment
    dt[, (rule_name) := as.integer(eval(parse(text = rule_expr), envir = .SD))]
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
evaluate_stage_rules <- function(dt, stage, stage_num) {
  if (is.null(stage$rules) || length(stage$rules) == 0) {
    return(dt)
  }
  
  # Evaluate each rule in the stage
  for (i in seq_along(stage$rules)) {
    rule_expr <- stage$rules[i]
    rule_name <- paste0("RULE_", stage$name, "_", i)
    dt <- evaluate_rule(dt, rule_expr, rule_name)
  }
  
  # Calculate stage score (percentage of rules met)
  rule_columns <- paste0("RULE_", stage$name, "_", seq_along(stage$rules))
  existing_rules <- intersect(rule_columns, names(dt))
  
  if (length(existing_rules) > 0) {
    score_col <- paste0("stage_", stage_num, "_score")
    dt[, (score_col) := rowSums(.SD == 1, na.rm = TRUE) / length(existing_rules) * 100,
       .SDcols = existing_rules]
    dt[is.na(get(score_col)), (score_col) := 0]
  }
  
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
#' @param target_stage Integer (0-5) representing the stage to check
#' @param rule_set_name Name of the rule set to use (e.g., "momentum_2")
#' @return Logical vector indicating if each row is close to the target stage
#' @export
is_close_to_stage <- function(dt, target_stage, rule_set_name = "momentum_2") {
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
  
  # Get the rule columns for this stage
  rule_columns <- paste0("RULE_", stage$name, "_", seq_along(stage$rules))
  existing_rules <- intersect(rule_columns, names(dt))
  
  if (length(existing_rules) == 0) {
    return(rep(FALSE, nrow(dt)))
  }
  
  # Check if all or all but one rule is met
  rules_met <- rowSums(dt[, ..existing_rules] == 1, na.rm = TRUE)
  total_rules <- length(existing_rules)
  
  return(rules_met >= pmax(1, total_rules - 1))
}
