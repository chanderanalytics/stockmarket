# 4_corporate_action_flags.R
# This script joins the output of 3_companies_prices_features.R (now in a DB table) with corporate action flags/types.
# Output: wide table, one row per company, with all features and corporate action columns, written to a DB table.

source("data_ingestion/Rscripts/0_setup_renv.R")

# --- LOGGING SETUP ---
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- sprintf("log/4_corporate_action_flags_%s.log", timestamp)
flog.appender(appender.tee(log_file))
flog.threshold(INFO)

flog.info("Starting 4_corporate_action_flags.R script...")

# --- CONFIG ---
# Database connection parameters from environment variables (see .Renviron)
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("PGDATABASE"),
  host = Sys.getenv("PGHOST"),
  port = as.integer(Sys.getenv("PGPORT")),
  user = Sys.getenv("PGUSER"),
  password = Sys.getenv("PGPASSWORD")
)

features_table <- "companies_with_price_features"  # Input table from script 3
actions_table <- "corporate_actions"                # Read directly from DB
output_table <- "corp_action_flags"
output_file <- sprintf("output/corp_action_flags_%s.csv", timestamp)
N <- 30  # Number of days for recent corporate action window

# --- LOAD DATA ---
flog.info("Loading features from table: %s", features_table)
features <- as.data.table(dbReadTable(con, features_table))  # Should have columns: id, ...
setnames(features, "id", "company_id")
features[, company_id := as.character(company_id)]
flog.info("Loaded %d companies/features from %s", nrow(features), features_table)
flog.info("Loading corporate actions from table: %s", actions_table)
actions <- as.data.table(dbGetQuery(con, "SELECT company_id, date, type FROM corporate_actions"))
actions[, company_id := as.character(company_id)]
flog.info("Loaded %d corporate actions from %s", nrow(actions), actions_table)

# If features has a date column, ensure it's Date type (for future-proofing)
if ("date" %in% names(features)) features[, date := as.Date(date)]
actions[, date := as.Date(date)]

# --- Aggregate corporate actions per company ---
flog.info("Aggregating corporate actions per company...")
actions_agg <- actions[, .(
  has_corporate_action = .N > 0,
  corporate_action_types = paste(unique(type), collapse = ",")
), by = company_id]
flog.info("Companies with any corporate action: %d", sum(actions_agg$has_corporate_action, na.rm=TRUE))

# --- (Optional) For recent corporate action in last N days (e.g., 30) ---
get_recent_types <- function(cc) {
  types <- actions[company_id == cc & date >= (Sys.Date() - N), unique(type)]
  if (length(types) == 0) return(NA_character_)
  paste(types, collapse = ",")
}

flog.info("Calculating recent corporate action types for each company...")
actions_agg[, recent_corporate_action_types := get_recent_types(company_id), by = company_id]
actions_agg[, has_recent_corporate_action := !is.na(recent_corporate_action_types)]
flog.info("Companies with recent corporate action: %d", sum(actions_agg$has_recent_corporate_action, na.rm=TRUE))

# --- Join features and corporate action flags ---
flog.info("Merging features and corporate action flags...")
final <- merge(features, actions_agg, by = "company_id", all.x = TRUE)
if ("has_corporate_action" %in% names(final)) {
  final[is.na(has_corporate_action), has_corporate_action := 0]
  final[, has_corporate_action := as.integer(has_corporate_action)]
  print(table(final$has_corporate_action, useNA="always"))
  print(str(final$has_corporate_action))
}
flog.info("Final output row count: %d", nrow(final))

# --- SAVE RESULT TO DATABASE ---
flog.info("Writing result to database table: %s", output_table)
dbWriteTable(con, output_table, final, overwrite = TRUE)

# Log record counts in the final table
flog.info("Total records in final table: %d", nrow(final))
if ("has_corporate_action" %in% names(final)) {
  flog.info("Companies with any corporate action: %d", sum(final$has_corporate_action, na.rm=TRUE))
}
if ("corporate_action_types" %in% names(final)) {
  action_type_counts <- table(unlist(strsplit(na.omit(final$corporate_action_types), ",")))
  for (type in names(action_type_counts)) {
    flog.info("Companies with action type '%s': %d", type, action_type_counts[[type]])
  }
}

# --- (Optional) SAVE RESULT TO CSV ---
flog.info("Writing result to CSV: %s", output_file)
fwrite(final, output_file)

flog.info("Corporate action flags and types joined. Output written to DB table: %s", output_table)
dbDisconnect(con)
flog.info("Script completed successfully.")