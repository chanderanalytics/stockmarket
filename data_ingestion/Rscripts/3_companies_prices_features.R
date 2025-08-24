# 3_companies_prices_features.R

source("data_ingestion/Rscripts/0_setup_renv.R")
test_n <- NA  # Set to NA to process all companies, or to a number for testing (e.g., 10)

# Set up logging
log_file <- sprintf("log/companies_prices_features_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
flog.appender(appender.file(log_file))
flog.info("Starting companies prices features script")

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

# --- CONFIG ---
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("PGDATABASE"),
  host = Sys.getenv("PGHOST"),
  port = as.integer(Sys.getenv("PGPORT")),
  user = Sys.getenv("PGUSER"),
  password = Sys.getenv("PGPASSWORD")
)

companies <- as.data.table(dbReadTable(con, "companies"))
prices <- as.data.table(dbReadTable(con, "prices"))
today <- Sys.Date()

# Allow override of 'today' via command-line argument
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0 && grepl("^\\d{4}-\\d{2}-\\d{2}$", args[1])) {
  today <- as.Date(args[1])
} else {
  today <- Sys.Date()
}
cat(sprintf("[INFO] Using 'today' as: %s\n", as.character(today)))
# Allow override of test_n via second command-line argument
if (length(args) > 1 && !is.na(as.numeric(args[2]))) {
  test_n <- as.numeric(args[2])
  cat(sprintf("[INFO] Using test_n: %d\n", test_n))
}

# Use reference date for all operations
ref_date <- today  # Store the reference date
cat(sprintf("[DEBUG] Using reference date: %s\n", as.character(ref_date)))

# For each company, if no price for reference date, insert from current_price
for (i in 1:nrow(companies)) {
  code <- companies$company_code[i]
  cid <- companies$id[i]
  if (length(code) != 1 || is.na(code) || code == "" || length(cid) != 1 || is.na(cid) || cid == "") next
  # Check if there's a price for the reference date
  if (nrow(prices[company_id == cid & date == ref_date]) == 0 && !is.na(companies$current_price[i])) {
    dbExecute(con, sprintf(
      "INSERT INTO prices (company_code, company_id, date, close, last_modified) VALUES ('%s', %d, '%s', %f, '%s')",
      code, cid, ref_date, companies$current_price[i], ref_date
    ))
    cat(sprintf("Inserted today's price from companies table for %s: %f\n", code, companies$current_price[i]))
  }
}

tryCatch({
  flog.info("Loading companies and prices tables from database...")
  # Instead of loading from 'companies', load from 'companies_powerbi' (created by script 2)
  companies_cols <- dbListFields(db_con, "companies_powerbi")
  companies_query <- sprintf("SELECT %s FROM companies_powerbi", paste(sprintf('"%s"', companies_cols), collapse = ", "))
  companies_dt <- as.data.table(dbGetQuery(db_con, companies_query))
  print('Columns in companies_dt:')
  print(names(companies_dt))
  prices_dt <- as.data.table(dbGetQuery(db_con, "SELECT * FROM prices"))
  flog.info("Loaded %d companies and %d price records", nrow(companies_dt), nrow(prices_dt))

  # Ensure date is Date type
  prices_dt[, date := as.Date(date)]
  latest_date <- max(prices_dt$date, na.rm = TRUE)
  flog.info("Latest price date availble (ref date may be diferent): %s", as.character(latest_date))

  # Define lags/periods (in trading days)
  lags <- c(1, 2, 3, 4, 5, 21, 63, 126, 252, 504, 756, 1260, 2520)  # 1d, 2d, 3d, 4d, 1w, 1m, 3m, 6m, 1y, 2y, 3y, 5y, 10y

  # Helper: CAGR
  cagr <- function(start, end, n_years) {
    if (anyNA(c(start, end, n_years))) return(NA)
    if (isTRUE(start <= 0) || isTRUE(end <= 0) || isTRUE(n_years <= 0)) return(NA)
    (end / start)^(1 / n_years) - 1
  }

  # Helper: Max Drawdown
  max_drawdown <- function(prices) {
    if (length(prices) < 2 || all(is.na(prices))) return(NA)
    max_dd <- 0
    peak <- prices[1]
    for (p in prices) {
      if (is.na(p)) next
      if (p > peak) peak <- p
      dd <- (peak - p) / peak
      if (dd > max_dd) max_dd <- dd
    }
    max_dd
  }

  # --- DEBUG LOGIC START ---
  # (Keep this block for troubleshooting, but do not run by default)
  # Find a company_id with the most price records
  # company_counts <- prices_dt[, .N, by = company_id]
  # top_company_id <- company_counts[order(-N)][1, company_id]
  # one_company_dt <- prices_dt[company_id == top_company_id][order(date)]
  # cat("Selected company_id for testing:", top_company_id, "\n")
  # cat("Number of price records for this company:", nrow(one_company_dt), "\n")
  # print(head(one_company_dt))
  # lags <- c(1, 2, 3, 4, 5, 21, 63, 126, 252, 504, 756, 1260, 2520)
  # latest_close <- one_company_dt[.N, close]
  # for (lag in lags) {
  #   if (nrow(one_company_dt) > lag) {
  #     past_close <- one_company_dt[.N - lag, close]
  #     change <- 100 * (latest_close - past_close) / past_close
  #     cat(sprintf("Price change %dd: %.2f%%\n", lag, change))
  #   } else {
  #     cat(sprintf("Price change %dd: NA (not enough data)\n", lag))
  #   }
  # }
  # --- DEBUG LOGIC END ---

  # Ensure id and company_id are the same type (character)
  companies_dt[, id := as.character(id)]
  prices_dt[, company_id := as.character(company_id)]
  # Debug: check ID types and overlap
  cat("class(companies_dt$id):", class(companies_dt$id), "\n")
  cat("class(prices_dt$company_id):", class(prices_dt$company_id), "\n")
  cat("Number of companies in companies_dt:", length(unique(companies_dt$id)), "\n")
  cat("Number of companies in prices_dt for today:", length(unique(prices_dt[date == today, company_id])), "\n")
  cat("Number of overlapping IDs:", length(intersect(unique(companies_dt$id), unique(prices_dt[date == today, company_id]))), "\n")

  # Left join companies to prices on id = company_id
  joined_dt <- merge(companies_dt, prices_dt, by.x = "id", by.y = "company_id", all.x = TRUE)

  # Always use the prices table's volume column for calculations
  if ("volume.y" %in% names(joined_dt)) {
    setnames(joined_dt, "volume.y", "price_volume")
  } else if ("volume" %in% names(joined_dt) && "date" %in% names(joined_dt)) {
    setnames(joined_dt, "volume", "price_volume")
  } else if ("volume.x" %in% names(joined_dt)) {
    setnames(joined_dt, "volume.x", "price_volume")
  }

  # Find top 50 ids by number of price records in joined data
  company_counts <- joined_dt[, .N, by = id][order(-N)]
  top_ids <- company_counts[ , id]  # Process all companies, not just the top 50
  # Filter to only companies with price data for the reference date
  ids_with_data <- unique(prices_dt[date == ref_date, company_id])
  cat(sprintf("[DEBUG] Found %d companies with price data for %s\n", length(ids_with_data), as.character(ref_date)))
  top_ids <- top_ids[top_ids %in% ids_with_data]
  if (!is.na(test_n) && !is.null(test_n)) {
    top_ids <- top_ids[1:min(test_n, length(top_ids))]
  }

  # Print number of rows in companies and prices tables
  # cat(sprintf("Number of rows in companies_dt: %d\n", nrow(companies_dt)))
  # cat(sprintf("Number of rows in prices_dt: %d\n", nrow(prices_dt)))

  # Print number of rows in joined table
  # cat(sprintf("Number of rows in joined_dt: %d\n", nrow(joined_dt)))

  # For the two selected companies, print id, name, nse_code, bse_code, and count of adj_close from joined_dt
  # for (cid in top_ids) {
  #   comp_info <- companies_dt[id == cid]
  #   cname <- comp_info$name[1]
  #   nse_code <- comp_info$nse_code[1]
  #   bse_code <- comp_info$bse_code[1]
  #   adj_close_count <- sum(!is.na(joined_dt[id == cid, adj_close]))
  #   cat(sprintf("Company id: %s, name: %s, nse_code: %s, bse_code: %s, adj_close count: %d\n", cid, cname, nse_code, bse_code, adj_close_count))
  # }

  # Only print volume for company 2277 from both tables
  # cat("Volume in companies_dt for company 2277:\n")
  # print(companies_dt[id == "2277", .(id, name, volume)])

  # cat("Volume in prices_dt for company 2277:\n")
  # print(prices_dt[company_id == "2277", .(company_id, date, volume)])

  # Main feature calculation for top_ids
  features_list <- list()
  # Initialize counters for price source tracking
  adj_close_used <- 0
  close_used <- 0
  current_price_used <- 0
  no_price_available <- 0
  
  for (i in seq_along(top_ids)) {
    cid <- top_ids[i]
    if (i %% 100 == 0) {
      flog.info("Processed %d/%d companies. Current company: %s", i, length(top_ids), cid)
    }
    if (length(cid) != 1 || is.na(cid) || cid == "" || !(cid %in% joined_dt$id)) {
      next  # Skip this company if id is missing or empty
    }
    # Use %in% for all subsetting to avoid length-0 errors
    cname <- joined_dt[id %in% cid, unique(name)][1]
    dt <- joined_dt[id %in% cid][order(date)]
    n_dt <- nrow(dt)
    volume_col <- "price_volume"
    f <- list(id = cid)
    
    # Get reference date price with fallback hierarchy: adj_close → close → current_price
    latest_close <- NA_real_
    price_source <- "none"
    
    # First try to get price for the reference date
    ref_date_row <- dt[date == today]
    if (nrow(ref_date_row) > 0) {
      # Try adj_close first
      if ("adj_close" %in% names(ref_date_row) && !is.na(ref_date_row$adj_close[1])) {
        latest_close <- ref_date_row$adj_close[1]
        price_source <- "adj_close"
        adj_close_used <- adj_close_used + 1
      } else if ("adj_close.x" %in% names(ref_date_row) && !is.na(ref_date_row$adj_close.x[1])) {
        latest_close <- ref_date_row$adj_close.x[1]
        price_source <- "adj_close"
        adj_close_used <- adj_close_used + 1
      }
      # If adj_close not available, try close
      else if ("close" %in% names(ref_date_row) && !is.na(ref_date_row$close[1])) {
        latest_close <- ref_date_row$close[1]
        price_source <- "close"
        close_used <- close_used + 1
      } else if ("close.x" %in% names(ref_date_row) && !is.na(ref_date_row$close.x[1])) {
        latest_close <- ref_date_row$close.x[1]
        price_source <- "close"
        close_used <- close_used + 1
      }
      # If neither adj_close nor close available, try current_price from companies table
      else {
        cp <- if (!is.na(cid) && cid %in% companies_dt$id) companies_dt[id %in% cid, current_price] else NA_real_
        if (!is.na(cp)) {
          latest_close <- cp
          price_source <- "current_price"
          current_price_used <- current_price_used + 1
        } else {
          no_price_available <- no_price_available + 1
        }
      }
    } else {
      # No data for reference date, try current_price from companies table
      cp <- if (!is.na(cid) && cid %in% companies_dt$id) companies_dt[id %in% cid, current_price] else NA_real_
      if (!is.na(cp)) {
        latest_close <- cp
        price_source <- "current_price"
        current_price_used <- current_price_used + 1
      } else {
        no_price_available <- no_price_available + 1
      }
    }
    
    # Volume logic for reference date
    latest_volume <- NA_real_
    if (nrow(ref_date_row) > 0) {
      if (!is.na(volume_col) && !is.na(ref_date_row[[volume_col]][1])) {
        latest_volume <- ref_date_row[[volume_col]][1]
      } else {
        v_comp <- if (!is.na(cid) && cid %in% companies_dt$id) companies_dt[id %in% cid, volume] else NA_real_
        latest_volume <- if (!is.na(v_comp)) v_comp else NA_real_
      }
    } else {
      v_comp <- if (!is.na(cid) && cid %in% companies_dt$id) companies_dt[id %in% cid, volume] else NA_real_
      latest_volume <- if (!is.na(v_comp)) v_comp else NA_real_
    }
    
    f[["latest_close"]] <- latest_close
    f[["latest_volume"]] <- latest_volume
    f[["price_source"]] <- price_source
    for (lag in lags) {
      # Short column names
      pchg_col <- paste0("pchg_", lag, "d")
      pvol_col <- paste0("pvol_", lag, "d")
      phi_col <- paste0("phi_", lag, "d")
      plo_col <- paste0("plo_", lag, "d")
      pdhi_col <- paste0("pdhi_", lag, "d")
      pdlo_col <- paste0("pdlo_", lag, "d")
      vchg_col <- paste0("vchg_", lag, "d")
      vvol_col <- paste0("vvol_", lag, "d")
      vhi_col <- paste0("vhi_", lag, "d")
      vlo_col <- paste0("vlo_", lag, "d")
      vdhi_col <- paste0("vdhi_", lag, "d")
      vdlo_col <- paste0("vdlo_", lag, "d")
      vavg_col <- paste0("vavg_", lag, "d")
      atr_col <- paste0("atr_", lag, "d")
      var_col <- paste0("var_", lag, "d")
      cor_col <- paste0("cor_", lag, "d")
      obv_col <- paste0("obv_", lag, "d")
      vwap_col <- paste0("vwap_", lag, "d")
      
      # Find the reference date position in the dataset
      ref_date_idx <- which(dt$date == today)
      if (length(ref_date_idx) > 0 && !is.na(latest_close)) {
        ref_idx <- ref_date_idx[1]
        
        # Determine which price column to use for historical calculations
        price_col <- if ("adj_close" %in% names(dt)) "adj_close" else if ("adj_close.x" %in% names(dt)) "adj_close.x" else if ("close" %in% names(dt)) "close" else if ("close.x" %in% names(dt)) "close.x" else NA
        
        if (!is.na(price_col) && ref_idx >= lag) {
          if (lag == 1) {
            if (ref_idx > 1) {
              past_close <- dt[ref_idx - 1, get(price_col)]
              f[[pchg_col]] <- 100 * (latest_close - past_close) / past_close
            } else {
              f[[pchg_col]] <- NA_real_
            }
            if ("high" %in% names(dt) && "low" %in% names(dt)) {
              phi <- dt[ref_idx, high]
              plo <- dt[ref_idx, low]
            } else {
              phi <- latest_close
              plo <- latest_close
            }
            f[[phi_col]] <- phi
            f[[plo_col]] <- plo
            f[[pdhi_col]] <- 100 * (latest_close - phi) / phi
            f[[pdlo_col]] <- 100 * (latest_close - plo) / plo
            f[[pvol_col]] <- NA_real_ # Volatility needs more than one return
            # Do not calculate or output any volume or advanced metrics for lag == 1
          } else {
            start_idx <- ref_idx - lag + 1
            if (start_idx >= 1) {
              past_close <- dt[ref_idx - lag, get(price_col)]
              f[[pchg_col]] <- 100 * (latest_close - past_close) / past_close
              period_data <- dt[start_idx:ref_idx]
              period_closes <- period_data[, get(price_col)]
              returns <- diff(log(period_closes))
              f[[pvol_col]] <- 100 * sd(returns, na.rm = TRUE)
              if ("high" %in% names(dt) && "low" %in% names(dt)) {
                phi <- max(period_data$high, na.rm = TRUE)
                plo <- min(period_data$low, na.rm = TRUE)
              } else {
                phi <- max(period_closes, na.rm = TRUE)
                plo <- min(period_closes, na.rm = TRUE)
              }
              f[[phi_col]] <- phi
              f[[plo_col]] <- plo
              f[[pdhi_col]] <- 100 * (latest_close - phi) / phi
              f[[pdlo_col]] <- 100 * (latest_close - plo) / plo
              # Volume metrics
              past_volume <- dt[ref_idx - lag, get(volume_col)]
              period_volumes <- dt[start_idx:ref_idx, get(volume_col)]
              vhi <- max(period_volumes, na.rm = TRUE)
              vlo <- min(period_volumes, na.rm = TRUE)
              f[[vhi_col]] <- vhi
              f[[vlo_col]] <- vlo
              f[[vdhi_col]] <- 100 * (latest_volume - vhi) / vhi
              f[[vdlo_col]] <- 100 * (latest_volume - vlo) / vlo
              # Robust length check for past_volume
              if (length(past_volume) == 1 && !is.na(past_volume) && past_volume > 0) {
                f[[vchg_col]] <- 100 * (latest_volume - past_volume) / past_volume
              } else {
                f[[vchg_col]] <- NA_real_
              }
              f[[vavg_col]] <- mean(period_volumes, na.rm = TRUE)
              f[[vvol_col]] <- 100 * sd(log(period_volumes), na.rm = TRUE)
              # ATR
              if ("high" %in% names(dt) && "low" %in% names(dt)) {
                highs <- period_data$high
                lows <- period_data$low
                closes <- period_data[, get(price_col)]
                prev_closes <- c(NA, closes[-length(closes)])
                tr <- pmax(highs - lows, abs(highs - prev_closes), abs(lows - prev_closes), na.rm = TRUE)
                f[[atr_col]] <- mean(tr[-1], na.rm = TRUE) # skip first NA
              } else {
                f[[atr_col]] <- NA_real_
              }
              # VaR (5th percentile of log returns)
              if (length(returns) > 0) {
                f[[var_col]] <- quantile(returns, 0.05, na.rm = TRUE)
              } else {
                f[[var_col]] <- NA_real_
              }
              # Price-volume correlation
              if (length(period_closes) == length(period_volumes) && length(period_closes) > 1) {
                f[[cor_col]] <- suppressWarnings(cor(period_closes, period_volumes, use = "pairwise.complete.obs"))
              } else {
                f[[cor_col]] <- NA_real_
              }
              # OBV (change over lag)
              obv <- rep(NA_real_, length(period_closes))
              if (length(period_closes) > 1) {
                obv[1] <- 0
                for (j in 2:length(period_closes)) {
                  # Add NA checks before comparison
                  if (!is.na(period_closes[j]) && !is.na(period_closes[j-1])) {
                    if (period_closes[j] > period_closes[j-1]) {
                      obv[j] <- obv[j-1] + period_volumes[j]
                    } else if (period_closes[j] < period_closes[j-1]) {
                      obv[j] <- obv[j-1] - period_volumes[j]
                    } else {
                      obv[j] <- obv[j-1]
                    }
                  } else {
                    # If either price is NA, keep previous OBV value
                    obv[j] <- obv[j-1]
                  }
                }
                f[[obv_col]] <- obv[length(obv)] - obv[1]
              } else {
                f[[obv_col]] <- NA_real_
              }
              # VWAP
              if (sum(period_volumes, na.rm = TRUE) > 0) {
                f[[vwap_col]] <- sum(period_closes * period_volumes, na.rm = TRUE) / sum(period_volumes, na.rm = TRUE)
              } else {
                f[[vwap_col]] <- NA_real_
              }
            }
          }
        } else {
          # Handle cases where there is not enough data for the lag
          f[[pchg_col]] <- NA_real_
          f[[pvol_col]] <- NA_real_
          f[[phi_col]] <- NA_real_
          f[[plo_col]] <- NA_real_
          f[[pdhi_col]] <- NA_real_
          f[[pdlo_col]] <- NA_real_
          if (lag > 1) {
            f[[vhi_col]] <- NA_real_
            f[[vlo_col]] <- NA_real_
            f[[vdhi_col]] <- NA_real_
            f[[vdlo_col]] <- NA_real_
            f[[vchg_col]] <- NA_real_
            f[[vavg_col]] <- NA_real_
            f[[vvol_col]] <- NA_real_
            f[[atr_col]] <- NA_real_
            f[[var_col]] <- NA_real_
            f[[cor_col]] <- NA_real_
            f[[obv_col]] <- NA_real_
            f[[vwap_col]] <- NA_real_
          }
        }
      } else {
        # Handle cases where reference date not found or no price available
        f[[pchg_col]] <- NA_real_
        f[[pvol_col]] <- NA_real_
        f[[phi_col]] <- NA_real_
        f[[plo_col]] <- NA_real_
        f[[pdhi_col]] <- NA_real_
        f[[pdlo_col]] <- NA_real_
        if (lag > 1) {
          f[[vhi_col]] <- NA_real_
          f[[vlo_col]] <- NA_real_
          f[[vdhi_col]] <- NA_real_
          f[[vdlo_col]] <- NA_real_
          f[[vchg_col]] <- NA_real_
          f[[vavg_col]] <- NA_real_
          f[[vvol_col]] <- NA_real_
          f[[atr_col]] <- NA_real_
          f[[var_col]] <- NA_real_
          f[[cor_col]] <- NA_real_
          f[[obv_col]] <- NA_real_
          f[[vwap_col]] <- NA_real_
        }
      }
    }
    features_list[[i]] <- as.data.table(f)
  }
  features_dt <- rbindlist(features_list, fill = TRUE)
  # print(features_dt) # Commented out as per edit hint
  flog.info("Feature calculation complete for %d companies", length(features_list))

  # Replace NA/nulls in new features with 9999
  feature_cols <- setdiff(names(features_dt), "id")
  for (col in feature_cols) {
    features_dt[is.na(get(col)), (col) := 9999]
  }
  flog.info("NA/nulls replaced with 9999 in feature columns")

  # Join with companies on id/company_id
  final_dt <- merge(companies_dt, features_dt, by = "id", all.x = TRUE)
  print('Columns in final_dt:')
  print(names(final_dt))
  flog.info("Merged features with companies table. Final row count: %d", nrow(final_dt))

  # Log the number of companies with matched price data
  diagnostics_count <- nrow(features_dt[!is.na(latest_close) & latest_close != 9999])

  flog.info("Number of companies with matched price data: %d", diagnostics_count)

  flog.info("\n=== PRICE SOURCE SUMMARY FOR REFERENCE DATE %s ===\n", as.character(today))
  flog.info("adj_close was used for %d companies\n", adj_close_used)
  flog.info("close was used for %d companies\n", close_used)
  flog.info("current_price from companies table was used for %d companies\n", current_price_used)
  flog.info("no price available for %d companies\n", no_price_available)
  flog.info("Total companies processed: %d\n", adj_close_used + close_used + current_price_used + no_price_available)
  

  # Export all companies
  if (!dir.exists("output")) dir.create("output")
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  output_file <- sprintf("output/companies_with_price_features_%s.csv", timestamp)
  fwrite(final_dt, output_file)
  flog.info("Exported features to %s", output_file)
  # Write final_dt to database
  dbWriteTable(con, "companies_with_price_features", as.data.frame(final_dt), overwrite = TRUE)
  flog.info("Exported features to companies_with_price_features table in database.")

  # Export only companies that matched price data
  matched_dt <- final_dt[!is.na(latest_close) & latest_close != 9999]
  matched_output_file <- sprintf("output/companies_with_price_features_matched_%s.csv", timestamp)
  fwrite(matched_dt, matched_output_file)
  flog.info("Exported matched companies to %s", matched_output_file)
  # Write matched_dt to database
  dbWriteTable(con, "companies_with_price_features_matched", as.data.frame(matched_dt), overwrite = TRUE)
  flog.info("Exported matched features to companies_with_price_features_matched table in database.")

  # Disconnect
  dbDisconnect(db_con)
  flog.info("Disconnected from database. Script complete.")

  # After features_dt is created and has the 'latest_close' and 'latest_volume' columns
  # Only print the final summary
  cat(sprintf("\n=== PRICE SOURCE SUMMARY FOR REFERENCE DATE %s ===\n", as.character(today)))
  cat(sprintf("adj_close was used for %d companies\n", adj_close_used))
  cat(sprintf("close was used for %d companies\n", close_used))
  cat(sprintf("current_price from companies table was used for %d companies\n", current_price_used))
  cat(sprintf("no price available for %d companies\n", no_price_available))
  cat(sprintf("Total companies processed: %d\n", adj_close_used + close_used + current_price_used + no_price_available))
  cat("================================================\n\n")

}, error = function(e) {
  flog.error("Error: %s", e$message)
  dbDisconnect(db_con)
  stop(e)
}) 


renv::snapshot()