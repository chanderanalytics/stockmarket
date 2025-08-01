# dq_check_companies.R

source("data_ingestion/Rscripts/0_setup_renv.R")


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

# Load companies table
companies_df <- dbGetQuery(db_con, "SELECT * FROM companies")

# Map BSE sector/industry using BSE code
companies_dt <- as.data.table(companies_df)
bse_map <- fread("data/BSE_Sector_Mapping.csv")
# Clean column names: replace spaces with underscores and add _bse suffix
col_names <- names(bse_map)
setnames(bse_map, old = col_names, new = paste0(gsub(" ", "_", tolower(col_names)), "_bse"))
# Print new column names for verification
print(names(bse_map))

# Ensure both columns are integer type for merge (in both data.tables)
companies_dt[, bse_code := as.integer(bse_code)]
bse_map[, security_code_bse := as.integer(security_code_bse)]

# Print types for debugging
cat("Type of companies_dt$bse_code:", class(companies_dt$bse_code), "\n")
cat("Type of bse_map$security_code_bse:", class(bse_map$security_code_bse), "\n")

# Merge on bse_code (companies) and security_code_bse (mapping)
companies_dt <- merge(
  companies_dt,
  bse_map,
  by.x = "bse_code",
  by.y = "security_code_bse",
  all.x = TRUE
)

# DQ summary
dq_summary <- data.frame(
  column = colnames(companies_dt),
  n_missing = sapply(companies_dt, function(x) sum(is.na(x))),
  n_unique = sapply(companies_dt, function(x) length(unique(x))),
  class = sapply(companies_dt, class),
  stringsAsFactors = FALSE
)
# Add percentage missing column
n_rows <- nrow(companies_dt)
dq_summary$perc_missing <- ifelse(n_rows > 0, round(100 * dq_summary$n_missing / n_rows, 2), NA)

# Zero/negative values for numeric columns
numeric_cols <- sapply(companies_dt, is.numeric)

if (any(numeric_cols)) {
  dq_summary$zero_or_negative <- NA
  numeric_colnames <- names(companies_dt)[numeric_cols]
  dq_summary$zero_or_negative[numeric_cols] <- sapply(companies_dt[, ..numeric_colnames], function(x) sum(x <= 0, na.rm=TRUE))
}

# Print DQ summary
print(dq_summary)

# Write DQ summary to CSV with datetime stamp
if (!dir.exists("output")) dir.create("output")
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
output_file <- sprintf("output/dq_summary_companies_%s.csv", timestamp)
write.csv(dq_summary, output_file, row.names = FALSE)

# Duplicate row check
n_duplicates <- nrow(companies_dt) - nrow(unique(companies_dt))
cat("Number of duplicate rows:", n_duplicates, "\n")

# Duplicate key check (if you have a primary key, e.g., company_id)
if ("company_id" %in% colnames(companies_dt)) {
  n_dup_keys <- sum(duplicated(companies_dt$company_id))
  cat("Number of duplicate company_id values:", n_dup_keys, "\n")
}

# Disconnect
dbDisconnect(db_con) 
