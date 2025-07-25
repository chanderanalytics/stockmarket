
source("data_ingestion/Rscripts/0_setup_renv.R")

start_time <- Sys.time()

flog.appender(appender.file(sprintf("log/price_volume_probabilities_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))) )
flog.info("Starting price and volume probability calculation script")

# Database connection details (adjust as needed)
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

# Example periods and thresholds
periods <- c(3, 7, 10, 15, 30)
price_thresholds <- c(0.03, 0.05, 0.07, 0.10, 0.15)
volume_thresholds <- c(0.10, 0.30, 0.50, 1.00)

rolling_windows <- c(3, 7, 10, 15, 30)
volume_spike_multiples <- c(1, 1.5, 2, 3)
price_spike_multiples <- c(1, 1.5, 2, 3)

results <- list()
flog.info("Starting probability calculations...")

company_ids <- unique(prices_dt$company_id)
for (i in seq_along(company_ids)) {
  cid <- company_ids[i]
  if (i %% 100 == 0) {
    flog.info("Processed %d/%d companies (%.1f%%)", i, length(company_ids), 100 * i / length(company_ids))
  }
  dtc <- prices_dt[company_id == cid][order(date)]
  dtc[, daily_return := c(NA, diff(log(adj_close)))]
  for (p in periods) {
    # Price returns
    returns <- (shift(dtc$adj_close, -p, type = "lead") - dtc$adj_close) / dtc$adj_close
    # Volume change
    vol_chg <- (shift(dtc$volume, -p, type = "lead") - dtc$volume) / dtc$volume

    for (th in price_thresholds) {
      prob <- mean(returns >= th, na.rm = TRUE)
      results[[length(results) + 1]] <- data.table(
        company_id = cid,
        metric = "price_return",
        period = p,
        threshold = th,
        probability = prob
      )
    }
    for (vth in volume_thresholds) {
      prob_vol <- mean(vol_chg >= vth, na.rm = TRUE)
      results[[length(results) + 1]] <- data.table(
        company_id = cid,
        metric = "volume_change",
        period = p,
        threshold = vth,
        probability = prob_vol
      )
    }
    # Volume and price spikes for multiple rolling windows and multiples
    for (rw in rolling_windows) {
      rolling_avg_vol <- frollmean(dtc$volume, rw, align = "right")
      for (mult in volume_spike_multiples) {
        spike <- shift(dtc$volume, -p, type = "lead") > mult * shift(rolling_avg_vol, -p, type = "lead")
        prob_spike <- mean(spike, na.rm = TRUE)
        results[[length(results) + 1]] <- data.table(
          company_id = cid,
          metric = paste0("volume_spike_", mult, "x_", rw, "davg"),
          period = p,
          probability = prob_spike
        )
      }
      rolling_sd <- frollapply(dtc$daily_return, rw, sd, align = "right", fill = NA)
      price_return <- (shift(dtc$adj_close, -p, type = "lead") - dtc$adj_close) / dtc$adj_close
      for (mult in price_spike_multiples) {
        spike <- abs(price_return) > mult * shift(rolling_sd, -p, type = "lead")
        prob_spike <- mean(spike, na.rm = TRUE)
        results[[length(results) + 1]] <- data.table(
          company_id = cid,
          metric = paste0("price_spike_", mult, "x_", rw, "dsd"),
          period = p,
          probability = prob_spike
        )
      }
    }
  }
}
final_probs <- rbindlist(results, fill = TRUE)
flog.info("Probability calculation complete. Writing output...")

# --- Only create four wide tables: price/volume baseline and price/volume spike ---

# Load corp_action_flags table from script 4
corp_action_flags <- as.data.table(dbReadTable(db_con, "corp_action_flags"))
corp_action_flags[, company_id := as.character(company_id)]

# Baseline (non-spike) metrics
baseline_probs <- final_probs[!grepl("spike", metric)]

# Price baseline
price_baseline <- baseline_probs[metric == "price_return"]
price_baseline[, col_id := paste(metric, period, threshold, sep = "_")]
wide_price_baseline <- dcast(price_baseline, company_id ~ col_id, value.var = "probability")
fwrite(wide_price_baseline, "output/price_baseline_probabilities_wide.csv")
# Merge with corp_action_flags and write only merged table to DB
merged_price_baseline <- merge(corp_action_flags, wide_price_baseline, by = "company_id", all.x = TRUE)
# Log null/non-null counts for probability columns
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
flog.info("Wrote merged_price_baseline_probabilities_wide to CSV and database.")

# Volume baseline
volume_baseline <- baseline_probs[metric == "volume_change"]
volume_baseline[, col_id := paste(metric, period, threshold, sep = "_")]
wide_volume_baseline <- dcast(volume_baseline, company_id ~ col_id, value.var = "probability")
fwrite(wide_volume_baseline, "output/volume_baseline_probabilities_wide.csv")
merged_volume_baseline <- merge(corp_action_flags, wide_volume_baseline, by = "company_id", all.x = TRUE)
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
flog.info("Wrote merged_volume_baseline_probabilities_wide to CSV and database.")

# Spike metrics
spike_probs <- final_probs[grepl("spike", metric)]

# Price spike
price_spike_probs <- spike_probs[grepl("price_spike", metric)]
price_spike_probs[, col_id := paste(metric, period, sep = "_")]
wide_price_spike <- dcast(price_spike_probs, company_id ~ col_id, value.var = "probability")
fwrite(wide_price_spike, "output/price_spike_probabilities_wide.csv")
merged_price_spike <- merge(corp_action_flags, wide_price_spike, by = "company_id", all.x = TRUE)
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
flog.info("Wrote merged_price_spike_probabilities_wide to CSV and database.")

# Volume spike
volume_spike_probs <- spike_probs[grepl("volume_spike", metric)]
volume_spike_probs[, col_id := paste(metric, period, sep = "_")]
wide_volume_spike <- dcast(volume_spike_probs, company_id ~ col_id, value.var = "probability")
fwrite(wide_volume_spike, "output/volume_spike_probabilities_wide.csv")
merged_volume_spike <- merge(corp_action_flags, wide_volume_spike, by = "company_id", all.x = TRUE)
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
flog.info("Wrote merged_volume_spike_probabilities_wide to CSV and database.")

# --- End of wide table creation ---

# Clean up and log

dbDisconnect(db_con)
flog.info("All requested wide tables written to CSV and database. Script complete.")
end_time <- Sys.time()
total_time <- end_time - start_time
flog.info("Total script runtime: %s", total_time)
cat(sprintf("Total script runtime: %s\n", total_time)) 