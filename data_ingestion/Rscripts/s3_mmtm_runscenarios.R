#!/usr/bin/env Rscript
# s3_mmtm_runscenarios.R
# Comprehensive momentum scenario analysis using s3.2 rule sets
# This script runs each scenario (momentum_0 to momentum_4) against the prepared data
# and generates output files for s4 to consume

source("data_ingestion/Rscripts/0_setup_renv.R")

# ============================================================================
# 1. SETUP AND LOGGING
# ============================================================================

# Setup logging
log_message <- function(msg, level = "INFO") {
  if (length(msg) > 1) {
    msg <- paste(msg, collapse = " ")
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

# Create log directory and file
if (!dir.exists("log")) {
  dir.create("log", recursive = TRUE)
}

log_file <- file.path("log", sprintf("mmtm_runscenarios_%s.log", 
                                     format(Sys.time(), "%Y%m%d_%H%M%S")))
file.create(log_file)

# ============================================================================
# 2. ARGUMENT PARSING
# ============================================================================

parse_arguments <- function() {
 args <- commandArgs(trailingOnly = TRUE)

 if (any(args %in% c("--help", "-h"))) {
  cat(paste0(
   "Usage: Rscript data_ingestion/Rscripts/s3_mmtm_runscenarios.R <YYYY-MM-DD> [--scenario=momentum_0] [--limit_companies=N] [--execute_next_day]\n\n",
   "Environment defaults (optional):\n",
   "  MMTM_SCENARIO=momentum_0\n",
   "  MMTM_LIMIT_COMPANIES=100\n",
   "  MMTM_EXECUTE_NEXT_DAY=true|false\n"
  ))
  quit(save = "no", status = 0)
 }

 is_truthy <- function(x) {
  tolower(trimws(x)) %in% c("1", "true", "t", "yes", "y")
 }

 env_scenario <- Sys.getenv("MMTM_SCENARIO")
 env_limit <- suppressWarnings(as.integer(Sys.getenv("MMTM_LIMIT_COMPANIES")))
 env_next_day <- Sys.getenv("MMTM_EXECUTE_NEXT_DAY")
 scenario_default <- if (nzchar(env_scenario)) env_scenario else NA_character_
 limit_default <- if (!is.na(env_limit) && env_limit > 0) env_limit else NULL
 next_day_default <- if (nzchar(env_next_day)) is_truthy(env_next_day) else FALSE

 params <- list(
  ref_date = Sys.Date(),
  limit_companies = limit_default,
  scenario = scenario_default,
  execute_next_day = next_day_default
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
 
  # Parse limit_companies if provided
 if (length(args) > 1) {
  limit_arg <- grep("^--limit_companies=", args, value = TRUE)
  if (length(limit_arg) == 1) {
    params$limit_companies <- as.integer(sub("^--limit_companies=", "", limit_arg))
    if (is.na(params$limit_companies) || params$limit_companies <= 0) {
      log_message(sprintf("Invalid limit_companies value: %s. Ignoring limit.", sub("^--limit_companies=", "", limit_arg)), "WARN")
      params$limit_companies <- NULL
    }
  }

  scen_arg <- grep("^--scenario=", args, value = TRUE)
  if (length(scen_arg) == 1) {
    params$scenario <- sub("^--scenario=", "", scen_arg)
  }

  if (any(grepl("^--execute_next_day$", args))) {
    params$execute_next_day <- TRUE
  }
 }
 
 return(params)
}

# ============================================================================
# 3. DATA LOADING
# ============================================================================

load_prepared_data <- function(ref_date, limit_companies = NULL) {
  # Try to load from s2 output first
  data_file <- sprintf("output/mmtm/prepared_data_%s.csv", format(ref_date, "%Y-%m-%d"))
  
  if (file.exists(data_file)) {
    log_message(sprintf("Loading prepared data from: %s", data_file))
    dt <- data.table::fread(data_file)
    
    log_message(sprintf("Loaded %d rows for %d companies", nrow(dt), length(unique(dt$company_id))))
    
    if (!is.null(limit_companies)) {
      log_message(sprintf("Limiting to first %d companies...", limit_companies))
      # Get the first 'limit_companies' unique companies before any processing
      selected_companies <- unique(dt$company_id)[1:min(limit_companies, length(unique(dt$company_id)))]
      # Filter the data to only include these companies
      dt <- dt[company_id %in% selected_companies]
      log_message(sprintf("Limited to %d rows for %d companies", 
                        nrow(dt), 
                        length(selected_companies)))
    }
    
    log_message(sprintf("Loaded %d rows for %d companies", nrow(dt), length(unique(dt$company_id))))
    return(dt)
  } else {
    stop(sprintf("Prepared data file not found: %s. Please run s2_mmtm_preparedata.R first.", data_file))
  }
}

# ============================================================================
# 4. LOAD MODULES
# ============================================================================


# Load the rule evaluator module (s3.3)
source("data_ingestion/Rscripts/s3.3_rule_evaluator.R")

# ============================================================================
# 5. RULE EVALUATION (using s3.3 module)
# ============================================================================

evaluate_rules <- function(dt) {
  log_message("Evaluating trading rules using pre-calculated columns...")
  
  # Use s3.3 to evaluate base rules for standard momentum cycle
  # We'll use momentum_0 as the base scenario for standard rule evaluation
  if ("momentum_0" %in% names(rule_sets)) {
    base_rule_set <- rule_sets[["momentum_0"]]
    
    # Evaluate all stages in the base rule set to create standard rule columns
    for (stage_num in names(base_rule_set)) {
      stage_def <- base_rule_set[[stage_num]]
      stage_name <- stage_def$name
      
      log_message(sprintf("Evaluating base rules for stage %s: %s", stage_num, stage_name))
      
      # Use s3.3 rule evaluator to evaluate this stage's rules
   tryCatch({
        dt <- evaluate_stage_rules(dt, stage_def, paste0("base_", stage_name, "_rules"))
        log_message(sprintf("  Successfully evaluated %d rules for stage %s", length(stage_def$rules), stage_name))
   }, error = function(e) {
        log_message(sprintf("  Error evaluating rules for stage %s: %s", stage_name, e$message), "WARN")
   })
    }
 } else {
    log_message("No momentum_0 scenario found in s3.2 rule sets for base rule evaluation", "WARN")
  }
  
  log_message("Trading rules evaluated successfully using s3.3 module")
 return(dt)
}
# ============================================================================
# 6. STAGE ASSIGNMENT (using s3.2 rule sets)
# ============================================================================

assign_stage <- function(dt) {
  log_message("Legacy assign_stage function - no longer needed in scenario-based processing")
  log_message("Use assign_stage_scenario() for scenario-specific stage assignment instead")
  return(dt)
}

# ============================================================================
# 7. STAGE HISTORY (from 9_mmtm_oldversion.R)
# ============================================================================

add_stage_history <- function(dt) {
  log_message("Adding stage history...")
  
  setorder(dt, company_id, date)

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
    
    # Create stage names mapping from s3.2 rule sets
    stage_names <- c()
    if ("momentum_0" %in% names(rule_sets)) {
      base_rule_set <- rule_sets[["momentum_0"]]
      for (stage_num in names(base_rule_set)) {
        stage_names[stage_num] <- base_rule_set[[stage_num]]$name
      }
    }
    
    # Format each stage change
    stage_strings <- mapply(
      function(s, d) {
        stage_name <- stage_names[as.character(s)]
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
  
  log_message("Stage history added successfully")
  return(dt)
}

# ============================================================================
# 8. DYNAMIC LEVELS (from 9_mmtm_oldversion.R)
# ============================================================================

calculate_dynamic_levels <- function(dt) {
 log_message("Calculating dynamic price levels...")
 
  t0 <- Sys.time()
  setorder(dt, company_id, date)
  log_message(sprintf("Dynamic levels: rows=%d companies=%d", nrow(dt), uniqueN(dt$company_id)), "DEBUG")
 
  stage_group_col <- if ("stage_group" %in% names(dt)) "stage_group" else ".stage_group_tmp"
  if (stage_group_col == ".stage_group_tmp") {
    dt[, (stage_group_col) := rleid(stage_ff), by = company_id]
  }
 
  # Legacy-style dynamic levels (from 9_mmtm_oldversion.R), applied on stage_ff (0..5)
  dt[, `:=`(
    swing_low_5d = tryCatch({
      frollapply(low, 5, min, align = "right", fill = NA)
    }, error = function(e) rep(NA_real_, .N)),
    swing_low_10d = tryCatch({
      frollapply(low, 10, min, align = "right", fill = NA)
    }, error = function(e) rep(NA_real_, .N)),
    swing_high_5d = tryCatch({
      frollapply(high, 5, max, align = "right", fill = NA)
    }, error = function(e) rep(NA_real_, .N))
  ), by = company_id]
  log_message(sprintf("Dynamic levels: swings done in %.2fs", as.numeric(difftime(Sys.time(), t0, units = "secs"))), "DEBUG")

  dt[, base_stop_pct := {
    fifelse(
      is.na(stage_ff), 2.0,
      fcase(
        stage_ff == 0, 1.5,
        stage_ff == 1, 2.0,
        stage_ff == 2, 2.5,
        stage_ff == 3, 3.0,
        stage_ff == 4, 1.0,
        default = 2.0
      )
    )
  }]
  log_message(sprintf("Dynamic levels: base_stop_pct done in %.2fs", as.numeric(difftime(Sys.time(), t0, units = "secs"))), "DEBUG")

  # Calculate atr_pct first
  dt[, atr_pct := atr / close, by = company_id]
  
  dt[, `:=`(
    stage_age = seq_len(.N),
    time_factor = pmax(0.5, 1 - (seq_len(.N) / pmax(fifelse(is.na(optimal_holding_days), 1, optimal_holding_days), 1)) * 0.5),
    vol_factor = pmin(pmax(vol_21d, 0.001, na.rm = TRUE) / 0.20, 1.5, na.rm = TRUE),
    momentum_factor = 1 + pmin(pmax(return_21d * 10, 0, na.rm = TRUE), 1, na.rm = TRUE),
    # ATR volatility classification as character column
    vol_category = as.character(fcase(
      atr_pct <= 0.03, "lt3",
      atr_pct <= 0.05, "3-5", 
      atr_pct <= 0.10, "5-10",
      default = "gt10"
    ))
  ), by = .(company_id, get(stage_group_col))]
  log_message(sprintf("Dynamic levels: factors done in %.2fs", as.numeric(difftime(Sys.time(), t0, units = "secs"))), "DEBUG")

  dt[, base_stop := {
    tryCatch({
      close - (atr * base_stop_pct * time_factor * vol_factor * pmax(momentum_factor, 0.5))
    }, error = function(e) close * 0.9)
  }]

  dt[, stop_loss := base_stop]
 
  dt[stage_ff == 0 & !is.na(swing_low_5d), stop_loss := pmax(base_stop, swing_low_5d * 0.99, na.rm = TRUE)]
  dt[stage_ff == 1 & !is.na(swing_low_5d), stop_loss := pmax(base_stop, swing_low_5d * 0.98, na.rm = TRUE)]
  dt[stage_ff == 2 & !is.na(ma_21), stop_loss := pmax(base_stop, ma_21 * 0.97, na.rm = TRUE)]
  log_message(sprintf("Dynamic levels: initial stop_loss rules done in %.2fs", as.numeric(difftime(Sys.time(), t0, units = "secs"))), "DEBUG")

  dt[stage_ff == 3, stop_loss := {
    tryCatch({
      ma_stop <- ma_50 * 0.95
      swing_stop <- swing_low_10d * 0.95
      pmax(base_stop, ma_stop, swing_stop, na.rm = TRUE)
    }, error = function(e) base_stop)
  }]

  dt[, stop_loss := {
    tryCatch({
      cummax(nafill(stop_loss, type = "locf"))
    }, error = function(e) stop_loss)
  }, by = .(company_id, get(stage_group_col))]
  log_message(sprintf("Dynamic levels: trailing stop done in %.2fs", as.numeric(difftime(Sys.time(), t0, units = "secs"))), "DEBUG")

  dt[, stop_pct := tryCatch({
    ((close - stop_loss) / close) * 100
  }, error = function(e) rep(NA_real_, .N))]

  # Remove 1% cap to allow proper ATR-based stop losses

  dt[, take_profit := {
    tryCatch({
      close + (close - stop_loss) * 2
    }, error = function(e) close * 1.1)
  }]
  dt[, take_profit_pct := ((take_profit - close) / close) * 100]

  dt[, risk_reward := {
    tryCatch({
      risk <- close - stop_loss
      reward <- take_profit - close
      ifelse(abs(risk) < 1e-6, NA_real_, reward / risk)
    }, error = function(e) rep(NA_real_, .N))
  }]

  if (stage_group_col == ".stage_group_tmp") {
    dt[, (stage_group_col) := NULL]
  }
 
  log_message("Dynamic levels calculated successfully")
  return(dt)
}

add_metadata_legacy <- function(dt, stage_defs) {
  setorder(dt, company_id, date)

  if (!is.list(stage_defs)) {
    stop(sprintf("stage_defs must be a list; got type=%s class=%s", typeof(stage_defs), paste(class(stage_defs), collapse = ",")))
  }

  dt[, stage_ff := {
    if (.N > 0) nafill(stage_ff, type = "locf") else NA_integer_
  }, by = company_id]

  dt[, stage_change := {
    prev_stage <- data.table::shift(stage_ff, 1, type = "lag")
    !is.na(stage_ff) & (is.na(prev_stage) | stage_ff != prev_stage)
  }, by = company_id]

  dt[, stage_group := rleid(stage_ff), by = company_id]

  dt[, stage_age := {
    rl <- rleid(stage_ff)
    unlist(by(rl, company_id, function(x) {
      if (length(x) == 0) return(rep(NA_integer_, length(x)))
      r <- rle(x)
      sequence(r$lengths)
    }, simplify = FALSE))
  }]

  dt[, optimal_holding_days := {
    sapply(stage_ff, function(s) {
      if (is.na(s)) return(NA_integer_)
      s_char <- as.character(s)
      if (s_char %in% names(stage_defs)) stage_defs[[s_char]]$optimal_days else NA_integer_
    })
  }]

  dt[, days_remaining := {
    if (all(is.na(optimal_holding_days))) rep(NA_integer_, .N) else pmax(0, optimal_holding_days - stage_age + 1, na.rm = TRUE)
  }]

  dt[, progress_factor := pmin((close / data.table::shift(close, 21) - 1) / 0.2, 1)]

  trade_cols <- c("entry_price", "exit_price", "entry_date", "exit_date", "pnl_pct")
  for (col in trade_cols) {
    if (!col %in% names(dt)) {
      if (col %in% c("entry_date", "exit_date")) {
        dt[, (col) := as.character(NA)]
      } else {
        dt[, (col) := NA_real_]
      }
    }
  }

  dt[, is_entry := (!is.na(stage_ff) & stage_change == TRUE)]
  dt[, is_exit := (data.table::shift(stage_change, type = "lead") == TRUE) |
    (stage_age >= optimal_holding_days & !is.na(optimal_holding_days)), by = company_id]

  dt
}

generate_trade_status_legacy <- function(dt, stage_defs, execute_next_day = FALSE) {
  setorder(dt, company_id, date)

  if (!is.list(stage_defs)) {
    stop(sprintf("stage_defs must be a list; got type=%s class=%s", typeof(stage_defs), paste(class(stage_defs), collapse = ",")))
  }

  req_cols <- c("company_id", "date", "close", "stage_ff", "stop_loss", "stop_pct", "is_entry", "optimal_holding_days")
  missing_cols <- setdiff(req_cols, names(dt))
  if (length(missing_cols) > 0) {
    stop(sprintf("generate_trade_status_legacy missing required columns: %s", paste(missing_cols, collapse = ", ")))
  }

  log_message(sprintf("generate_trade_status_legacy(): stage_defs type=%s class=%s names=%s",
                      typeof(stage_defs),
                      paste(class(stage_defs), collapse = ","),
                      paste(names(stage_defs), collapse = ",")), "DEBUG")

  stage_targets <- data.table(
    stage_ff = 0:5,
    min_return_pct = c(0, 5, 10, 15, 20, 0),
    max_return_pct = c(0, 15, 25, 30, 40, 0)
  )

  if (!"status" %in% names(dt)) dt[, status := "NO_ACTION"]
  if (!"exit_reason" %in% names(dt)) dt[, exit_reason := NA_character_]
  if (!"trade_active" %in% names(dt)) dt[, trade_active := FALSE]

  stage_names <- vapply(0:5, function(s) {
    s_char <- as.character(s)
    if (s_char %in% names(stage_defs) && is.list(stage_defs[[s_char]]) && !is.null(stage_defs[[s_char]]$name)) {
      stage_defs[[s_char]]$name
    } else {
      "UNKNOWN_STAGE"
    }
  }, character(1))
  entry_status_by_stage <- paste0("ENTRY_S", 1:6, "_", stage_names)
  hold_status_by_stage <- paste0("HOLD_S", 1:6, "_", stage_names)
  exit_status_by_stage <- paste0("EXIT_S", 1:6, "_", stage_names)

  min_ret_by_stage <- c(0, 5, 10, 15, 20, 0)
  max_ret_by_stage <- c(0, 15, 25, 30, 40, 0)

  close_vec <- dt[["close"]]
  date_vec <- dt[["date"]]
  stage_ff_vec <- dt[["stage_ff"]]
  stop_loss_vec <- dt[["stop_loss"]]
  stop_pct_vec <- dt[["stop_pct"]]
  is_entry_vec <- dt[["is_entry"]]
  optimal_days_vec <- dt[["optimal_holding_days"]]
  open_vec <- if ("open" %in% names(dt)) dt[["open"]] else NULL

  row_trycatch <- {
    v <- tolower(trimws(Sys.getenv("MMTM_ROW_TRYCATCH", "FALSE")))
    v %in% c("1", "true", "t", "yes", "y")
  }

  companies <- unique(dt$company_id)
  t_all <- Sys.time()
  log_message(sprintf("generate_trade_status_legacy(): companies=%d rows=%d row_trycatch=%s execute_next_day=%s",
                      length(companies), nrow(dt), row_trycatch, isTRUE(execute_next_day)), "INFO")
  cid_i <- 0L
  for (cid in companies) {
    cid_i <- cid_i + 1L
    if (cid_i %% 10L == 1L) {
      log_message(sprintf("generate_trade_status_legacy(): processing company %d/%d (cid=%s)", cid_i, length(companies), as.character(cid)), "INFO")
    }
    t_cid <- Sys.time()
    idx <- which(dt$company_id == cid)
    if (length(idx) == 0) next

    in_pos <- FALSE
    entry_px <- NA_real_
    entry_dt <- as.Date(NA)
    entry_stage <- NA_integer_

    pending_entry <- FALSE
    pending_entry_stage <- NA_integer_
    pending_entry_stage_name <- NA_character_

    pending_exit <- FALSE
    pending_exit_stage <- NA_integer_
    pending_exit_stage_name <- NA_character_
    pending_exit_reason <- NA_character_

    get_exec_price <- function(row_k) {
      if (!is.null(open_vec) && !is.na(open_vec[row_k])) return(open_vec[row_k])
      close_vec[row_k]
    }

    status_loc <- dt[["status"]][idx]
    entry_price_loc <- dt[["entry_price"]][idx]
    entry_date_loc <- dt[["entry_date"]][idx]
    exit_price_loc <- dt[["exit_price"]][idx]
    exit_date_loc <- dt[["exit_date"]][idx]
    pnl_pct_loc <- dt[["pnl_pct"]][idx]
    trade_active_loc <- dt[["trade_active"]][idx]
    exit_reason_loc <- dt[["exit_reason"]][idx]

    step <- "start"
    k_last <- NA_integer_

    process_k <- function(k, p, prev_k) {
      k_last <<- k

      step <<- "start"
      s <- stage_ff_vec[k]
      if (is.na(s)) {
        status_loc[p] <<- "NO_ACTION"
        return(invisible(NULL))
      }
      s0 <- as.integer(s)
      s1 <- s0 + 1L

      step <<- "stop_pct"
      stop_pct_val <- stop_pct_vec[k]

      step <<- "pending_entry_check"
      if (isTRUE(execute_next_day) && isTRUE(pending_entry)) {
        exec_px <- get_exec_price(k)
        in_pos <<- TRUE
        entry_px <<- exec_px
        entry_dt <<- date_vec[k]
        entry_stage <<- pending_entry_stage

        status_loc[p] <<- entry_status_by_stage[as.integer(pending_entry_stage) + 1L]
        entry_price_loc[p] <<- entry_px
        entry_date_loc[p] <<- as.character(entry_dt)
        trade_active_loc[p] <<- TRUE
        pnl_pct_loc[p] <<- 0

        pending_entry <<- FALSE
        pending_entry_stage <<- NA_integer_
        pending_entry_stage_name <<- NA_character_
        return(invisible(NULL))
      }

      step <<- "pending_exit_check"
      if (isTRUE(execute_next_day) && isTRUE(pending_exit) && isTRUE(in_pos)) {
        exec_px <- get_exec_price(k)
        entry_price_loc[p] <<- entry_px
        entry_date_loc[p] <<- as.character(entry_dt)
        trade_active_loc[p] <<- FALSE
        pnl_pct_loc[p] <<- (exec_px / entry_px - 1) * 100

        status_loc[p] <<- exit_status_by_stage[as.integer(pending_exit_stage) + 1L]
        exit_price_loc[p] <<- exec_px
        exit_date_loc[p] <<- as.character(date_vec[k])
        exit_reason_loc[p] <<- pending_exit_reason

        in_pos <<- FALSE
        entry_px <<- NA_real_
        entry_dt <<- as.Date(NA)
        entry_stage <<- NA_integer_

        pending_exit <<- FALSE
        pending_exit_stage <<- NA_integer_
        pending_exit_stage_name <<- NA_character_
        pending_exit_reason <<- NA_character_
        return(invisible(NULL))
      }

      step <<- "entry_ok"
      entry_ok <- (!is.na(is_entry_vec[k]) && is_entry_vec[k] == TRUE) &
        (s0 %in% c(0L, 1L, 2L, 3L)) &
        (close_vec[k] > stop_loss_vec[k]) &
        (!is.na(stop_pct_val) && stop_pct_val <= 10 && stop_pct_val >= 1)

      if (!isTRUE(in_pos) && isTRUE(entry_ok)) {
        step <<- "entry_exec"
        if (isTRUE(execute_next_day)) {
          pending_entry <<- TRUE
          pending_entry_stage <<- s0
          pending_entry_stage_name <<- stage_names[s1]
          return(invisible(NULL))
        }

        in_pos <<- TRUE
        entry_px <<- close_vec[k]
        entry_dt <<- date_vec[k]
        entry_stage <<- s0

        status_loc[p] <<- entry_status_by_stage[s1]
        entry_price_loc[p] <<- entry_px
        entry_date_loc[p] <<- as.character(entry_dt)
        trade_active_loc[p] <<- TRUE
        pnl_pct_loc[p] <<- 0
        return(invisible(NULL))
      }

      if (isTRUE(in_pos)) {
        step <<- "in_pos_update"
        entry_price_loc[p] <<- entry_px
        entry_date_loc[p] <<- as.character(entry_dt)
        trade_active_loc[p] <<- TRUE
        pnl_pct_loc[p] <<- (close_vec[k] / entry_px - 1) * 100

        current_return <- pnl_pct_loc[p]
        days_in_position <- as.numeric(difftime(date_vec[k], entry_dt, units = "days"))

        step <<- "exit_rules"
        min_ret <- min_ret_by_stage[s1]
        max_ret <- max_ret_by_stage[s1]

        exit_hit_stop <- !is.na(stop_loss_vec[k]) && close_vec[k] <= stop_loss_vec[k]
        exit_distribution <- s0 == 5L
        exit_topping <- (s0 == 4L) && !is.na(prev_k) && !is.na(close_vec[prev_k]) && close_vec[k] < close_vec[prev_k]
        exit_max_target <- is.finite(max_ret) && !is.na(current_return) && current_return >= max_ret
        exit_optimal <- !is.na(optimal_days_vec[k]) && !is.na(days_in_position) && !is.na(min_ret) &&
          (days_in_position >= optimal_days_vec[k]) && (current_return >= min_ret)

        exit_now <- isTRUE(exit_hit_stop) || isTRUE(exit_distribution) || isTRUE(exit_topping) || isTRUE(exit_max_target) || isTRUE(exit_optimal)
        if (exit_now) {
          if (isTRUE(execute_next_day)) {
            pending_exit <<- TRUE
            pending_exit_stage <<- s0
            pending_exit_stage_name <<- stage_names[s1]
            pending_exit_reason <<- if (exit_hit_stop) "STOP_LOSS" else if (exit_distribution) "DISTRIBUTION" else if (exit_topping) "TOPPING" else if (exit_max_target) "MAX_TARGET" else "OPTIMAL"
            status_loc[p] <<- hold_status_by_stage[s1]
            return(invisible(NULL))
          }

          status_loc[p] <<- exit_status_by_stage[s1]
          exit_price_loc[p] <<- close_vec[k]
          exit_date_loc[p] <<- as.character(date_vec[k])
          trade_active_loc[p] <<- FALSE
          exit_reason_loc[p] <<- if (exit_hit_stop) "STOP_LOSS" else if (exit_distribution) "DISTRIBUTION" else if (exit_topping) "TOPPING" else if (exit_max_target) "MAX_TARGET" else "OPTIMAL"

          in_pos <<- FALSE
          entry_px <<- NA_real_
          entry_dt <<- as.Date(NA)
          entry_stage <<- NA_integer_
          return(invisible(NULL))
        }

        status_loc[p] <<- hold_status_by_stage[s1]
      }

      invisible(NULL)
    }

    if (isTRUE(row_trycatch)) {
      for (p in seq_along(idx)) {
        k <- idx[p]
        prev_k <- if (p > 1) idx[p - 1] else NA_integer_
        tryCatch({
          process_k(k, p, prev_k)
        }, error = function(e) {
          log_message(sprintf(
            "Error in generate_trade_status_legacy: cid=%s row=%d date=%s stage_ff=%s\nError step: %s\nError: %s\nError call: %s\nTrace tail:\n%s",
            as.character(cid),
            k_last,
            as.character(date_vec[k_last]),
            as.character(stage_ff_vec[k_last]),
            as.character(step),
            conditionMessage(e),
            if (!is.null(e$call)) paste(deparse(e$call), collapse = " ") else "<no call>",
            paste(utils::tail(capture.output(sys.calls()), 8), collapse = "\n")
          ), "ERROR")
          stop(e)
        })
      }
    } else {
      tryCatch({
        for (p in seq_along(idx)) {
          k <- idx[p]
          prev_k <- if (p > 1) idx[p - 1] else NA_integer_
          process_k(k, p, prev_k)
        }
      }, error = function(e) {
        log_message(sprintf(
          "Error in generate_trade_status_legacy (company-level): cid=%s last_row=%s last_date=%s last_stage_ff=%s\nError step: %s\nError: %s\nError call: %s",
          as.character(cid),
          as.character(k_last),
          if (!is.na(k_last)) as.character(date_vec[k_last]) else NA_character_,
          if (!is.na(k_last)) as.character(stage_ff_vec[k_last]) else NA_character_,
          as.character(step),
          conditionMessage(e),
          if (!is.null(e$call)) paste(deparse(e$call), collapse = " ") else "<no call>"
        ), "ERROR")
        stop(e)
      })
    }

    dt[idx, `:=`(
      status = status_loc,
      entry_price = entry_price_loc,
      entry_date = entry_date_loc,
      exit_price = exit_price_loc,
      exit_date = exit_date_loc,
      pnl_pct = pnl_pct_loc,
      trade_active = trade_active_loc,
      exit_reason = exit_reason_loc
    )]

    if (cid_i %% 10L == 0L) {
      log_message(sprintf("generate_trade_status_legacy(): processed %d/%d companies; last_batch_seconds=%.2f; total_seconds=%.2f",
                          cid_i,
                          length(companies),
                          as.numeric(difftime(Sys.time(), t_cid, units = "secs")),
                          as.numeric(difftime(Sys.time(), t_all, units = "secs"))), "INFO")
    }
  }

  dt
}

# ============================================================================
# 8. METADATA AND TRADE TRACKING (from 9_mmtm_oldversion.R)
# ============================================================================

add_metadata <- function(dt) {
  log_message("Adding metadata...")
  
  # Add stage names from s3.2 rule sets (dynamic scenario detection)
  dt[, stage_name := {
    # Find first available scenario for stage naming
    stage_scenarios <- names(rule_sets)  # Use ALL scenarios, not just 0-4
    base_scenario <- if (length(stage_scenarios) > 0) stage_scenarios[1] else NULL

    # Safe access with multiple checks
    ifelse(is.na(stage), "NO_STAGE",
      ifelse(!is.null(base_scenario) & !is.na(stage),
        ifelse(as.character(stage) %in% names(rule_sets[[base_scenario]]),
          tryCatch(rule_sets[[base_scenario]][[as.character(stage)]]$name, error = function(e) paste("Stage", stage)),
          paste("Stage", stage)
        ),
        paste("Stage", stage)
      )
    )
  }]

  # Only set status to NO_ACTION if it's not already set by generate_trade_status
  if (!"status" %in% names(dt)) {
    dt[, status := "NO_ACTION"]
  } else {
    # Replace any NA status with NO_ACTION
    dt[is.na(status), status := "NO_ACTION"]
  }
  
  # Add trade tracking columns if they don't exist
  if (!"entry_price" %in% names(dt)) dt[, entry_price := NA_real_]
  if (!"entry_date" %in% names(dt)) dt[, entry_date := NA_character_]
  if (!"exit_price" %in% names(dt)) dt[, exit_price := NA_real_]
  if (!"exit_date" %in% names(dt)) dt[, exit_date := NA_character_]
  if (!"exit_reason" %in% names(dt)) dt[, exit_reason := NA_character_]
  if (!"trade_active" %in% names(dt)) dt[, trade_active := FALSE]
  if (!"stop_loss" %in% names(dt)) dt[, stop_loss := close * 0.95]  # Default 5% stop loss
  
  log_message("Metadata added successfully")
  return(dt)
}

# ============================================================================
# 9. SCENARIO PROCESSING
# ============================================================================

# Load rule sets
source("data_ingestion/Rscripts/s3.2_rule_sets.R")

get_scenario_num <- function(scenario_name) {
  m <- regmatches(scenario_name, regexec("^momentum_([0-9]+)$", scenario_name))[[1]]
  if (length(m) == 2) {
    return(as.integer(m[2]))
  }
  return(NA_integer_)
}

make_rule_slug <- function(rule_expr, max_len = 50) {
  slug <- tolower(rule_expr)
  slug <- gsub("data\\.table::", "", slug)
  slug <- gsub("\\s+", "_", slug)
  slug <- gsub("[^a-z0-9_]+", "_", slug)
  slug <- gsub("_+", "_", slug)
  slug <- gsub("^_+|_+$", "", slug)
  if (nchar(slug) == 0) slug <- "rule"
  substr(slug, 1, max_len)
}

get_custom_rule_name <- function(scenario_name, stage_num, rule_index) {
  NULL
}

make_rule_col_name <- function(scenario_name, stage_num, rule_index, rule_expr) {
  custom <- get_custom_rule_name(scenario_name, stage_num, rule_index)
  if (!is.null(custom)) return(custom)

  scen_num <- get_scenario_num(scenario_name)
  if (is.na(scen_num)) {
    stop(sprintf("Unsupported scenario_name format for dynamic rule columns: %s", scenario_name))
  }

  slug <- make_rule_slug(rule_expr)
  paste0("m", scen_num, "_s", as.integer(stage_num), "_r", as.integer(rule_index), "_", slug)
}

# Function to evaluate rules for a scenario using s3.3 module
evaluate_scenario_rules <- function(dt, scenario_name, rule_set, execute_next_day = FALSE) {
  log_message(sprintf("Evaluating scenario: %s with individual rule tracking", scenario_name))
  
  # Create a copy of the data
  result_dt <- copy(dt)

  for (stage_num in names(rule_set)) {
    stage_def <- rule_set[[stage_num]]
    if (is.null(stage_def) || !is.list(stage_def) || is.null(stage_def$rules)) next
    if (length(stage_def$rules) == 0) next

    for (i in seq_along(stage_def$rules)) {
      rule_expr <- stage_def$rules[[i]]
      if (is.na(rule_expr) || nchar(trimws(rule_expr)) == 0) next
      col_name <- make_rule_col_name(scenario_name, stage_num, i, rule_expr)
      result_dt <- evaluate_rule(result_dt, rule_expr, col_name)
    }
  }
  
  # Initialize status column if it doesn't exist
  if (!"status" %in% names(result_dt)) {
    result_dt[, status := NA_character_]
  }
  
  # Initialize stage and status columns
  result_dt[, stage := NA_integer_]
  result_dt[, status := NA_character_]
  result_dt[, scenario := scenario_name]
  
  # Process each stage in the rule set (1-6)
  for (stage_num in 1:6) {
    stage_num_str <- as.character(stage_num)
    if (stage_num_str %in% names(rule_set)) {
      stage_def <- rule_set[[stage_num_str]]
      stage_name <- stage_def$name
      
      log_message(sprintf("Evaluating stage %d: %s", stage_num, stage_name))
      
      rule_cols <- sapply(seq_along(stage_def$rules), function(i) {
        make_rule_col_name(scenario_name, stage_num, i, stage_def$rules[[i]])
      })
      rule_cols <- rule_cols[rule_cols %in% names(result_dt)]
      if (length(rule_cols) != length(stage_def$rules)) next

      rules_met <- rowSums(result_dt[, ..rule_cols] == 1, na.rm = TRUE) == length(rule_cols)
      rules_met[is.na(rules_met)] <- FALSE

      result_dt[rules_met, stage := as.integer(stage_num)]
      num_signals <- sum(rules_met, na.rm = TRUE)
      log_message(sprintf("  Generated %d ENTRY signals for stage %d (%s)", 
                         num_signals, stage_num, stage_name))
    } else {
      log_message(sprintf("  Stage %d not found in rule set", stage_num), "DEBUG")
    }
  }
  
  # Ensure required columns are present before calling generate_trade_status
  if (!"stop_loss" %in% names(result_dt)) {
    result_dt[, stop_loss := close * 0.95]  # Default 5% stop loss if not set
  }
  if (!"entry_price" %in% names(result_dt)) {
    result_dt[, entry_price := NA_real_]
  }
  if (!"entry_date" %in% names(result_dt)) {
    result_dt[, entry_date := as.character(NA)]
  }
  if (!"exit_price" %in% names(result_dt)) {
    result_dt[, exit_price := NA_real_]
  }
  if (!"exit_date" %in% names(result_dt)) {
    result_dt[, exit_date := as.character(NA)]
  }
  if (!"pnl_pct" %in% names(result_dt)) {
    result_dt[, pnl_pct := NA_real_]
  }
  
  # Ensure stage column is properly set
  if (!"stage" %in% names(result_dt)) {
    result_dt[, stage := NA_integer_]
  }
  
  # Generate trade status with error handling
  # Apply legacy semantics adapter (ported from 9_mmtm_oldversion.R) for this scenario
  # Map scenario stage (1..6) to legacy stage_ff (0..5)
  result_dt[, stage_ff := {
    v <- as.integer(stage)
    out <- rep(NA_integer_, .N)
    ok <- !is.na(v)
    out[ok] <- pmax(0L, pmin(5L, v[ok] - 1L))
    out
  }]

  stage_defs <- lapply(0:5, function(sff) {
    scen_stage <- as.character(sff + 1L)
    if (scen_stage %in% names(rule_set)) {
      list(
        stage = sff,
        name = rule_set[[scen_stage]]$name,
        optimal_days = rule_set[[scen_stage]]$optimal_days
      )
    } else {
      list(stage = sff, name = paste0("STAGE_", sff), optimal_days = NA_integer_)
    }
  })
  names(stage_defs) <- as.character(0:5)

  result_dt <- tryCatch({
    add_metadata_legacy(result_dt, stage_defs)
  }, error = function(e) {
    log_message(sprintf("Scenario %s: add_metadata_legacy failed: %s", scenario_name, e$message), "ERROR")
    stop(e)
  })

  result_dt <- tryCatch({
    calculate_dynamic_levels(result_dt)
  }, error = function(e) {
    log_message(sprintf("Scenario %s: calculate_dynamic_levels failed: %s", scenario_name, e$message), "ERROR")
    stop(e)
  })

  result_dt <- tryCatch({
    generate_trade_status_legacy(result_dt, stage_defs, execute_next_day = isTRUE(execute_next_day))
  }, error = function(e) {
    log_message(sprintf("Scenario %s: generate_trade_status_legacy failed: %s", scenario_name, e$message), "ERROR")
    stop(e)
  })
  
  log_message(sprintf("Scenario %s completed: %d entries, %d exits", 
                     scenario_name, 
                     sum(grepl("ENTRY_", result_dt$status)),
                     sum(grepl("EXIT_", result_dt$status))))
  
  return(result_dt)
}

# ============================================================================
# 10. MAIN EXECUTION
# ============================================================================

main_run_scenarios <- function() {
  log_message("Starting MMTM scenario analysis...")
  
  # Parse arguments
  args <- parse_arguments()
  log_message(sprintf("Reference date: %s", args$ref_date))
  log_message(sprintf("DEBUG: scenario argument: %s", args$scenario))
  if (!is.null(args$limit_companies)) {
    log_message(sprintf("Limit companies: %d", args$limit_companies))
  }
  
  # Create output directory if it doesn't exist
  output_dir <- "output/mmtm"
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Load prepared data
  log_message("Loading prepared data...")
  dt <- load_prepared_data(args$ref_date)
  
  # Apply company limit if specified (must be done before any processing)
  if (!is.null(args$limit_companies)) {
    log_message(sprintf("Limiting to first %d companies before any processing...", args$limit_companies))
    # Get the first N unique companies
    selected_companies <- unique(dt$company_id)[1:min(args$limit_companies, length(unique(dt$company_id)))]
    # Filter the data to only include these companies
    dt <- dt[company_id %in% selected_companies]
    log_message(sprintf("Filtered to %d rows for %d companies", 
                      nrow(dt), 
                      length(selected_companies)))
  }
  
  # Skip indicator calculation - data is already prepared
  log_message("Using pre-calculated indicators from prepared data...")

  # Process scenarios based on arguments
  if (!is.na(args$scenario) && nzchar(args$scenario)) {
    # Process single specified scenario
    if (!args$scenario %in% names(rule_sets)) {
      stop(sprintf("Unknown scenario '%s'. Available scenarios: %s", args$scenario, paste(names(rule_sets), collapse = ", ")))
    }
    available_scenarios <- args$scenario
    log_message(sprintf("Processing single scenario: %s", args$scenario))
  } else {
    # Default to momentum_0
    available_scenarios <- "momentum_0"
    log_message("Defaulting to scenario: momentum_0")
  }
  
  # Process each scenario sequentially with complete pipeline
  for (scenario_name in available_scenarios) {
    tryCatch({
      log_message(sprintf("\n=== Processing scenario: %s ===", scenario_name))

      # Get the rule set for this scenario
      scenario_rule_set <- rule_sets[[scenario_name]]
      if (is.null(scenario_rule_set)) {
        log_message(sprintf("No rule set found for scenario: %s", scenario_name), "WARN")
        next
      }

      # Start with the base processed data (with indicators calculated)
      scenario_dt <- copy(dt)

      # Evaluate rules for this scenario
      scenario_dt <- evaluate_scenario_rules(
        scenario_dt,
        scenario_name,
        scenario_rule_set,
        execute_next_day = isTRUE(args$execute_next_day)
      )

      # Note: evaluate_scenario_rules already handles stage assignment and exit conditions
      # No need for separate assign_stage_scenario call

      # Add stage history for this scenario
      log_message(sprintf("Adding stage history for scenario: %s", scenario_name))
      scenario_dt <- add_stage_history(scenario_dt)

      # ensure status column is present and has no NAs
      if (!"status" %in% names(scenario_dt)) {
        scenario_dt[, status := "NO_ACTION"]
      } else {
        # Only replace NA status values, preserve existing ENTRY_ and EXIT_ statuses
        scenario_dt[is.na(status), status := "NO_ACTION"]
      }
  
      # Log the distribution of status values for debugging
      if ("status" %in% names(scenario_dt)) {
        status_counts <- scenario_dt[, .N, by = status][order(-N)]
        log_message("Status distribution after processing:")
        for (i in 1:min(10, nrow(status_counts))) {
          log_message(sprintf("  %-40s: %d (%.1f%%)", 
                            status_counts$status[i], 
                            status_counts$N[i],
                            status_counts$N[i] / nrow(scenario_dt) * 100))
        }
      }
      
      # Save scenario-specific results
      scenario_output_file <- sprintf("%s/%s_%s.csv", output_dir, scenario_name, format(args$ref_date, "%Y-%m-%d"))
      log_message(sprintf("Saving scenario %s to: %s", scenario_name, scenario_output_file))
      
      # Ensure all required columns are present
      required_cols <- c("status", "stage", "scenario", "stop_loss", "entry_price", 
                        "entry_date", "exit_price", "exit_date", "pnl_pct", "exit_reason")
      for (col in required_cols) {
        if (!col %in% names(scenario_dt)) {
          if (col %in% c("stop_loss", "entry_price", "exit_price", "pnl_pct")) {
            scenario_dt[, (col) := NA_real_]
          } else if (col %in% c("entry_date", "exit_date")) {
            scenario_dt[, (col) := as.character(NA)]
          } else if (col %in% c("status", "scenario", "exit_reason")) {
            # Don't overwrite existing status values
            if (col == "status" && "status" %in% names(scenario_dt)) next
            scenario_dt[, (col) := as.character(NA)]
          } else if (col == "stage") {
            scenario_dt[, (col) := NA_integer_]
          }
        }
      }
      
      # Define the order of columns for the output
      first_cols <- c("company_id", "symbol", "date", "close", "status", "stage", "scenario")
      
      # Get all rule condition columns (m{num}_s{num}_*)
      rule_cols <- grep("^m[0-9]+_s[0-9]+_", names(scenario_dt), value = TRUE)
      
      # Get all other columns (excluding first_cols and rule_cols)
      other_cols <- setdiff(names(scenario_dt), c(first_cols, rule_cols))
      
      # Reorder columns: first_cols, then rule_cols, then other_cols
      setcolorder(scenario_dt, c(first_cols, rule_cols, other_cols))
      
      # Save the scenario data
      data.table::fwrite(scenario_dt, scenario_output_file)

      log_message(sprintf("✓ Scenario %s completed and saved successfully", scenario_name))
      
      # Step 2: Trade analysis will be handled by orchestrator (s1) directly
      log_message(sprintf("📊 Momentum file created for scenario: %s - trade analysis will be handled by orchestrator", scenario_name))
      
      # Clean up: Remove momentum file after orchestrator completes trade analysis
      # Note: This cleanup will be handled by orchestrator after s4 completes
      
      # Small delay between scenarios
      Sys.sleep(0.2)

    }, error = function(e) {
      log_message(sprintf("✗ Error processing scenario %s: %s", scenario_name, e$message), "ERROR")

      calls <- sys.calls()
      tail_calls <- tail(calls, 10)
      tail_str <- paste(vapply(tail_calls, function(x) paste(deparse(x), collapse = ""), character(1)), collapse = " <- ")
      log_message(sprintf("Call stack (tail): %s", tail_str), "ERROR")
    })
  }

  # Skip creating aggregated file to avoid memory issues with large datasets
  log_message("Skipping aggregated file creation to conserve memory")
  log_message("Individual scenario files contain all required data")
  
  # Only show "All scenarios processed" if actually processing multiple scenarios
  if (length(available_scenarios) > 1) {
    log_message("\n=== All scenarios processed ===")
    log_message("Individual scenario files generated successfully!")
  }
  
  log_message("✅ Scenario processing completed successfully", "SUCCESS")
  
  return(invisible(NULL))
}

# ============================================================================
# 6. STAGE ASSIGNMENT FUNCTIONS (using s3.2 rule sets)
# ============================================================================

assign_stage_scenario <- function(dt, scenario_name, rule_set) {
  log_message(sprintf("Assigning stages for scenario: %s", scenario_name))
  
  # Initialize stage column if it doesn't exist
  if (!"stage" %in% names(dt)) {
    dt[, stage := NA_integer_]
  }
  
  # Process each stage in the rule set (1-6)
  for (stage_num in 1:6) {
    stage_num_str <- as.character(stage_num)
    if (stage_num_str %in% names(rule_set)) {
      stage_def <- rule_set[[stage_num_str]]
      stage_name <- stage_def$name
      
      log_message(sprintf("  Processing stage %d: %s", stage_num, stage_name))
      
      # Check which rows met all rules for this stage
      rule_cols <- paste0("scenario_", scenario_name, "_stage_", stage_num, "_rules_", 
                         seq_along(stage_def$rules))
      existing_cols <- rule_cols[rule_cols %in% names(dt)]
      
      if (length(existing_cols) > 0) {
        # All rules must be TRUE (value = 1)
        rules_met <- rowSums(dt[, ..existing_cols] == 1, na.rm = TRUE) == length(existing_cols)
        rules_met[is.na(rules_met)] <- FALSE
        
        # Assign stage where rules are met
        dt[rules_met, stage := as.integer(stage_num)]
        
        log_message(sprintf("    Assigned stage %d to %d rows", stage_num, sum(rules_met)))
        
        # Clean up temporary rule columns
        dt[, (existing_cols) := NULL]
      }
    }
  }
  
  # Carry forward stage (locf) to avoid gaps, but only within each company's data
  dt[, stage := nafill(stage, type = "locf"), by = company_id]
  
  # Log stage distribution
  log_stage_distribution(dt, paste("for scenario", scenario_name))
  
  return(dt)
}

# Helper function to log stage distribution
log_stage_distribution <- function(dt, context = "") {
  if (nrow(dt) == 0) {
    log_message("No data to show stage distribution", "WARN")
    return()
  }
  
  if (!"stage" %in% names(dt)) {
    log_message("No 'stage' column found in data", "WARN")
    return()
  }
  
  stage_dist <- dt[, .N, by = stage][order(stage)]
  log_message(sprintf("Stage distribution %s:", context))
  
  for (i in 1:nrow(stage_dist)) {
    stage_num <- stage_dist$stage[i]
    if (is.na(stage_num)) {
      stage_name <- "NO_STAGE"
    } 
    log_message(sprintf("  %-25s: %6d rows (%.1f%%)", 
                       paste0(stage_name, " (", stage_num, ")"), 
                       stage_dist$N[i],
                       stage_dist$N[i] / nrow(dt) * 100))
  }

  return(dt)
}

assign_stage <- function(dt) {
  log_message("Assigning base momentum stages using s3.2 rule sets...")

  # Initialize stage tracking
  dt[, stage := NA_integer_]

  # Get available scenarios from s3.2
  if (!is.na(args$scenario) && nzchar(args$scenario)) {
    # For single scenario, only use that scenario
    available_scenarios <- args$scenario
    log_message(sprintf("Available scenarios from s3.2: %s", paste(available_scenarios, collapse = ", ")))
  } else {
    # For all scenarios or default, use all scenarios
    available_scenarios <- names(rule_sets)
    log_message(sprintf("Available scenarios from s3.2: %s", paste(available_scenarios, collapse = ", ")))
  }

  # For base stage assignment, we'll use the first scenario (momentum_0) as reference
  # This gives us the standard momentum cycle stages
  if ("momentum_0" %in% available_scenarios) {
    base_rule_set <- rule_sets[["momentum_0"]]

    # Process each stage in the base rule set
    for (stage_num in names(base_rule_set)) {
      stage_def <- base_rule_set[[stage_num]]
      stage_name <- stage_def$name

      log_message(sprintf("Processing base stage %s: %s", stage_num, stage_name))

      # Use s3.3 rule evaluator to evaluate this stage
      tryCatch({
        dt <- evaluate_stage_rules(dt, stage_def, paste0("base_stage_", stage_num, "_rules"))

        # Check which rows met all rules for this stage
        stage_rule_cols <- paste0("base_stage_", stage_num, "_rules_", seq_along(stage_def$rules))
        existing_cols <- stage_rule_cols[stage_rule_cols %in% names(dt)]

        if (length(existing_cols) > 0) {
          # All rules must be TRUE (value = 1)
          rules_met <- rowSums(dt[, ..existing_cols] == 1) == length(existing_cols)
          rules_met[is.na(rules_met)] <- FALSE

          # Assign stage where rules are met
          dt[rules_met, stage := as.integer(stage_num)]

          log_message(sprintf("  Assigned stage %s to %d rows", stage_num, sum(rules_met)))

          # Clean up temporary rule columns
          dt[, (existing_cols) := NULL]
        } else {
          log_message(sprintf("  No valid rules found for stage %s", stage_name), "WARN")
        }

  }, error = function(e) {
        log_message(sprintf("  Error evaluating stage %s: %s", stage_name, e$message), "WARN")
      })
    }
  } else {
    log_message("No momentum_0 scenario found in s3.2 rule sets", "WARN")
  }

# Carry forward stage (locf) to avoid gaps
dt[, stage := nafill(stage, type = "locf"), by = company_id]

  # Log stage distribution
stage_dist <- dt[, .N, by = stage][order(stage)]
  log_message("Stage distribution:")
  for (i in 1:nrow(stage_dist)) {
    stage_name <- if(is.na(stage_dist$stage[i])) {
   "NO_STAGE"
  } else {
      # Get stage name from s3.2 rule sets
      stage_num <- as.character(stage_dist$stage[i])
      if ("momentum_0" %in% names(rule_sets) && stage_num %in% names(rule_sets[["momentum_0"]])) {
        rule_sets[["momentum_0"]][[stage_num]]$name
   } else {
        paste("Stage", stage_num)
      }
    }
    log_message(sprintf("  Stage %s (%s): %d rows", stage_dist$stage[i], stage_name, stage_dist$N[i]))
  }

 return(dt)
}

# ============================================================================
# 7. MAIN EXECUTION
# ============================================================================
# ============================================================================
# 11. SCRIPT EXECUTION
# ============================================================================

# Only execute if run as a script (not sourced)
if (!interactive()) {
  tryCatch({
    main_run_scenarios()
    log_message("Script completed successfully", "SUCCESS")
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
    
    log_message(sprintf("Fatal error in execution: %s", error_msg), "ERROR")
    
    if (exists(".traceback")) {
      log_message("Stack trace:", "ERROR")
      log_message(utils::capture.output(print(.traceback())), "ERROR")
    }
    
    quit(save = "no", status = 1)
  })
} 