#!/bin/bash

# Daily Stock Market Data Pipeline
# This script runs all data ingestion and analysis scripts in sequence
# Date is extracted from the CSV filename

set -e  # Exit on any error
set -o pipefail

# Configuration
WORKSPACE_DIR="/Users/chanderbhushan/stockmkt"
VENV_PATH="$WORKSPACE_DIR/.venv/bin/activate"
PYTHONPATH="$WORKSPACE_DIR"

# Set log file with date and timestamp
log_datetime=$(date +%Y%m%d_%H%M%S)
log_file="log/daily_pipeline_${log_datetime}.log"

# Create log directory if it doesn't exist
#mkdir -p log

echo "Starting daily pipeline at $(date)" | tee -a "$log_file"
echo "Using file: $1"


# Function to extract date from CSV filename
extract_date_from_csv() {
    local csv_file="$1"
    if [[ -f "$csv_file" ]]; then
        # Extract date from filename like screener_export_20250806.csv
        local filename=$(basename "$csv_file")
        if [[ $filename =~ screener_export_([0-9]{8})\.csv ]]; then
            # Keep the date in YYYYMMDD format for consistent file naming
            echo "${BASH_REMATCH[1]}"
        else
            echo "Error: Could not extract date from CSV filename: $csv_file"
            exit 1
        fi
    else
        echo "Error: CSV file not found: $csv_file"
        exit 1
    fi
}

# Function to log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$log_file"
}

# Function to run a command and log its execution with timing
run_command() {
    local description="$1"
    local command="$2"
    local step_number="$3"
    
    log_message "Starting Step $step_number: $description"
    log_message "Command: $command"
    
    local start_time=$(date +%s)
    
    if eval "$command" 2>&1 | tee -a "$log_file"; then
        local end_time=$(date +%s)
        local duration=$(( (end_time - start_time) / 60 ))
        log_message "✅ Completed Step $step_number: $description (Duration: $duration minutes)"
        echo "$duration"  # Return duration for summary
    else
        local end_time=$(date +%s)
        local duration=$(( (end_time - start_time) / 60 ))
        log_message "❌ Failed Step $step_number: $description (Duration: $duration minutes)"
        exit 1
    fi
}

# Function to get database counts
get_db_counts() {
    local companies_count=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM companies;" | xargs)
    local prices_count=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM prices;" | xargs)
    local companies_powerbi_count=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM companies_powerbi;" | xargs)
    echo "$companies_count $prices_count $companies_powerbi_count"
}

# Main execution
main() {
    # Check if CSV file is provided
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <csv_file>"
        echo "Example: $0 data/screener_export_20250806.csv"
        exit 1
    fi
    
    local csv_file="$1"
    local date_from_csv=$(extract_date_from_csv "$csv_file")
    
    log_message "Starting daily pipeline with CSV: $csv_file"
    log_message "Extracted date: $date_from_csv"
    
    # Change to workspace directory
    cd "$WORKSPACE_DIR"
    
    # Get initial database counts
    read companies_before prices_before companies_powerbi_before <<< $(get_db_counts)
    log_message "Initial database counts - Companies: $companies_before, Prices: $prices_before, Companies PowerBI: $companies_powerbi_before"
    
    # Check if companies table has data
    if [ "$companies_before" -eq 0 ]; then
        log_message "ERROR: Companies table is empty! Please run historical import first."
        log_message "Run: ./run_historical_import.sh"
        exit 1
    fi
    
    # Initialize duration tracking
    declare -a durations=()
    
    # 1. Import companies from Screener CSV
    duration=$(run_command "Import companies from Screener CSV" \
        "source $VENV_PATH && PYTHONPATH=$PYTHONPATH python data_ingestion/onetime/1.1_import_screener_companies.py $csv_file" "1")
    durations+=("$duration")

    # 13. Import insider trades (incremental)
    # Use same date as reference date from input CSV
    # Format: data/insider_trades/insider_trades_YYYYMMDD.csv
    # Can be overridden with INSIDER_TRADES_CSV environment variable
    # Optional: INSIDER_MAX_ROWS to limit rows during testing
    DEFAULT_INSIDER_TRADES_CSV="data/insider_trades/insider_trades_${date_from_csv}.csv"
    : ${INSIDER_TRADES_CSV:=$DEFAULT_INSIDER_TRADES_CSV}
    
    log_message "Looking for insider trades file: $INSIDER_TRADES_CSV"
    if [ -f "$INSIDER_TRADES_CSV" ]; then
        if [ -n "$INSIDER_MAX_ROWS" ]; then
            duration=$(run_command "Import insider trades incremental" \
                "python3 data_ingestion/onetime/import_insider_trades_incremental.py \"$INSIDER_TRADES_CSV\" --max-rows $INSIDER_MAX_ROWS" "13")
        else
            duration=$(run_command "Import insider trades incremental" \
                "python3 data_ingestion/onetime/import_insider_trades_incremental.py \"$INSIDER_TRADES_CSV\"" "13")
        fi
        durations+=("$duration")
    else
        log_message "Insider trades file not found: $INSIDER_TRADES_CSV"
    fi
    
    
    # 2. Fetch historical prices
    duration=$(run_command "Fetch historical prices (10 days)" \
        "source $VENV_PATH && PYTHONPATH=$PYTHONPATH python data_ingestion/onetime/2.1_onetime_prices.py --days 10 --csv_file $csv_file" "2")
    durations+=("$duration")
    
    # 3. Fetch corporate actions
    #duration=$(run_command "Fetch corporate actions (10 days)" \
    #    "source $VENV_PATH && PYTHONPATH=$PYTHONPATH python data_ingestion/onetime/3.1_onetime_corporate_actions.py --days 10 --csv-file $csv_file" "3")
    #durations+=("$duration")
    
    # 4. Fetch indices data
    duration=$(run_command "Fetch indices data (10 days)" \
        "source $VENV_PATH && PYTHONPATH=$PYTHONPATH python data_ingestion/onetime/4.1_onetime_indices.py --days 10 --csv-file $csv_file" "4")
    durations+=("$duration")
    
    # 5. Data quality check
    duration=$(run_command "Data quality check" \
        "Rscript data_ingestion/Rscripts/1_dq_check_companies.R" "5")
    durations+=("$duration")
    
    # 6. Generate company insights
    duration=$(run_command "Generate company insights" \
        "Rscript data_ingestion/Rscripts/2_companies_insights.R" "6")
    durations+=("$duration")
    
    # 7. Calculate price features
    duration=$(run_command "Calculate price features" \
        "Rscript data_ingestion/Rscripts/3_companies_prices_features.R $date_from_csv" "7")
    durations+=("$duration")
    
    # 8. Calculate corporate action flags
    duration=$(run_command "Calculate corporate action flags" \
        "Rscript data_ingestion/Rscripts/4_corporate_action_flags.R" "8")
    durations+=("$duration")
    
    # 9. Calculate price-volume probabilities
    duration=$(run_command "Calculate price-volume probabilities" \
        "Rscript data_ingestion/Rscripts/5_price_volume_probabilities_vectorized.R" "9")
    durations+=("$duration")
    
    # 10. Recombine batches and merge
    duration=$(run_command "Recombine batches and merge" \
        "Rscript data_ingestion/Rscripts/5b_recombine_batches_and_merge.R" "10")
    durations+=("$duration")
    
    # 11. Calculate composite quality score
    duration=$(run_command "Calculate composite quality score" \
        "Rscript data_ingestion/Rscripts/7_composite_quality_score.R" "11")
    durations+=("$duration")
    
    # 12. Calculate indices features
    duration=$(run_command "Calculate indices features" \
        "Rscript data_ingestion/Rscripts/8_indices_features.R $date_from_csv" "12")
    durations+=("$duration")

    # 14. Calculate prices max min
    duration=$(run_command "Calculate prices max min" \
        "Rscript data_ingestion/Rscripts/prices_max_min.R" "14")
    durations+=("$duration")
    
    # 15. Update insider metrics
    duration=$(run_command "Update insider metrics" \
        "python3 data_ingestion/update_insider_metrics.py" "15")
    durations+=("$duration")
    
    # 16. Run momentum trading model
    duration=$(run_command "Run momentum trading model" \
        "Rscript data_ingestion/Rscripts/mmtm.R $date_from_csv" "16")
    durations+=("$duration")
    
    # 17. Run trade tracker analysis
    duration=$(run_command "Run trade tracker analysis" \
        "Rscript clean_trade_tracker.R" "17")
    durations+=("$duration")
    
    # 18. Save trade analysis to database
    duration=$(run_command "Save trade analysis to database" \
        "Rscript save_to_database.R" "18")
    durations+=("$duration")

    
    # Get final database counts
    read companies_after prices_after companies_powerbi_after <<< $(get_db_counts)
    log_message "Final database counts - Companies: $companies_after, Prices: $prices_after, Companies PowerBI: $companies_powerbi_after"
    
    # Calculate changes
    local companies_change=$((companies_after - companies_before))
    local prices_change=$((prices_after - prices_before))
    local companies_powerbi_change=$((companies_powerbi_after - companies_powerbi_before))
    
    log_message "Records added to companies table: $companies_change"
    log_message "Records added to prices table: $prices_change"
    log_message "Records added to companies_powerbi table: $companies_powerbi_change"
    
    # Calculate total duration
    local total_duration=0
    for duration in "${durations[@]}"; do
        total_duration=$((total_duration + duration))
    done
    
    log_message "🎉 Daily pipeline completed successfully!"
    log_message "Total duration: $total_duration minutes"
    
    # Summary of steps completed
    log_message "Summary of steps completed:"
    log_message "✓ 1. Import companies from Screener CSV (${durations[0]} min)"
    log_message "✓ 13. Fetch insider trades nse ({$durations[13]} min)"
    log_message "✓ 2. Fetch historical prices (${durations[2]} min)"
    #log_message "✓ 3. Fetch corporate actions (${durations[3]} min)"
    log_message "✓ 4. Fetch indices data (${durations[4]} min)"
    log_message "✓ 5. Data quality check (${durations[5]} min)"
    log_message "✓ 6. Generate company insights (${durations[6]} min)"
    log_message "✓ 7. Calculate price features (${durations[7]} min)"
    log_message "✓ 8. Calculate corporate action flags (${durations[8]} min)"
    log_message "✓ 9. Calculate price-volume probabilities (${durations[9]} min)"
    log_message "✓ 10. Recombine batches and merge (${durations[10]} min)"
    log_message "✓ 11. Calculate composite quality score (${durations[11]} min)"
    log_message "✓ 12. Calculate indices features (${durations[12]} min)"
    log_message "✓ 14. Calculate prices max min (${durations[14]} min)"
    log_message "✓ 15. Update insider metrics (${durations[15]} min)"
    log_message "✓ 16. Run momentum trading model (${durations[16]} min)"
    log_message "✓ 17. Run trade tracker analysis (${durations[17]} min)"
    log_message "✓ 18. Save trade analysis to database (${durations[18]} min)"
    # Check for errors in log
    if grep -q "ERROR\|Failed\|Error" "$log_file"; then
        log_message "⚠️  Warnings or errors found during run! Check log file for details."
        grep -i "error\|failed" "$log_file" | tail -5
    else
        log_message "✅ No errors found during run."
    fi
    
    # Save environment for debugging
    env > "/tmp/daily_pipeline_env_${log_datetime}.txt"
}

# Run main function with all arguments
main "$@" 