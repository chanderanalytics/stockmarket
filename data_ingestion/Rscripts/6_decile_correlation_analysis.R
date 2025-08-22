# 6_decile_correlation_analysis.R
# Calculate correlations between decile columns and existing return probability columns
# This helps identify which metrics are most predictive of future performance

library(data.table)
library(DBI)
library(RPostgres)
library(futile.logger)

# Logging setup
log_file <- sprintf("log/6_decile_correlation_analysis_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S"))
flog.appender(appender.file(log_file))
flog.info("Starting decile correlation analysis script")

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

# Load required data
flog.info("Loading companies insights data (with deciles)...")
companies_insights <- as.data.table(dbReadTable(db_con, "companies_insights"))

flog.info("Loading price baseline probabilities (with return columns)...")
price_baseline <- as.data.table(dbReadTable(db_con, "merged_price_baseline_probabilities_wide"))

flog.info("Data loaded: %d companies with deciles, %d companies with return probabilities", 
          nrow(companies_insights), nrow(price_baseline))

# Get all decile columns
decile_cols <- names(companies_insights)[grepl("_decile$", names(companies_insights))]
flog.info("Found %d decile columns: %s", length(decile_cols), paste(decile_cols, collapse = ", "))

# Get all return probability columns
return_cols <- names(price_baseline)[grepl("^price_return_", names(price_baseline))]
flog.info("Found %d return probability columns: %s", length(return_cols), paste(return_cols, collapse = ", "))

# Function to impute missing decile values with company-specific median
impute_missing_deciles <- function(companies_dt, decile_cols) {
  flog.info("Imputing missing decile values with company-specific medians...")
  
  # Create a copy to avoid modifying original data
  imputed_dt <- copy(companies_dt)
  
  # Convert decile columns to numeric for imputation
  for (decile_col in decile_cols) {
    if (decile_col %in% names(imputed_dt)) {
      # Convert to numeric, handling non-numeric values
      imputed_dt[, (paste0(decile_col, "_numeric")) := as.numeric(get(decile_col))]
      
      # Calculate company-specific median decile (excluding missing values)
      company_median_decile <- imputed_dt[, .(
        median_decile = median(get(paste0(decile_col, "_numeric")), na.rm = TRUE)
      ), by = company_id]
      
      # Merge median back to main table
      imputed_dt <- merge(imputed_dt, company_median_decile, by = "company_id", all.x = TRUE)
      
      # Replace missing values with company median
      imputed_dt[is.na(get(paste0(decile_col, "_numeric"))), 
                 (paste0(decile_col, "_numeric")) := median_decile]
      
      # Remove the temporary median column
      imputed_dt[, median_decile := NULL]
      
      # Log imputation statistics
      original_missing <- sum(is.na(as.numeric(companies_dt[[decile_col]])))
      imputed_missing <- sum(is.na(imputed_dt[[paste0(decile_col, "_numeric")]]))
      flog.info("Imputed %s: %d missing values filled, %d still missing", 
                decile_col, original_missing - imputed_missing, imputed_missing)
    }
  }
  
  return(imputed_dt)
}

# Function to calculate correlation between decile and return probability
calculate_decile_return_correlations <- function(companies_dt, price_baseline_dt, decile_cols, return_cols) {
  correlations_list <- list()
  
  # Merge companies insights with price baseline
  merged_dt <- merge(companies_dt, price_baseline_dt, by = "company_id", all.x = TRUE)
  flog.info("Merged data: %d companies", nrow(merged_dt))
  
  for (decile_col in decile_cols) {
    if (decile_col %in% names(merged_dt)) {
      flog.info("Analyzing correlations for decile column: %s", decile_col)
      
      # Use imputed numeric decile column
      imputed_col <- paste0(decile_col, "_numeric")
      
      for (return_col in return_cols) {
        if (return_col %in% names(merged_dt)) {
          # Filter valid data points (using imputed decile values)
          valid_data <- merged_dt[!is.na(get(imputed_col)) & 
                                   !is.na(get(return_col)) & 
                                   is.finite(get(return_col)) &
                                   get(imputed_col) != 9999 &
                                   get(return_col) != 9999]
          
          if (nrow(valid_data) > 10) {  # Minimum sample size
            # Calculate correlation using imputed decile values
            cor_result <- cor.test(valid_data[[imputed_col]], valid_data[[return_col]], 
                                  method = "spearman", use = "complete.obs")
            
            # Extract period and threshold from return column name
            # Format: price_return_{period}_{threshold}
            col_parts <- strsplit(return_col, "_")[[1]]
            period <- as.numeric(col_parts[3])
            threshold <- as.numeric(col_parts[4])
            
            # Count how many values were imputed for this correlation
            original_missing <- sum(is.na(as.numeric(companies_dt[[decile_col]])))
            imputed_missing <- sum(is.na(merged_dt[[imputed_col]]))
            imputed_count <- original_missing - imputed_missing
            
            correlations_list[[length(correlations_list) + 1]] <- data.table(
              decile_column = decile_col,
              return_column = return_col,
              period_days = period,
              threshold = threshold,
              correlation = cor_result$estimate,
              p_value = cor_result$p.value,
              sample_size = nrow(valid_data),
              imputed_count = imputed_count,
              mean_decile = mean(valid_data[[imputed_col]], na.rm = TRUE),
              mean_return_prob = mean(valid_data[[return_col]], na.rm = TRUE),
              sd_return_prob = sd(valid_data[[return_col]], na.rm = TRUE),
              significant = cor_result$p.value < 0.05
            )
          }
        }
      }
    }
  }
  
  return(rbindlist(correlations_list, fill = TRUE))
}

# Function to calculate sector-wise correlations
calculate_sector_correlations <- function(companies_dt, price_baseline_dt, decile_cols, return_cols) {
  sector_correlations_list <- list()
  
  # Merge companies insights with price baseline
  merged_dt <- merge(companies_dt, price_baseline_dt, by = "company_id", all.x = TRUE)
  
  # Get unique sectors
  sectors <- unique(merged_dt$sector[!is.na(merged_dt$sector) & merged_dt$sector != ""])
  flog.info("Calculating sector-wise correlations for %d sectors", length(sectors))
  
  for (sector in sectors) {
    sector_data <- merged_dt[sector == sector]
    
    for (decile_col in decile_cols) {
      if (decile_col %in% names(sector_data)) {
        # Use imputed numeric decile column
        imputed_col <- paste0(decile_col, "_numeric")
        
        for (return_col in return_cols) {
          if (return_col %in% names(sector_data)) {
            # Filter valid data points (using imputed decile values)
            valid_data <- sector_data[!is.na(get(imputed_col)) & 
                                      !is.na(get(return_col)) & 
                                      is.finite(get(return_col)) &
                                      get(imputed_col) != 9999 &
                                      get(return_col) != 9999]
            
            if (nrow(valid_data) > 5) {  # Lower threshold for sector analysis
              # Calculate correlation using imputed decile values
              cor_result <- cor.test(valid_data[[imputed_col]], valid_data[[return_col]], 
                                    method = "spearman", use = "complete.obs")
              
              # Extract period and threshold from return column name
              col_parts <- strsplit(return_col, "_")[[1]]
              period <- as.numeric(col_parts[3])
              threshold <- as.numeric(col_parts[4])
              
              # Count imputed values for this sector
              original_missing <- sum(is.na(as.numeric(companies_dt[company_id %in% sector_data$company_id, get(decile_col)])))
              imputed_missing <- sum(is.na(sector_data[[imputed_col]]))
              imputed_count <- original_missing - imputed_missing
              
              sector_correlations_list[[length(sector_correlations_list) + 1]] <- data.table(
                sector = sector,
                decile_column = decile_col,
                return_column = return_col,
                period_days = period,
                threshold = threshold,
                correlation = cor_result$estimate,
                p_value = cor_result$p.value,
                sample_size = nrow(valid_data),
                imputed_count = imputed_count,
                mean_decile = mean(valid_data[[imputed_col]], na.rm = TRUE),
                mean_return_prob = mean(valid_data[[return_col]], na.rm = TRUE),
                significant = cor_result$p.value < 0.05
              )
            }
          }
        }
      }
    }
  }
  
  return(rbindlist(sector_correlations_list, fill = TRUE))
}

# Function to create compact coefficient lookup table
create_coefficient_lookup <- function(correlations_dt) {
  flog.info("Creating compact coefficient lookup table...")
  
  # Create a compact lookup table with key coefficients
  lookup_table <- correlations_dt[, .(
    decile_column,
    period_days,
    threshold,
    correlation,
    p_value,
    significant,
    sample_size,
    # Create normalized weight within each period
    weight = correlation / sum(abs(correlation), na.rm = TRUE),
    # Create rank within each period
    rank_in_period = frank(-abs(correlation), ties.method = "min")
  ), by = period_days]
  
  # Add summary statistics
  summary_stats <- correlations_dt[, .(
    avg_correlation = mean(correlation, na.rm = TRUE),
    max_correlation = max(correlation, na.rm = TRUE),
    min_correlation = min(correlation, na.rm = TRUE),
    significant_count = sum(significant, na.rm = TRUE),
    total_tests = .N
  ), by = .(decile_column)]
  
  # Merge summary stats
  lookup_table <- merge(lookup_table, summary_stats, by = "decile_column", all.x = TRUE)
  
  flog.info("Created lookup table with %d rows", nrow(lookup_table))
  
  return(lookup_table)
}

# Function to create top coefficients summary (for practical use)
create_top_coefficients_summary <- function(correlations_dt, top_n = 20) {
  flog.info("Creating top coefficients summary for practical use...")
  
  # Get top correlations by absolute value
  top_correlations <- copy(correlations_dt)
  top_correlations[, abs_correlation := abs(correlation)]
  setorder(top_correlations, -abs_correlation)
  
  # Select top N correlations
  top_summary <- head(top_correlations, top_n)
  
  # Add practical usage information
  top_summary[, usage_priority := 1:.N]
  top_summary[, weight_normalized := correlation / sum(abs(correlation), na.rm = TRUE)]
  
  # Create simple coefficient names for easy reference
  top_summary[, coeff_name := paste0(decile_column, "_", period_days, "d_", threshold)]
  
  flog.info("Created top %d coefficients summary", top_n)
  
  return(top_summary)
}

# Main analysis
flog.info("Starting correlation analysis between deciles and return probabilities...")

# Impute missing decile values
companies_insights_imputed <- impute_missing_deciles(companies_insights, decile_cols)

# Calculate overall correlations
correlations <- calculate_decile_return_correlations(companies_insights_imputed, price_baseline, decile_cols, return_cols)

# Calculate sector-wise correlations
sector_correlations <- calculate_sector_correlations(companies_insights_imputed, price_baseline, decile_cols, return_cols)

# Create compact coefficient lookup table
coefficient_lookup <- create_coefficient_lookup(correlations)

# Create top coefficients summary
top_coefficients <- create_top_coefficients_summary(correlations, top_n = 50)

# Sort correlations by absolute correlation value
correlations[, abs_correlation := abs(correlation)]
setorder(correlations, -abs_correlation)

# Create summary statistics
correlation_summary <- correlations[, .(
  mean_correlation = mean(correlation, na.rm = TRUE),
  median_correlation = median(correlation, na.rm = TRUE),
  max_correlation = max(correlation, na.rm = TRUE),
  min_correlation = min(correlation, na.rm = TRUE),
  sd_correlation = sd(correlation, na.rm = TRUE),
  significant_count = sum(significant, na.rm = TRUE),
  total_tests = .N,
  total_imputed = sum(imputed_count, na.rm = TRUE)
), by = .(decile_column)]

# Create period-wise summary
period_summary <- correlations[, .(
  mean_correlation = mean(correlation, na.rm = TRUE),
  median_correlation = median(correlation, na.rm = TRUE),
  max_correlation = max(correlation, na.rm = TRUE),
  min_correlation = min(correlation, na.rm = TRUE),
  significant_count = sum(significant, na.rm = TRUE),
  total_tests = .N,
  total_imputed = sum(imputed_count, na.rm = TRUE)
), by = .(period_days)]

# Export results
if (!dir.exists("output")) dir.create("output")

# Save correlations to CSV
output_file <- sprintf("output/decile_return_correlations_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
fwrite(correlations, output_file)
flog.info("Correlations saved to: %s", output_file)

# Save sector correlations to CSV
sector_output_file <- sprintf("output/sector_decile_correlations_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
fwrite(sector_correlations, sector_output_file)
flog.info("Sector correlations saved to: %s", sector_output_file)

# Save coefficient lookup to CSV
lookup_output_file <- sprintf("output/coefficient_lookup_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
fwrite(coefficient_lookup, lookup_output_file)
flog.info("Coefficient lookup saved to: %s", lookup_output_file)

# Save top coefficients to CSV
top_coeff_output_file <- sprintf("output/top_coefficients_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
fwrite(top_coefficients, top_coeff_output_file)
flog.info("Top coefficients saved to: %s", top_coeff_output_file)

# Save summary to CSV
summary_output_file <- sprintf("output/decile_correlation_summary_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
fwrite(correlation_summary, summary_output_file)
flog.info("Correlation summary saved to: %s", summary_output_file)

# Save period summary to CSV
period_summary_file <- sprintf("output/period_correlation_summary_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
fwrite(period_summary, period_summary_file)
flog.info("Period correlation summary saved to: %s", period_summary_file)

# Write to database
dbWriteTable(db_con, "decile_return_correlations", as.data.frame(correlations), overwrite = TRUE)
dbWriteTable(db_con, "sector_decile_correlations", as.data.frame(sector_correlations), overwrite = TRUE)
dbWriteTable(db_con, "coefficient_lookup", as.data.frame(coefficient_lookup), overwrite = TRUE)
dbWriteTable(db_con, "top_coefficients", as.data.frame(top_coefficients), overwrite = TRUE)
dbWriteTable(db_con, "decile_correlation_summary", as.data.frame(correlation_summary), overwrite = TRUE)
dbWriteTable(db_con, "period_correlation_summary", as.data.frame(period_summary), overwrite = TRUE)

flog.info("Results written to database tables")

# Print top correlations
flog.info("Top 10 correlations by absolute value:")
print(head(correlations[, .(decile_column, return_column, period_days, threshold, correlation, p_value, sample_size, imputed_count)], 10))

# Print summary by decile column
flog.info("Correlation summary by decile column:")
print(correlation_summary)

# Print period summary
flog.info("Correlation summary by period:")
print(period_summary)

# Print top coefficients
flog.info("Top 10 coefficients for practical use:")
print(head(top_coefficients[, .(coeff_name, decile_column, period_days, threshold, correlation, p_value, significant, usage_priority)], 10))

# Close database connection
dbDisconnect(db_con)
flog.info("Decile correlation analysis complete")

# Return results for further use
cat("\n=== DECILE-RETURN CORRELATION ANALYSIS RESULTS ===\n")
cat("Top predictive deciles (by absolute correlation):\n")
top_correlations <- correlations[, .(decile_column, return_column, period_days, threshold, correlation, p_value, imputed_count)]
setorder(top_correlations, -abs(correlation))
print(head(top_correlations, 15))

cat("\n=== CORRELATION SUMMARY BY PERIOD ===\n")
for (period in unique(correlations$period_days)) {
  cat(sprintf("\nPeriod %d days:\n", period))
  period_data <- correlations[period_days == period, .(decile_column, return_column, correlation, p_value, significant, imputed_count)]
  setorder(period_data, -abs(correlation))
  print(head(period_data, 10))
}

cat("\n=== TOP COEFFICIENTS FOR PRACTICAL USE ===\n")
cat("Use these top coefficients in your predictive models:\n")
print(head(top_coefficients[, .(usage_priority, coeff_name, decile_column, period_days, threshold, correlation, p_value, significant, weight_normalized)], 20))

cat("\n=== SIGNIFICANT CORRELATIONS (p < 0.05) ===\n")
significant_correlations <- correlations[significant == TRUE, .(decile_column, return_column, period_days, threshold, correlation, p_value, imputed_count)]
setorder(significant_correlations, -abs(correlation))
print(head(significant_correlations, 15))

cat("\n=== SECTOR-SPECIFIC INSIGHTS ===\n")
top_sector_correlations <- sector_correlations[significant == TRUE, .(sector, decile_column, return_column, correlation, p_value, imputed_count)]
setorder(top_sector_correlations, -abs(correlation))
print(head(top_sector_correlations, 10))

cat("\n=== PRACTICAL USAGE GUIDE ===\n")
cat("1. Use 'top_coefficients' table for the most predictive combinations\n")
cat("2. Use 'coefficient_lookup' table for all coefficient combinations\n")
cat("3. Calculate weighted scores using the coefficients as weights\n")
cat("4. Example SQL for weighted score:\n")
cat("   SELECT company_id, \n")
cat("          SUM(decile_value * coefficient) as weighted_score\n")
cat("   FROM companies_insights ci\n")
cat("   JOIN coefficient_lookup cl ON ci.decile_column = cl.decile_column\n")
cat("   WHERE cl.usage_priority <= 20\n")
cat("   GROUP BY company_id;\n")

cat("\n=== IMPUTATION SUMMARY ===\n")
cat("Total values imputed across all correlations:", sum(correlations$imputed_count, na.rm = TRUE), "\n")
cat("Average imputed values per correlation:", mean(correlations$imputed_count, na.rm = TRUE), "\n") 