source("data_ingestion/Rscripts/0_setup_renv.R")


log_file <- sprintf("log/companies_insights_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
flog.appender(appender.file(log_file))

flog.info("Starting companies insights script")

# ---
# Database credentials are now read from environment variables.
# Set these in your shell, .Renviron, or with the dotenv package:
# PGUSER=stockuser
# PGPASSWORD=stockpass
# PGHOST=localhost
# PGPORT=5432
# PGDATABASE=stockdb
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
  
  # Map BSE sector/industry using BSE code
  bse_map <- fread("/Users/chanderbhushan/stockmkt/data/BSE_Sector_Mapping.csv")
  # Read only the header (first row) of the CSV to get column names
  col_names <- names(bse_map)
  print(col_names)
  # Rename columns to have _bse suffix and replace dots with underscores
  setnames(bse_map, old = col_names, new = paste0(gsub(" ", "_", tolower(col_names)), "_bse"))

# Ensure both columns are integer type for merge (in both data.tables)
dt_companies[, bse_code := as.integer(bse_code)]
bse_map[, security_code_bse := as.integer(security_code_bse)]

# Print types for debugging
cat("Type of companies_dt$bse_code:", class(dt_companies$bse_code), "\n")
cat("Type of bse_map$security_code_bse:", class(bse_map$security_code_bse), "\n")


dt_companies <- merge(
    dt_companies,
    bse_map,
    by.x = "bse_code",
    by.y = "security_code_bse",
    all.x = TRUE
  )
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
  dt_companies[, mcap_decile := cut(
    rank(-market_capitalization, ties.method = "min"),
    breaks = quantile(rank(-market_capitalization, ties.method = "min"), probs = seq(0, 1, 0.1), na.rm = TRUE),
    labels = as.character(1:10),
    include.lowest = TRUE
  )]
  flog.info("Added decile-based market cap classification.")

  

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