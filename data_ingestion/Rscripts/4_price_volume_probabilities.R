library(DBI)
library(RPostgres)
library(data.table)
library(futile.logger)

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

company_ids <- unique(prices_dt$company_id)[1:200]
for (i in seq_along(company_ids)) {
  cid <- company_ids[i]
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
  if (i %% 100 == 0) flog.info("Processed %d companies", i)
}
final_probs <- rbindlist(results, fill = TRUE)
flog.info("Probability calculation complete. Writing output...")

# Save only baseline (non-spike) metrics for main CSV/table
baseline_probs <- final_probs[!grepl("spike", metric)]
fwrite(baseline_probs, "output/price_volume_probabilities.csv")
dbWriteTable(
  db_con,
  "price_volume_probabilities",
  as.data.frame(baseline_probs),
  overwrite = TRUE
)

# Wide format for baseline (non-spike) metrics
baseline_probs[, col_id := paste(metric, period, threshold, sep = "_")]
wide_baseline_probs <- dcast(baseline_probs, company_id ~ col_id, value.var = "probability")
fwrite(wide_baseline_probs, "output/price_volume_probabilities_wide.csv")
dbWriteTable(
  db_con,
  "price_volume_probabilities_wide",
  as.data.frame(wide_baseline_probs),
  overwrite = TRUE
)

# --- Create and write spike/outlier table ---
spike_probs <- final_probs[grepl("spike", metric)]
spike_probs[, threshold := NULL]
fwrite(spike_probs, "output/price_volume_spike_probabilities.csv")

# Wide format for spike/outlier probabilities
spike_probs[, col_id := paste(metric, period, sep = "_")]
wide_spike_probs <- dcast(spike_probs, company_id ~ col_id, value.var = "probability")
fwrite(wide_spike_probs, "output/price_volume_spike_probabilities_wide.csv")
dbWriteTable(
  db_con,
  "price_volume_spike_probabilities_wide",
  as.data.frame(wide_spike_probs),
  overwrite = TRUE
)

# For price and volume spike only tables:
price_spike_probs <- spike_probs[grepl("price_spike", metric)]
volume_spike_probs <- spike_probs[grepl("volume_spike", metric)]

dbDisconnect(db_con)
flog.info("Wide, spike, and main tables written to CSV and database.")

end_time <- Sys.time()
total_time <- end_time - start_time
flog.info("Total script runtime: %s", total_time)
cat(sprintf("Total script runtime: %s\n", total_time))

flog.info("Script complete. Output written to CSV and database.") 