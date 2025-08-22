# prices_max_min

source("data_ingestion/Rscripts/0_setup_renv.R")

# Load libraries
library(DBI)
library(RPostgres)
library(data.table)
library(futile.logger)


# Set up logging
log_file <- sprintf("log/prices_max_min_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
flog.appender(appender.file(log_file))
flog.info("Starting prices max min script")

# Load credentials from environment variables
user <- Sys.getenv("PGUSER")
password <- Sys.getenv("PGPASSWORD")
host <- Sys.getenv("PGHOST", "localhost")
port <- as.integer(Sys.getenv("PGPORT", "5432"))
dbname <- Sys.getenv("PGDATABASE", "stockdb")

# Connect to PostgreSQL
db_con <- dbConnect(
  RPostgres::Postgres(),
  dbname = dbname,
  host = host,
  port = port,
  user = user,
  password = password
)

  prices_dt <- as.data.table(dbGetQuery(db_con, "SELECT * FROM prices"))
  prices_dt[, date := as.Date(date)]
  setorder(prices_dt, company_name, -date)
  prices_dt[, row_num := seq_len(.N), by = company_name]
  prices_dt[, max_price_historical:= max(adj_close), by="company_name"]
  prices_dt[, min_price_historical:= min(adj_close), by="company_name"]
  prices_dt[, cmp_from_max:= (max_price_historical - adj_close) / adj_close, by="company_name"]
  prices_dt[, cmp_from_min:= (adj_close - min_price_historical) / min_price_historical, by="company_name"]
  prices_dt[, max_date := date[which.max(adj_close)], by = company_name]
  prices_dt[, min_date := date[which.min(adj_close)], by = company_name]
  prices_dt <- prices_dt[row_num==1,]

# Write to database
dbWriteTable(db_con, "prices_max_min", as.data.frame(prices_dt), overwrite = TRUE)

flog.info("Results written to database table")


  # Disconnect
  dbDisconnect(db_con)
  flog.info("Disconnected from database. Script complete.")

