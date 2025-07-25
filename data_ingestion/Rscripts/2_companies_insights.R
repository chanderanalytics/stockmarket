source("data_ingestion/Rscripts/0_setup_renv.R")


log_file <- sprintf("log/companies_insights_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
flog.appender(appender.file(log_file))

flog.info("Starting companies insights script")

# ---
# Database credentials are now read from environment variables.
# Set these in your shell, .Renviron, or with the dotenv package:

# ---

user <- Sys.getenv("PGUSER")
password <- Sys.getenv("PGPASSWORD")
host <- Sys.getenv("PGHOST", "localhost")
port <- as.integer(Sys.getenv("PGPORT", "5432"))
dbname <- Sys.getenv("PGDATABASE", "stockdb")

flog.info("Connecting to PostgreSQL database: %s@%s:%s/%s", user, host, port, dbname)

tryCatch({
  # Define metrics to average and rank at the very top
  metrics_to_average <- c("return_on_equity", "price_to_earning", "eps", "debt_to_equity")
  
  metrics_to_rank <- list(
    return_on_equity = TRUE,
    price_to_earning = FALSE,
    eps = TRUE,
    debt_to_equity = FALSE
  )
  ranking_group_fields <- c(
    "sector_name_bse", 
    "industry_bse", 
    "industry_new_name_bse", 
    "igroup_name_bse", 
    "isubgroup_name_bse"
  )

  # 1. Connect to PostgreSQL
  con <- dbConnect(
    RPostgres::Postgres(),
    dbname = dbname,
    host = host,
    port = port,
    user = user,
    password = password
  )
  flog.info("Connected to database.")


  # 2. Pull the companies table as data.table
  dt_companies <- as.data.table(dbGetQuery(con, "SELECT * FROM companies"))
  flog.info("Pulled %d rows from companies table", nrow(dt_companies))
  
  # --- BSE Mapping: Clean, robust logic ---
  bse_map <- fread("/Users/chanderbhushan/stockmkt/data/BSE_Sector_Mapping.csv")
  # Standardize the key column name for merging
  if ("Security Code" %in% names(bse_map)) setnames(bse_map, "Security Code", "bse_code")
  if ("security_code" %in% names(bse_map)) setnames(bse_map, "security_code", "bse_code")
  # Rename all other columns to have _bse suffix (except the key)
  cols_to_rename <- setdiff(names(bse_map), "bse_code")
  setnames(bse_map, cols_to_rename, paste0(cols_to_rename, "_bse"))
  # Ensure dt_companies has bse_code as integer
  if (!"bse_code" %in% names(dt_companies) && "bse_code" %in% names(dt_companies)) dt_companies[, bse_code := as.integer(trimws(as.character(bse_code)))]
  dt_companies[, bse_code := as.integer(trimws(as.character(bse_code)))]
  bse_map[, bse_code := as.integer(trimws(as.character(bse_code)))]
  # Merge
  merged_dt <- merge(
    dt_companies,
    bse_map,
    by = "bse_code",
    all.x = TRUE
  )
  # Debug: check name column after merge
  cat("[DEBUG] Columns after merge:", paste(names(merged_dt), collapse=", "), "\n")
  cat("[DEBUG] Sample names after merge:", paste(head(merged_dt$name, 10), collapse=", "), "\n")
  dt_companies <- merged_dt
  flog.info("Mapped BSE sector/industry using BSE code with _bse suffix.")

  # 3. Data Cleaning (data.table syntax)
  #dt_companies <- dt_companies[!is.na(market_capitalization) & !is.na(sector) & !is.na(roe)]
  #flog.info("Completed data cleaning. Rows after cleaning: %d", nrow(dt_companies))

  # 4. Feature Engineering
  flog.info("Starting feature engineering...")

  # Market Cap Classification
  q90 <- quantile(dt_companies$market_capitalization, 0.9, na.rm=TRUE)
  q50 <- quantile(dt_companies$market_capitalization, 0.5, na.rm=TRUE)
  dt_companies[, cap_class := fifelse(market_capitalization >= q90, "top 10perc by mcap",
                                      fifelse(market_capitalization >= q50 & market_capitalization < q90, "50-90% by mcap",
                                       "bottom 50% by mcap"))]
  flog.info("Added quantile-based market cap classification.")

  # SEBI-style absolute classification (assuming market_capitalization is in crores)
  dt_companies[, cap_class_sebi := fifelse(
    market_capitalization > 20000, "Large Cap",
    fifelse(market_capitalization > 5000 & market_capitalization <= 20000, "Mid Cap", "Small Cap")
  )]
  flog.info("Added SEBI-style market cap classification.")

  # Decile-based classification (Decile 1 = largest, Decile 10 = smallest)
  # Remove the dedicated mcap_decile calculation block
  # dt_companies[, mcap_decile := cut(
  #   rank(-market_capitalization, ties.method = "min"),
  #   breaks = quantile(rank(-market_capitalization, ties.method = "min"), probs = seq(0, 1, 0.1), na.rm = TRUE),
  #   labels = as.character(1:10),
  #   include.lowest = TRUE
  # )]

  

  # Z-scores for ROE, PE, EPS, and Debt to Equity
  dt_companies[, z_roe := (return_on_equity - mean(return_on_equity, na.rm=TRUE)) / sd(return_on_equity, na.rm=TRUE)]
  dt_companies[, z_pe := (price_to_earning - mean(price_to_earning, na.rm=TRUE)) / sd(price_to_earning, na.rm=TRUE)]
  dt_companies[, z_eps := (eps - mean(eps, na.rm=TRUE)) / sd(eps, na.rm=TRUE)]
  dt_companies[, z_debt_to_equity := (debt_to_equity - mean(debt_to_equity, na.rm=TRUE)) / sd(debt_to_equity, na.rm=TRUE)]
  flog.info("Added z-scores for ROE, PE, EPS, and Debt to Equity.")

  # Composite Value Score (example: high ROE, low PE, high EPS, low Debt to Equity)
  dt_companies[, value_score := scale(-price_to_earning) + scale(return_on_equity) + scale(eps) + scale(-debt_to_equity)]
  flog.info("Added composite value score (ROE, PE, EPS, Debt to Equity).")

  # Outlier flag for PE, ROE, EPS, and Debt to Equity
  dt_companies[, pe_outlier := abs(z_pe) > 3]
  dt_companies[, roe_outlier := abs(z_roe) > 3]
  dt_companies[, eps_outlier := abs(z_eps) > 3]
  dt_companies[, debt_to_equity_outlier := abs(z_debt_to_equity) > 3]
  flog.info("Added outlier flags for PE, ROE, EPS, and Debt to Equity.")

  # Convert outlier columns to 0/1 and set NA to 0
  outlier_cols <- c("pe_outlier", "roe_outlier", "eps_outlier", "debt_to_equity_outlier")
  for (col in outlier_cols) {
    if (col %in% names(dt_companies)) {
      dt_companies[, (col) := as.integer(get(col))]
      dt_companies[is.na(get(col)), (col) := 0]
    }
  }

  # Add ranking columns for all metrics and group fields
  for (group_field in ranking_group_fields) {
    if (group_field %in% names(dt_companies)) {
      is_blank <- is.na(dt_companies[[group_field]]) | trimws(dt_companies[[group_field]]) == ""
      for (metric in names(metrics_to_rank)) {
        if (metric %in% names(dt_companies)) {
          rank_col <- paste0(metric, "_rank_by_", group_field)
          if (metrics_to_rank[[metric]]) {
            # Higher is better
            dt_companies[, (rank_col) := frank(-get(metric), ties.method = "min"), by = group_field]
          } else {
            # Lower is better
            dt_companies[, (rank_col) := frank(get(metric), ties.method = "min"), by = group_field]
          }
          # Set indicator for blank/NA groups
          dt_companies[is_blank, (rank_col) := 9999]
        }
      }
      for (metric in metrics_to_average) {
        avg_col <- paste0(group_field, "_avg_", metric)
        if (avg_col %in% names(dt_companies)) {
          dt_companies[is_blank, (avg_col) := 9999]
        }
      }
    }
  }

  # Modular group averages for each group field and metric
  for (group_field in ranking_group_fields) {
    if (group_field %in% names(dt_companies)) {
      for (metric in metrics_to_average) {
        if (metric %in% names(dt_companies)) {
          avg_col <- paste0(group_field, "_avg_", metric)
          dt_companies[, (avg_col) := mean(get(metric), na.rm = TRUE), by = group_field]
        }
      }
    }
  }

  # Set 9999 for blank/NA groups in group average columns (after averages are calculated)
  for (group_field in ranking_group_fields) {
    if (group_field %in% names(dt_companies)) {
      is_blank <- is.na(dt_companies[[group_field]]) | trimws(dt_companies[[group_field]]) == ""
      for (metric in metrics_to_average) {
        avg_col <- paste0(group_field, "_avg_", metric)
        if (avg_col %in% names(dt_companies)) {
          dt_companies[is_blank, (avg_col) := 9999]
        }
      }
    }
  }

  # ---
  # Additional scalable, dashboard-ready calculations

  # 1. Peer-relative columns for all metrics
  for (group_field in ranking_group_fields) {
    for (metric in metrics_to_average) {
      avg_col <- paste0(group_field, "_avg_", metric)
      rel_col <- paste0(metric, "_vs_", group_field, "_avg")
      if (avg_col %in% names(dt_companies) && metric %in% names(dt_companies)) {
        dt_companies[, (rel_col) := get(metric) - get(avg_col)]
      }
    }
  }

  # 2. Net profit margin and operating margin
  if (all(c("profit_after_tax", "sales") %in% names(dt_companies))) {
    dt_companies[, net_profit_margin := profit_after_tax / sales]
  }
  if (all(c("operating_profit", "sales") %in% names(dt_companies))) {
    dt_companies[, operating_margin := operating_profit / sales]
  }

  # 3. Earnings yield and PEG ratio
  if ("price_to_earning" %in% names(dt_companies)) {
    dt_companies[, earnings_yield := 1 / price_to_earning]
  }
  if (all(c("price_to_earning", "eps_growth_3years") %in% names(dt_companies))) {
    dt_companies[, peg_ratio := price_to_earning / eps_growth_3years]
  }

  # 4. Leverage and liquidity risk flags
  if ("debt_to_equity" %in% names(dt_companies)) {
    dt_companies[, leverage_risk := as.integer(debt_to_equity > 2)]
  }
  if ("currentRatio_yf" %in% names(dt_companies)) {
    dt_companies[, liquidity_risk := as.integer(currentRatio_yf < 1)]
  }

  # 5. Return vs. peer average
  for (group_field in ranking_group_fields) {
    avg_col <- paste0(group_field, "_avg_return_over_1year")
    if (avg_col %in% names(dt_companies) && "return_over_1year" %in% names(dt_companies)) {
      rel_col <- paste0("return_over_1year_vs_", group_field, "_avg")
      dt_companies[, (rel_col) := return_over_1year - get(avg_col)]
    }
  }

  # 6. Composite scores
  # Quality: ROE, net profit margin, sales growth
  if (all(c("return_on_equity", "net_profit_margin", "sales_growth_3years") %in% names(dt_companies))) {
    dt_companies[, quality_score := scale(return_on_equity) + scale(net_profit_margin) + scale(sales_growth_3years)]
  }
  # Value: -PE, -PBV, dividend yield
  if (all(c("price_to_earning", "price_to_book_value", "dividend_yield") %in% names(dt_companies))) {
    dt_companies[, value_score_composite := scale(-price_to_earning) + scale(-price_to_book_value) + scale(dividend_yield)]
  }

  # 7. Distance from all-time high
  if (all(c("current_price", "high_price_all_time") %in% names(dt_companies))) {
    dt_companies[, distance_from_ath := (current_price - high_price_all_time) / high_price_all_time]
  }

  # 8. Listing age (years)
  if ("listing_date" %in% names(dt_companies)) {
    dt_companies[, listing_age_years := as.numeric(Sys.Date() - as.Date(listing_date)) / 365.25]
  }
  # ---

  # ---
  # Replace NA/nulls in derived columns with 9999 for Power BI-friendliness
  derived_cols <- c(
    # Peer-relative columns
    unlist(lapply(ranking_group_fields, function(g) paste0(metrics_to_average, "_vs_", g, "_avg"))),
    # Margins, yields, ratios, scores, etc.
    "net_profit_margin", "operating_margin", "earnings_yield", "peg_ratio",
    "leverage_risk", "liquidity_risk", "quality_score", "value_score_composite",
    "distance_from_ath", "listing_age_years"
  )
  for (col in derived_cols) {
    if (col %in% names(dt_companies)) {
      dt_companies[is.na(get(col)), (col) := 9999]
    }
  }
  # ---

  # --- Trend features: estimate historical value and percent change for all available metrics with 3y/5y growth ---
  trend_metrics <- list(
    sales = list(growth3 = "sales_growth_3years", growth5 = "sales_growth_5years"),
    profit_after_tax = list(growth3 = "profit_growth_3years", growth5 = "profit_growth_5years"),
    eps = list(growth3 = "eps_growth_3years", growth5 = NULL)
  )
  for (metric in names(trend_metrics)) {
    growth3_col <- trend_metrics[[metric]]$growth3
    growth5_col <- trend_metrics[[metric]]$growth5
    if (!is.null(growth3_col) && all(c(metric, growth3_col) %in% names(dt_companies))) {
      dt_companies[, paste0(metric, "_3y_ago") := get(metric) / (1 + get(growth3_col))^3]
      dt_companies[, paste0(metric, "_vs_3y_ago") := (get(metric) - get(paste0(metric, "_3y_ago"))) / get(paste0(metric, "_3y_ago"))]
    }
    if (!is.null(growth5_col) && all(c(metric, growth5_col) %in% names(dt_companies))) {
      dt_companies[, paste0(metric, "_5y_ago") := get(metric) / (1 + get(growth5_col))^5]
      dt_companies[, paste0(metric, "_vs_5y_ago") := (get(metric) - get(paste0(metric, "_5y_ago"))) / get(paste0(metric, "_5y_ago"))]
    }
  }
  # ---

  # ---
  # Volume-based metrics and flags
  if (all(c("volume", "volume_1week_average") %in% names(dt_companies))) {
    dt_companies[, volume_vs_1week_avg := volume / volume_1week_average]
    dt_companies[, volume_spike_1week := as.integer(volume_vs_1week_avg > 2)]
  }
  if (all(c("volume", "volume_1month_average") %in% names(dt_companies))) {
    dt_companies[, volume_vs_1month_avg := volume / volume_1month_average]
    dt_companies[, volume_spike_1month := as.integer(volume_vs_1month_avg > 2)]
    dt_companies[, low_volume_flag := as.integer(volume < volume_1month_average * 0.5)]
  }
  if (all(c("volume", "volume_1year_average") %in% names(dt_companies))) {
    dt_companies[, volume_vs_1year_avg := volume / volume_1year_average]
    dt_companies[, volume_spike_1year := as.integer(volume_vs_1year_avg > 2)]
  }
  if (all(c("volume", "market_capitalization") %in% names(dt_companies))) {
    dt_companies[, liquidity_score_volume := volume / market_capitalization]
  }
  # Peer-relative volume for all groups (REMOVED as not meaningful across different market caps)
  # for (group_field in ranking_group_fields) {
  #   avg_col <- paste0(group_field, "_avg_volume")
  #   if (avg_col %in% names(dt_companies) && "volume" %in% names(dt_companies)) {
  #     rel_col <- paste0("volume_vs_", group_field, "_avg")
  #     dt_companies[, (rel_col) := volume - get(avg_col)]
  #   }
  # }
  # Replace NA/nulls in new volume columns with 9999 (excluding peer-relative volume columns)
  volume_derived_cols <- c(
    "volume_vs_1week_avg", "volume_spike_1week",
    "volume_vs_1month_avg", "volume_spike_1month", "low_volume_flag",
    "volume_vs_1year_avg", "volume_spike_1year",
    "liquidity_score_volume"
    # Peer-relative columns removed
  )
  for (col in volume_derived_cols) {
    if (col %in% names(dt_companies)) {
      dt_companies[is.na(get(col)), (col) := 9999]
    }
  }
  # ---

# Print head of market_capitalization before decile loop
a <- head(dt_companies$market_capitalization)
# cat('Head of market_capitalization:', a, '\n') # Commented out

# Diagnostic prints for debt_to_equity and peg_ratio
# cat('Summary for debt_to_equity:\n') # Commented out
# print(summary(dt_companies$debt_to_equity)) # Commented out
# cat('Unique values for debt_to_equity:', length(unique(dt_companies$debt_to_equity)), '\n') # Commented out
# cat('Summary for peg_ratio:\n') # Commented out
# print(summary(dt_companies$peg_ratio)) # Commented out
# cat('Unique values for peg_ratio:', length(unique(dt_companies$peg_ratio)), '\n') # Commented out

# --- Decile calculation for key metrics (current, growth, expected) ---
metrics_decile_higher_better <- c(
  "market_capitalization", "return_on_equity", "return_on_assets", "net_profit_margin", "eps", "revenue_growth", "ebitda_margin",
  "sales_growth_3years", "profit_growth_3years", "profit_growth_5years", "eps_growth_3years",
  "expected_quarterly_sales", "expected_quarterly_eps", "expected_quarterly_net_profit"
)
metrics_decile_lower_better <- c("price_to_earning", "price_to_book_value", "debt_to_equity", "peg_ratio")

for (metric in metrics_decile_higher_better) {
  if (metric %in% names(dt_companies)) {
    decile_col <- paste0(metric, "_decile")
    valid_idx <- which(is.finite(dt_companies[[metric]]) & dt_companies[[metric]] != 9999 & !is.na(dt_companies[[metric]]))
    metric_ranks <- rep(NA_integer_, nrow(dt_companies))
    metric_ranks[valid_idx] <- rank(-dt_companies[[metric]][valid_idx], ties.method = "min")
    bins_used <- 10
    repeat {
      qtiles <- quantile(metric_ranks[valid_idx], probs = seq(0, 1, length.out = bins_used + 1), na.rm = TRUE)
      if (length(unique(qtiles)) == length(qtiles)) {
        deciles <- rep(NA_character_, nrow(dt_companies))
        deciles[valid_idx] <- as.character(cut(
          metric_ranks[valid_idx],
          breaks = qtiles,
          labels = as.character(1:bins_used),
          include.lowest = TRUE
        ))
        dt_companies[, (decile_col) := deciles]
        flog.info("Assigned %d-bin quantiles for %s", bins_used, metric)
        break
      } else if (bins_used > 2) {
        bins_used <- bins_used - 1
      } else {
        dt_companies[, (decile_col) := NA_character_]
        flog.info("Skipped quantile for %s due to insufficient unique values", metric)
        break
      }
    }
  }
}
for (metric in metrics_decile_lower_better) {
  if (metric %in% names(dt_companies)) {
    decile_col <- paste0(metric, "_decile")
    valid_idx <- which(is.finite(dt_companies[[metric]]) & dt_companies[[metric]] != 9999 & !is.na(dt_companies[[metric]]))
    metric_ranks <- rep(NA_integer_, nrow(dt_companies))
    metric_ranks[valid_idx] <- rank(dt_companies[[metric]][valid_idx], ties.method = "min")
    bins_used <- 10
    repeat {
      qtiles <- quantile(metric_ranks[valid_idx], probs = seq(0, 1, length.out = bins_used + 1), na.rm = TRUE)
      if (length(unique(qtiles)) == length(qtiles)) {
        deciles <- rep(NA_character_, nrow(dt_companies))
        deciles[valid_idx] <- as.character(cut(
          metric_ranks[valid_idx],
          breaks = qtiles,
          labels = as.character(1:bins_used),
          include.lowest = TRUE
        ))
        dt_companies[, (decile_col) := deciles]
        flog.info("Assigned %d-bin quantiles for %s", bins_used, metric)
        break
      } else if (bins_used > 2) {
        bins_used <- bins_used - 1
      } else {
        dt_companies[, (decile_col) := NA_character_]
        flog.info("Skipped quantile for %s due to insufficient unique values", metric)
        break
      }
    }
  }
}

# --- Deciles for expected quarterly metrics ---
expected_metrics <- c("expected_quarterly_sales", "expected_quarterly_eps", "expected_quarterly_net_profit")
for (metric in expected_metrics) {
  if (metric %in% names(dt_companies)) {
    decile_col <- paste0(metric, "_decile")
    valid_idx <- which(is.finite(dt_companies[[metric]]) & dt_companies[[metric]] != 9999 & !is.na(dt_companies[[metric]]))
    metric_ranks <- rep(NA_integer_, nrow(dt_companies))
    metric_ranks[valid_idx] <- rank(-dt_companies[[metric]][valid_idx], ties.method = "min")
    bins_used <- 10
    repeat {
      qtiles <- quantile(metric_ranks[valid_idx], probs = seq(0, 1, length.out = bins_used + 1), na.rm = TRUE)
      if (length(unique(qtiles)) == length(qtiles)) {
        deciles <- rep(NA_character_, nrow(dt_companies))
        deciles[valid_idx] <- as.character(cut(
          metric_ranks[valid_idx],
          breaks = qtiles,
          labels = as.character(1:bins_used),
          include.lowest = TRUE
        ))
        dt_companies[, (decile_col) := deciles]
        flog.info("Assigned %d-bin quantiles for %s", bins_used, metric)
        break
      } else if (bins_used > 2) {
        bins_used <- bins_used - 1
      } else {
        dt_companies[, (decile_col) := NA_character_]
        flog.info("Skipped quantile for %s due to insufficient unique values", metric)
        break
      }
    }
  }
}

# --- Trend features: expected vs. current/actual ---
if (all(c("expected_quarterly_sales", "sales") %in% names(dt_companies))) {
  dt_companies[, expected_sales_vs_current := (expected_quarterly_sales - sales) / sales]
}
if (all(c("expected_quarterly_eps", "eps") %in% names(dt_companies))) {
  dt_companies[, expected_eps_vs_current := (expected_quarterly_eps - eps) / eps]
}
if (all(c("expected_quarterly_net_profit", "profit_after_tax") %in% names(dt_companies))) {
  dt_companies[, expected_net_profit_vs_current := (expected_quarterly_net_profit - profit_after_tax) / profit_after_tax]
}

  # 5. Export for Power BI (after ranking columns are added)
  if (!dir.exists("output")) dir.create("output")
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  #fwrite(dt_companies, sprintf("output/companies_for_powerbi_%s.csv", timestamp))
  flog.info("Writing table to companies_powerbi in PostgreSQL...")
  dbWriteTable(con, "companies_powerbi", as.data.frame(dt_companies), overwrite = TRUE)
  flog.info("Table written to companies_powerbi. Ready for Power BI!")

  # Write to a single output file with all ranking columns
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  fwrite(dt_companies, sprintf("output/ranked_companies_all_groups_%s.csv", timestamp))

  # 6. Disconnect
  dbDisconnect(con)
  flog.info("Disconnected from database.")

}, error = function(e) {
  flog.error("Error: %s", e$message)
  stop(e)
}) 

renv::snapshot()