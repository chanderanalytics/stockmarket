#!/usr/bin/env Rscript

# s4.2_consolidate_scenarios.R
# Script to consolidate scenario CSV files and add scenario column
# Created: 2025-12-30

# Load required packages
suppressPackageStartupMessages({
  library(data.table)
  library(stringr)
  library(glue)
  library(assertthat)
})

# Configuration
config <- list(
  input_dir = "/Users/chanderbhushan/stockmkt/output/mmtm",
  output_dir = "/Users/chanderbhushan/stockmkt/output/mmtm/consolidated",
  file_patterns = c(
    "performance_metrics_momentum_[0-9]+_[0-9]{4}-[0-9]{2}-[0-9]{2}\\.csv",
    "trade_details_momentum_[0-9]+_[0-9]{4}-[0-9]{2}-[0-9]{2}\\.csv",
    "atr_volatility_performance_momentum_[0-9]+_[0-9]{4}-[0-9]{2}-[0-9]{2}\\.csv"
  )
)

# Create output directory if it doesn't exist
if (!dir.exists(config$output_dir)) {
  dir.create(config$output_dir, recursive = TRUE, showWarnings = FALSE)
}

# Function to extract scenario number and date from filename
extract_metadata <- function(filename) {
  # Extract the number after 'momentum_' and before the next '_'
  scenario_match <- str_match(filename, "momentum_(\\d+)_(\\d{4}-\\d{2}-\\d{2})\\.csv$")
  
  if (is.na(scenario_match[1,1])) {
    stop(glue("Could not parse scenario and date from filename: {filename}"))
  }
  
  return(list(
    scenario = as.integer(scenario_match[1,2]),
    ref_date = scenario_match[1,3]
  ))
}

# Function to read and process a single file
process_file <- function(filepath, file_type) {
  message(glue("Processing {basename(filepath)}..."))
  
  # Extract metadata from filename
  metadata <- extract_metadata(basename(filepath))
  
  # Read the file
  dt <- fread(filepath, na.strings = c("", "NA", "N/A", "NULL"))
  
  # Add scenario and reference_date columns
  dt[, `:=`(
    scenario = paste0("scenario_", metadata$scenario),
    reference_date = as.Date(metadata$ref_date)
  )]
  
  # Reorder columns to have scenario and reference_date first
  setcolorder(dt, c("scenario", "reference_date", setdiff(names(dt), c("scenario", "reference_date"))))
  
  return(dt)
}

# Function to process all files of a specific type
process_file_type <- function(file_pattern, file_type) {
  message(glue("\nProcessing {file_type} files..."))
  
  # Find all matching files
  files <- list.files(
    path = config$input_dir,
    pattern = file_pattern,
    full.names = TRUE
  )
  
  if (length(files) == 0) {
    warning(glue("No {file_type} files found matching pattern: {file_pattern}"))
    return(NULL)
  }
  
  # Extract reference dates from all files to verify consistency
  ref_dates <- unique(sapply(files, function(f) {
    extract_metadata(basename(f))$ref_date
  }))
  
  if (length(ref_dates) > 1) {
    warning(glue("Multiple reference dates found for {file_type}: {paste(ref_dates, collapse=', ')}"))
  }
  
  # Use the most common reference date for the output filename
  ref_date <- names(sort(table(ref_dates), decreasing = TRUE))[1]
  message(glue("Using reference date: {ref_date} for {file_type}"))
  
  # Process all files and combine
  all_data <- rbindlist(
    lapply(files, function(f) process_file(f, file_type)),
    use.names = TRUE,
    fill = TRUE
  )
  
  # Save consolidated file
  output_file <- file.path(
    config$output_dir,
    glue("consolidated_{file_type}_{ref_date}.csv")
  )
  
  fwrite(all_data, output_file)
  message(glue("Saved consolidated {file_type} to: {output_file}"))
  
  return(list(
    file_type = file_type,
    file_count = length(files),
    row_count = nrow(all_data),
    ref_date = ref_date,
    output_file = output_file
  ))
}

# Main function
main <- function() {
  message("Starting consolidation of scenario files...")
  
  # Process each file type
  results <- list(
    performance_metrics = process_file_type(
      config$file_patterns[1], 
      "performance_metrics"
    ),
    trade_details = process_file_type(
      config$file_patterns[2], 
      "trade_details"
    ),
    atr_volatility = process_file_type(
      config$file_patterns[3], 
      "atr_volatility"
    )
  )
  
  # Print summary
  message("\n=== Consolidation Summary ===")
  for (result in results) {
    if (!is.null(result)) {
      message(glue(
        "{result$file_type}: {result$file_count} files, {result$row_count} rows, ref_date={result$ref_date} -> {result$output_file}"
      ))
    }
  }
  
  message("\nConsolidation complete!")
}

# Run the script
if (!interactive()) {
  main()
}
