source("data_ingestion/Rscripts/setup_renv.R")


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
  setnames(bse_map, old = col_names, new = c(paste0(gsub(" ", "_", col_names), "_bse"))

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
    labels = paste0("Decile ", 1:10),
    include.lowest = TRUE
  )]
  flog.info("Added decile-based market cap classification.")

  # Sector/Industry Averages
  sector_stats <- dt_companies[, .(
    sector_avg_roe = mean(roe, na.rm=TRUE),
    sector_avg_pe = mean(pe_ratio, na.rm=TRUE),
    sector_avg_market_capitalization = mean(market_capitalization, na.rm=TRUE)
  ), by = sector]
  dt_companies <- merge(dt_companies, sector_stats, by = "sector", all.x = TRUE)
  flog.info("Added sector/industry averages.")

  # Z-scores for ROE and PE
  dt_companies[, z_roe := (roe - mean(roe, na.rm=TRUE)) / sd(roe, na.rm=TRUE)]
  dt_companies[, z_pe := (pe_ratio - mean(pe_ratio, na.rm=TRUE)) / sd(pe_ratio, na.rm=TRUE)]
  flog.info("Added z-scores for ROE and PE.")

  # Ranking within sector
  dt_companies[, roe_rank := frank(-roe, ties.method="min"), by = sector]
  dt_companies[, pe_rank := frank(pe_ratio, ties.method="min"), by = sector]
  dt_companies[, market_capitalization_rank := frank(-market_capitalization, ties.method="min"), by = sector]
  flog.info("Added sector-wise rankings.")

  # Composite Value Score (example: high ROE, low PE)
  dt_companies[, value_score := scale(-pe_ratio) + scale(roe)]
  flog.info("Added composite value score.")

  # Outlier flag for PE and ROE
  dt_companies[, pe_outlier := abs(z_pe) > 3]
  dt_companies[, roe_outlier := abs(z_roe) > 3]
  flog.info("Added outlier flags for PE and ROE.")

  # 5. Export for Power BI
  if (!dir.exists("output")) dir.create("output")
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  #fwrite(dt_companies, sprintf("output/companies_for_powerbi_%s.csv", timestamp))
  flog.info("Writing table to companies_powerbi in PostgreSQL...")
  dbWriteTable(con, "companies_powerbi", as.data.frame(dt_companies), overwrite = TRUE)
  flog.info("Table written to companies_powerbi. Ready for Power BI!")

  # 6. Disconnect
  dbDisconnect(con)
  flog.info("Disconnected from database.")

}, error = function(e) {
  flog.error("Error: %s", e$message)
  stop(e)
}) 

renv::snapshot()