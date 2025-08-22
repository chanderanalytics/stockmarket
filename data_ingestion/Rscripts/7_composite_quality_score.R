# 7_composite_quality_score.R
# Create composite quality score by summing all decile values
# Then create new decile ranking for the combined score
# This allows using one filter instead of multiple decile filters

library(data.table)
library(DBI)
library(RPostgres)
library(futile.logger)
library(dplyr)

# Logging setup
log_file <- sprintf("log/7_composite_quality_score_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
flog.appender(appender.file(log_file))
flog.info("Starting composite quality score calculation")

# Connect to database
db_con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("PGDATABASE"),
  host = Sys.getenv("PGHOST"),
  port = as.integer(Sys.getenv("PGPORT")),
  user = Sys.getenv("PGUSER"),
  password = Sys.getenv("PGPASSWORD")
)

flog.info("Connected to database successfully")

# Load merged price baseline probabilities wide data (final joined table)
flog.info("Loading merged_price_baseline_probabilities_wide data (final joined table)...")
merged_data <- as.data.table(dbReadTable(db_con, "merged_price_baseline_probabilities_wide"))

flog.info("Data loaded: %d companies", nrow(merged_data))

# Get all decile columns
decile_cols <- names(merged_data)[grepl("_decile$", names(merged_data))]
flog.info("Found %d decile columns: %s", length(decile_cols), paste(decile_cols, collapse = ", "))

# Check NULL percentage for each decile column and filter out columns with too many NULLs
flog.info("Checking NULL percentages for decile columns...")
null_percentages <- data.table()
for (decile_col in decile_cols) {
  # Count both NA and empty string values
  null_count <- sum(is.na(merged_data[[decile_col]]) | merged_data[[decile_col]] == "")
  total_count <- nrow(merged_data)
  null_percentage <- (null_count / total_count) * 100
  
  null_percentages <- rbind(null_percentages, data.table(
    column = decile_col,
    null_count = null_count,
    total_count = total_count,
    null_percentage = null_percentage
  ))
  
  flog.info("%s: %d NULLs/empty out of %d total (%.1f%%)", 
            decile_col, null_count, total_count, null_percentage)
}

# Filter out decile columns with more than 50% NULLs
max_null_percentage <- 50
valid_decile_cols <- null_percentages[null_percentage <= max_null_percentage, column]
excluded_decile_cols <- null_percentages[null_percentage > max_null_percentage, column]

# Manually exclude specific decile columns
excluded_decile_cols <- c(excluded_decile_cols, "eps_decile", "profit_growth_5years_decile", "market_capitalization_decile")
valid_decile_cols <- valid_decile_cols[!valid_decile_cols %in% c("eps_decile", "profit_growth_5years_decile", "market_capitalization_decile")]

flog.info("Using %d decile columns with <= %.1f%% NULLs: %s", 
          length(valid_decile_cols), max_null_percentage, paste(valid_decile_cols, collapse = ", "))

if (length(excluded_decile_cols) > 0) {
  flog.info("Excluded %d decile columns with > %.1f%% NULLs or manually excluded: %s", 
            length(excluded_decile_cols), max_null_percentage, paste(excluded_decile_cols, collapse = ", "))
}

# Get corresponding raw value columns (remove _decile suffix)
raw_cols <- gsub("_decile$", "", valid_decile_cols)
raw_cols <- raw_cols[raw_cols %in% names(merged_data)]
flog.info("Found %d corresponding raw value columns: %s", length(raw_cols), paste(raw_cols, collapse = ", "))

# Function to calculate composite quality score (simplified without median imputation)
calculate_composite_score <- function(merged_dt, decile_cols) {
  flog.info("Calculating composite quality score...")
  
  # Create a copy to avoid modifying original data
  score_dt <- copy(merged_dt)
  
  # Convert all decile columns to numeric
  numeric_cols <- c()
  for (decile_col in decile_cols) {
    if (decile_col %in% names(score_dt)) {
      numeric_col <- paste0(decile_col, "_numeric")
      
      # Convert to numeric, handling empty strings and NA
      score_dt[, (numeric_col) := as.numeric(ifelse(get(decile_col) == "" | is.na(get(decile_col)), NA, as.character(get(decile_col))))]
      
      # Check if conversion was successful (not all NA)
      if (!all(is.na(score_dt[[numeric_col]]))) {
        numeric_cols <- c(numeric_cols, numeric_col)
        flog.info("Successfully converted %s to numeric", decile_col)
      } else {
        flog.warn("Conversion failed for %s - all values became NA", decile_col)
      }
    }
  }
  
  if (length(numeric_cols) == 0) {
    flog.error("No valid numeric decile columns found")
    return(score_dt)
  }
  
  flog.info("Using %d numeric decile columns: %s", length(numeric_cols), paste(numeric_cols, collapse = ", "))
  
  # Calculate composite score (sum of all available decile values)
  score_dt[, composite_score := rowSums(.SD, na.rm = TRUE), .SDcols = numeric_cols]
  
  # Calculate number of valid deciles used for each company
  score_dt[, valid_deciles_count := rowSums(!is.na(.SD)), .SDcols = numeric_cols]
  
  # Calculate average decile (alternative to sum)
  score_dt[, avg_decile := rowMeans(.SD, na.rm = TRUE), .SDcols = numeric_cols]
  
  # Calculate normalized composite score (composite score / number of deciles used)
  score_dt[, normalized_composite_score := composite_score / valid_deciles_count]
  
  # Also create a pure average score for comparison
  score_dt[, avg_composite_score := avg_decile]
  
  flog.info("Composite score calculated. Range: %.2f to %.2f", 
            min(score_dt$composite_score, na.rm = TRUE), 
            max(score_dt$composite_score, na.rm = TRUE))
  
  flog.info("Normalized composite score calculated. Range: %.2f to %.2f", 
            min(score_dt$normalized_composite_score, na.rm = TRUE), 
            max(score_dt$normalized_composite_score, na.rm = TRUE))
  
  flog.info("Average composite score calculated. Range: %.2f to %.2f", 
            min(score_dt$avg_composite_score, na.rm = TRUE), 
            max(score_dt$avg_composite_score, na.rm = TRUE))
  
  # Log summary
  total_companies <- nrow(score_dt)
  companies_with_scores <- sum(!is.na(score_dt$composite_score))
  flog.info("Composite scores calculated for %d out of %d companies", companies_with_scores, total_companies)
  
  # Log distribution of valid deciles count
  decile_count_dist <- score_dt[, .N, by = valid_deciles_count][order(valid_deciles_count)]
  flog.info("Distribution of valid deciles count:")
  for (i in 1:nrow(decile_count_dist)) {
    flog.info("  %d deciles: %d companies", decile_count_dist$valid_deciles_count[i], decile_count_dist$N[i])
  }
  
  return(score_dt)
}

# Function to create decile ranking for composite score
create_composite_deciles <- function(score_dt) {
  flog.info("Creating decile ranking for composite score...")
  
  # Create decile ranking for composite score using normalized score
  valid_scores <- score_dt[!is.na(normalized_composite_score) & is.finite(normalized_composite_score)]
  
  if (nrow(valid_scores) > 0) {
    # Create deciles (1 = top 10%, 10 = bottom 10%) using normalized score
    valid_scores[, composite_decile := as.character(cut(
      normalized_composite_score,
      breaks = quantile(normalized_composite_score, probs = seq(0, 1, length.out = 11)),
      labels = as.character(1:10),
      include.lowest = TRUE
    ))]
    
    # Create quintiles (1 = top 20%, 5 = bottom 20%) using normalized score
    valid_scores[, composite_quintile := as.character(cut(
      normalized_composite_score,
      breaks = quantile(normalized_composite_score, probs = seq(0, 1, length.out = 6)),
      labels = as.character(1:5),
      include.lowest = TRUE
    ))]
    
    # Create top 10% indicator
    valid_scores[, is_top_10_percent := composite_decile == "1"]
    
    # Create top 20% indicator
    valid_scores[, is_top_20_percent := composite_quintile == "1"]
    
    # Create quality tiers using data.table syntax instead of dplyr
    valid_scores[, quality_tier := ifelse(composite_decile %in% c("1", "2"), "High Quality",
                                         ifelse(composite_decile %in% c("3", "4", "5"), "Medium Quality",
                                                ifelse(composite_decile %in% c("6", "7", "8"), "Low Quality",
                                                       ifelse(composite_decile %in% c("9", "10"), "Poor Quality", "Unknown"))))]
    
    flog.info("Decile ranking created using normalized composite score. Distribution:")
    flog.info("Top 10%%: %d companies", sum(valid_scores$is_top_10_percent))
    flog.info("Top 20%%: %d companies", sum(valid_scores$is_top_20_percent))
    
    # Log quality tier distribution
    tier_dist <- valid_scores[, .N, by = quality_tier]
    for (i in 1:nrow(tier_dist)) {
      flog.info("%s: %d companies", tier_dist$quality_tier[i], tier_dist$N[i])
    }
    
    # Log score ranges by quality tier
    tier_score_ranges <- valid_scores[, .(
      min_score = min(normalized_composite_score),
      max_score = max(normalized_composite_score),
      avg_score = mean(normalized_composite_score),
      count = .N
    ), by = quality_tier]
    
    flog.info("Score ranges by quality tier:")
    for (i in 1:nrow(tier_score_ranges)) {
      flog.info("  %s: %.2f to %.2f (avg: %.2f, count: %d)", 
                tier_score_ranges$quality_tier[i], 
                tier_score_ranges$min_score[i], 
                tier_score_ranges$max_score[i],
                tier_score_ranges$avg_score[i],
                tier_score_ranges$count[i])
    }
  }
  
  return(valid_scores)
}

# Main analysis
flog.info("Starting composite quality score calculation...")

# Calculate composite scores
companies_with_scores <- calculate_composite_score(merged_data, valid_decile_cols)

# Create composite deciles
final_scores <- create_composite_deciles(companies_with_scores)

# Create comprehensive table with raw values, deciles, composite scores, and usage flags
# First, let's check what columns actually exist in final_scores
existing_cols <- names(final_scores)
flog.info("Available columns in final_scores: %s", paste(existing_cols, collapse = ", "))

# Create a list of columns we want to include, checking if they exist
output_cols <- c(
  # Core composite quality columns
  "company_id", "composite_score", "normalized_composite_score", "avg_composite_score",
  "composite_decile", "composite_quintile", "is_top_10_percent", "is_top_20_percent", 
  "quality_tier", "valid_deciles_count", "avg_decile"
)

# Add raw value columns that exist
raw_cols_to_check <- c("return_on_equity", "return_on_assets", "net_profit_margin", 
                       "sales_growth_3years", "profit_growth_3years", "eps_growth_3years",
                       "expected_quarterly_sales", "expected_quarterly_eps", "expected_quarterly_net_profit",
                       "price_to_earning", "price_to_book_value", "debt_to_equity", "peg_ratio")

for (col in raw_cols_to_check) {
  if (col %in% existing_cols) {
    output_cols <- c(output_cols, col)
  }
}

# Add decile columns that exist
decile_cols_to_check <- c("return_on_equity_decile", "return_on_assets_decile", "net_profit_margin_decile",
                         "sales_growth_3years_decile", "profit_growth_3years_decile", "eps_growth_3years_decile",
                         "expected_quarterly_sales_decile", "expected_quarterly_eps_decile", "expected_quarterly_net_profit_decile",
                         "price_to_earning_decile", "price_to_book_value_decile", "debt_to_equity_decile", "peg_ratio_decile")

for (col in decile_cols_to_check) {
  if (col %in% existing_cols) {
    output_cols <- c(output_cols, col)
  }
}

flog.info("Selected %d columns for output: %s", length(output_cols), paste(output_cols, collapse = ", "))

# Create the output table with only existing columns
composite_scores_comprehensive <- final_scores[, ..output_cols]

# Add usage flags based on which decile columns were actually used
for (decile_col in valid_decile_cols) {
  flag_col <- paste0("used_", gsub("_decile$", "", decile_col), "_decile")
  composite_scores_comprehensive[, (flag_col) := TRUE]
}

# Set unused decile flags to FALSE
all_possible_flags <- c(
  "used_roe_decile", "used_roa_decile", "used_net_profit_margin_decile",
  "used_sales_growth_3years_decile", "used_profit_growth_3years_decile", "used_eps_growth_3years_decile",
  "used_expected_quarterly_sales_decile", "used_expected_quarterly_eps_decile", "used_expected_quarterly_net_profit_decile",
  "used_price_to_earning_decile", "used_price_to_book_value_decile", "used_debt_to_equity_decile",
  "used_peg_ratio_decile"
)

for (flag_col in all_possible_flags) {
  if (flag_col %in% names(composite_scores_comprehensive)) {
    composite_scores_comprehensive[is.na(get(flag_col)), (flag_col) := FALSE]
  }
}

# Write to database
dbWriteTable(db_con, "composite_quality_scores", as.data.frame(composite_scores_comprehensive), overwrite = TRUE)

flog.info("Results written to database table")

# Print summary
flog.info("Composite score calculation complete")

# Close database connection
dbDisconnect(db_con)

