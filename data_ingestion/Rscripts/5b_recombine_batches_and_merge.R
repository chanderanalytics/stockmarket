# 5b_recombine_batches_and_merge.R

library(data.table)
library(DBI)
library(RPostgres)
library(futile.logger)

# Logging setup
log_file <- sprintf("log/5b_recombine_batches_and_merge_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
flog.appender(appender.file(log_file))
flog.info("Starting batch recombination and merge script")

# Reconstruct file lists
batch_price_baseline_files <- list.files("output", pattern = "batch_.*_price_baseline.csv", full.names = TRUE)
batch_volume_baseline_files <- list.files("output", pattern = "batch_.*_volume_baseline.csv", full.names = TRUE)
batch_price_spike_files <- list.files("output", pattern = "batch_.*_price_spike.csv", full.names = TRUE)
batch_volume_spike_files <- list.files("output", pattern = "batch_.*_volume_spike.csv", full.names = TRUE)

flog.info("Found %d price baseline, %d volume baseline, %d price spike, %d volume spike batch files", 
           length(batch_price_baseline_files), length(batch_volume_baseline_files), 
           length(batch_price_spike_files), length(batch_volume_spike_files))

# Recombine
wide_price_baseline <- rbindlist(lapply(batch_price_baseline_files, fread), fill = TRUE)
wide_volume_baseline <- rbindlist(lapply(batch_volume_baseline_files, fread), fill = TRUE)
wide_price_spike <- rbindlist(lapply(batch_price_spike_files, fread), fill = TRUE)
wide_volume_spike <- rbindlist(lapply(batch_volume_spike_files, fread), fill = TRUE)

flog.info("Recombined all batch outputs.")

# Connect to DB and load corp_action_flags
db_con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("PGDATABASE"),
  host = Sys.getenv("PGHOST"),
  port = as.integer(Sys.getenv("PGPORT")),
  user = Sys.getenv("PGUSER"),
  password = Sys.getenv("PGPASSWORD")
)
corp_action_flags <- as.data.table(dbReadTable(db_con, "corp_action_flags"))

# Ensure company_id is character in all tables before merging
corp_action_flags[, company_id := as.character(company_id)]
wide_price_baseline[, company_id := as.character(company_id)]
wide_volume_baseline[, company_id := as.character(company_id)]
wide_price_spike[, company_id := as.character(company_id)]
wide_volume_spike[, company_id := as.character(company_id)]

# Merge and write outputs
merged_price_baseline <- merge(corp_action_flags, wide_price_baseline, by = "company_id", all.x = TRUE)
flog.info("Merged price baseline with corporate action flags.")
prob_cols <- grep("^price_return", names(merged_price_baseline), value = TRUE)
for (col in prob_cols) {
  non_nulls <- sum(!is.na(merged_price_baseline[[col]]))
  nulls <- sum(is.na(merged_price_baseline[[col]]))
  flog.info("%s: non-NULL=%d, NULL=%d", col, non_nulls, nulls)
}
dbWriteTable(
  db_con,
  "merged_price_baseline_probabilities_wide",
  as.data.frame(merged_price_baseline),
  overwrite = TRUE
)
fwrite(wide_price_baseline, "output/price_baseline_probabilities_wide.csv")

merged_volume_baseline <- merge(corp_action_flags, wide_volume_baseline, by = "company_id", all.x = TRUE)
flog.info("Merged volume baseline with corporate action flags.")
prob_cols <- grep("^volume_change", names(merged_volume_baseline), value = TRUE)
for (col in prob_cols) {
  non_nulls <- sum(!is.na(merged_volume_baseline[[col]]))
  nulls <- sum(is.na(merged_volume_baseline[[col]]))
  flog.info("%s: non-NULL=%d, NULL=%d", col, non_nulls, nulls)
}
dbWriteTable(
  db_con,
  "merged_volume_baseline_probabilities_wide",
  as.data.frame(merged_volume_baseline),
  overwrite = TRUE
)
fwrite(wide_volume_baseline, "output/volume_baseline_probabilities_wide.csv")

merged_price_spike <- merge(corp_action_flags, wide_price_spike, by = "company_id", all.x = TRUE)
flog.info("Merged price spike with corporate action flags.")
prob_cols <- grep("^price_spike", names(merged_price_spike), value = TRUE)
for (col in prob_cols) {
  non_nulls <- sum(!is.na(merged_price_spike[[col]]))
  nulls <- sum(is.na(merged_price_spike[[col]]))
  flog.info("%s: non-NULL=%d, NULL=%d", col, non_nulls, nulls)
}
dbWriteTable(
  db_con,
  "merged_price_spike_probabilities_wide",
  as.data.frame(merged_price_spike),
  overwrite = TRUE
)
fwrite(wide_price_spike, "output/price_spike_probabilities_wide.csv")

merged_volume_spike <- merge(corp_action_flags, wide_volume_spike, by = "company_id", all.x = TRUE)
flog.info("Merged volume spike with corporate action flags.")
prob_cols <- grep("^volume_spike", names(merged_volume_spike), value = TRUE)
for (col in prob_cols) {
  non_nulls <- sum(!is.na(merged_volume_spike[[col]]))
  nulls <- sum(is.na(merged_volume_spike[[col]]))
  flog.info("%s: non-NULL=%d, NULL=%d", col, non_nulls, nulls)
}
dbWriteTable(
  db_con,
  "merged_volume_spike_probabilities_wide",
  as.data.frame(merged_volume_spike),
  overwrite = TRUE
)
fwrite(wide_volume_spike, "output/volume_spike_probabilities_wide.csv")

# Clean up
dbDisconnect(db_con)
flog.info("All requested wide tables written to CSV and database. Script complete.") 