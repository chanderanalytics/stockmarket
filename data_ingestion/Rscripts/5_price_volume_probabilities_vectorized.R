# 5_price_volume_probabilities_vectorized.R

source("data_ingestion/Rscripts/0_setup_renv.R")

start_time <- Sys.time()

flog.appender(appender.file(sprintf("log/price_volume_probabilities_vectorized_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))))
flog.info("Starting vectorized price and volume probability calculation script")

# Database connection details
user <- Sys.getenv("PGUSER")
password <- Sys.getenv("PGPASSWORD")
host <- Sys.getenv("PGHOST", "localhost")
port <- as.integer(Sys.getenv("PGPORT", "5432"))
dbname <- Sys.getenv("PGDATABASE", "stockdb")

# Connect to PostgreSQL
flog.info("Connecting to database...")
db_con <- dbConnect(
  RPostgres::Postgres(),
  dbname = dbname,
  host = host,
  port = port,
  user = user,
  password = password
)

# Load prices table
flog.info("Loading prices table from database...")
db_query <- "SELECT company_id, date, adj_close, volume FROM prices"
prices_dt <- as.data.table(dbGetQuery(db_con, db_query))
prices_dt[, date := as.Date(date)]
prices_dt[, company_id := as.character(company_id)]
flog.info("Loaded %d price records for %d companies", nrow(prices_dt), length(unique(prices_dt$company_id)))

# Load corp_action_flags table from script 4
corp_action_flags <- as.data.table(dbReadTable(db_con, "corp_action_flags"))
corp_action_flags[, company_id := as.character(company_id)]

# Parameters
periods <- c(3, 7, 10, 15, 30)
price_thresholds <- c(0.03, 0.05, 0.07, 0.10, 0.15)
volume_thresholds <- c(0.10, 0.30, 0.50, 1.00)
rolling_windows <- c(3, 7, 10, 15, 30)
volume_spike_multiples <- c(1, 1.5, 2, 3)
price_spike_multiples <- c(1, 1.5, 2, 3)

setorder(prices_dt, company_id, date)

# Filter out non-positive or NA adj_close to avoid log() warnings
prices_dt[adj_close <= 0 | is.na(adj_close), adj_close := NA]

# Batching setup
batch_size <- 500
unique_companies <- unique(prices_dt$company_id)
n_batches <- ceiling(length(unique_companies) / batch_size)

# Prepare temp file lists
batch_price_baseline_files <- c()
batch_volume_baseline_files <- c()
batch_price_spike_files <- c()
batch_volume_spike_files <- c()

for (batch_idx in seq_len(n_batches)) {
  batch_start <- (batch_idx - 1) * batch_size + 1
  batch_end <- min(batch_idx * batch_size, length(unique_companies))
  batch_companies <- unique_companies[batch_start:batch_end]
  flog.info("Processing batch %d/%d: companies %d to %d", batch_idx, n_batches, batch_start, batch_end)
  batch_prices <- prices_dt[company_id %in% batch_companies]

  # --- Begin original calculations, but on batch_prices ---
  # Calculate returns and volume changes for all periods
  for (p in periods) {
    batch_prices[, paste0("return_", p) := shift(adj_close, -p, type = "lead") / adj_close - 1, by = company_id]
    batch_prices[, paste0("volchg_", p) := shift(volume, -p, type = "lead") / volume - 1, by = company_id]
  }

  # Melt to long format for thresholding
  returns_long <- melt(
    batch_prices,
    id.vars = c("company_id", "date"),
    measure.vars = patterns("^return_"),
    variable.name = "period",
    value.name = "return"
  )
  returns_long[, period := as.integer(gsub("return_", "", period))]

  volchg_long <- melt(
    batch_prices,
    id.vars = c("company_id", "date"),
    measure.vars = patterns("^volchg_"),
    variable.name = "period",
    value.name = "volchg"
  )
  volchg_long[, period := as.integer(gsub("volchg_", "", period))]

  # Price return probabilities
  price_probs <- returns_long[, {
    lapply(price_thresholds, function(th) mean(return >= th, na.rm = TRUE))
  }, by = .(company_id, period)]
  setnames(price_probs, paste0("V", seq_along(price_thresholds)), paste0("prob_", price_thresholds))
  price_probs <- melt(price_probs, id.vars = c("company_id", "period"), variable.name = "threshold", value.name = "probability")
  price_probs[, threshold := as.numeric(gsub("prob_", "", threshold))]

  # Volume change probabilities
  volume_probs <- volchg_long[, {
    lapply(volume_thresholds, function(th) mean(volchg >= th, na.rm = TRUE))
  }, by = .(company_id, period)]
  setnames(volume_probs, paste0("V", seq_along(volume_thresholds)), paste0("prob_", volume_thresholds))
  volume_probs <- melt(volume_probs, id.vars = c("company_id", "period"), variable.name = "threshold", value.name = "probability")
  volume_probs[, threshold := as.numeric(gsub("prob_", "", threshold))]

  # Rolling means and SDs for all companies and windows
  for (rw in rolling_windows) {
    batch_prices[, paste0("rollmean_vol_", rw) := frollmean(volume, rw, align = "right"), by = company_id]
    batch_prices[, paste0("rollsd_ret_", rw) := frollapply(c(NA, diff(log(adj_close))), rw, sd, align = "right", fill = NA), by = company_id]
  }

  # Price spike probabilities
  for (rw in rolling_windows) {
    for (mult in price_spike_multiples) {
      for (p in periods) {
        batch_prices[, paste0("price_spike_", mult, "x_", rw, "dsd_", p) := {
          price_return <- (shift(adj_close, -p, type = "lead") - adj_close) / adj_close
          rolling_sd <- shift(get(paste0("rollsd_ret_", rw)), -p, type = "lead")
          as.numeric(abs(price_return) > mult * rolling_sd)
        }, by = company_id]
      }
    }
  }

  # Volume spike probabilities
  for (rw in rolling_windows) {
    for (mult in volume_spike_multiples) {
      for (p in periods) {
        batch_prices[, paste0("volume_spike_", mult, "x_", rw, "davg_", p) := {
          future_vol <- shift(volume, -p, type = "lead")
          rolling_avg_vol <- shift(get(paste0("rollmean_vol_", rw)), -p, type = "lead")
          as.numeric(future_vol > mult * rolling_avg_vol)
        }, by = company_id]
      }
    }
  }

  # Melt and calculate spike probabilities
  price_spike_cols <- grep("^price_spike_", names(batch_prices), value = TRUE)
  price_spike_long <- melt(batch_prices, id.vars = "company_id", measure.vars = price_spike_cols, variable.name = "metric", value.name = "spike")
  price_spike_probs <- price_spike_long[, .(probability = mean(spike, na.rm = TRUE)), by = .(company_id, metric)]
  wide_price_spike <- dcast(price_spike_probs, company_id ~ metric, value.var = "probability")

  volume_spike_cols <- grep("^volume_spike_", names(batch_prices), value = TRUE)
  volume_spike_long <- melt(batch_prices, id.vars = "company_id", measure.vars = volume_spike_cols, variable.name = "metric", value.name = "spike")
  volume_spike_probs <- volume_spike_long[, .(probability = mean(spike, na.rm = TRUE)), by = .(company_id, metric)]
  wide_volume_spike <- dcast(volume_spike_probs, company_id ~ metric, value.var = "probability")

  # Dcast to wide format for baseline metrics
  price_probs[, col_id := paste0("price_return_", period, "_", threshold)]
  wide_price_baseline <- dcast(price_probs, company_id ~ col_id, value.var = "probability")
  volume_probs[, col_id := paste0("volume_change_", period, "_", threshold)]
  wide_volume_baseline <- dcast(volume_probs, company_id ~ col_id, value.var = "probability")

  # Save batch outputs to temp files
  price_baseline_file <- sprintf("output/batch_%d_price_baseline.csv", batch_idx)
  volume_baseline_file <- sprintf("output/batch_%d_volume_baseline.csv", batch_idx)
  price_spike_file <- sprintf("output/batch_%d_price_spike.csv", batch_idx)
  volume_spike_file <- sprintf("output/batch_%d_volume_spike.csv", batch_idx)
  fwrite(wide_price_baseline, price_baseline_file)
  fwrite(wide_volume_baseline, volume_baseline_file)
  fwrite(wide_price_spike, price_spike_file)
  fwrite(wide_volume_spike, volume_spike_file)
  batch_price_baseline_files <- c(batch_price_baseline_files, price_baseline_file)
  batch_volume_baseline_files <- c(batch_volume_baseline_files, volume_baseline_file)
  batch_price_spike_files <- c(batch_price_spike_files, price_spike_file)
  batch_volume_spike_files <- c(batch_volume_spike_files, volume_spike_file)
  flog.info("Batch %d outputs written.", batch_idx)
}

# Recombine all batches
flog.info("Recombining all batch outputs...")
wide_price_baseline <- rbindlist(lapply(batch_price_baseline_files, fread), fill = TRUE)
wide_volume_baseline <- rbindlist(lapply(batch_volume_baseline_files, fread), fill = TRUE)
wide_price_spike <- rbindlist(lapply(batch_price_spike_files, fread), fill = TRUE)
wide_volume_spike <- rbindlist(lapply(batch_volume_spike_files, fread), fill = TRUE)

# Ensure company_id is character in all tables before merging
corp_action_flags[, company_id := as.character(company_id)]
wide_price_baseline[, company_id := as.character(company_id)]
wide_volume_baseline[, company_id := as.character(company_id)]
wide_price_spike[, company_id := as.character(company_id)]
wide_volume_spike[, company_id := as.character(company_id)]

# Merge with corp_action_flags and write only merged table to DB
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

# Clean up and log

dbDisconnect(db_con)
flog.info("All requested wide tables written to CSV and database. Script complete.")
end_time <- Sys.time()
total_time <- end_time - start_time
flog.info("Total script runtime: %s", total_time)
cat(sprintf("Total script runtime: %s\n", total_time)) 