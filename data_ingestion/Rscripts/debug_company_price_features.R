# debug_company_price_features.R

library(DBI)
library(RPostgres)
library(data.table)
library(zoo)

# Connect to DB
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("PGDATABASE"),
  host = Sys.getenv("PGHOST", "localhost"),
  port = as.integer(Sys.getenv("PGPORT", "5432")),
  user = Sys.getenv("PGUSER"),
  password = Sys.getenv("PGPASSWORD")
)

companies_dt <- as.data.table(dbGetQuery(con, "SELECT * FROM companies"))
prices_dt <- as.data.table(dbGetQuery(con, "SELECT * FROM prices"))

# Ensure id and company_id are the same type
companies_dt[, id := as.character(id)]
prices_dt[, company_id := as.character(company_id)]

# Join tables
joined_dt <- merge(prices_dt, companies_dt, by.x = "company_id", by.y = "id", all.x = TRUE)
cat("Rows in joined table:", nrow(joined_dt), "\n")

# Find a company_id that is present in both tables and has price data
company_ids_with_prices <- intersect(companies_dt$id, prices_dt$company_id)
one_company_id <- company_ids_with_prices[1]  # or sample(company_ids_with_prices, 1)

# Filter the joined table for this company
one_company_dt <- joined_dt[company_id == one_company_id][order(date)]

cat("Selected company_id with price data:", one_company_id, "\n")
cat("Number of price records for this company:", nrow(one_company_dt), "\n")
print(head(one_company_dt))

# Calculate simple price changes for this company
lags <- c(1, 2, 3, 21)
latest_close <- one_company_dt[.N, close]
for (lag in lags) {
  if (nrow(one_company_dt) > lag) {
    past_close <- one_company_dt[.N - lag, close]
    change <- (latest_close - past_close) / past_close
    cat(sprintf("Price change %dd: %.2f%%\n", lag, change * 100))
  } else {
    cat(sprintf("Price change %dd: NA (not enough data)\n", lag))
  }
}

dbDisconnect(con) 