#!/bin/bash
cd /Users/chanderbhushan/stockmkt

set -e
set -o pipefail

# Set log file with date and timestamp
log_datetime=$(date +%Y%m%d_%H%M%S)
log_file="log/historical_import_${log_datetime}.log"

# Initialize database schema before starting import
./0_init_db.sh | tee -a "$log_file"

echo "Starting historical data import at $(date)" | tee -a "$log_file"

# Get counts before run
companies_before=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM companies;" | xargs)
prices_before=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM prices;" | xargs)

echo "Companies table row count before run: $companies_before" | tee -a "$log_file"
echo "Prices table row count before run: $prices_before" | tee -a "$log_file"

# Check if companies table already has data
if [ "$companies_before" -gt 0 ]; then
    echo "WARNING: Companies table already has $companies_before records!" | tee -a "$log_file"
    echo "This script will add to existing data. Continue? (y/N)" | tee -a "$log_file"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Historical import cancelled by user" | tee -a "$log_file"
        exit 0
    fi
fi

echo "Starting full historical import workflow..." | tee -a "$log_file"

# 1. Import companies from CSV
# Dynamically set today's CSV file name
csv_file="data_ingestion/screener_export_$(date +%Y%m%d).csv"

# Check if the file exists
if [ ! -f "$csv_file" ]; then
    echo "ERROR: CSV file $csv_file not found!" | tee -a "$log_file"
    exit 1
fi

echo "Starting 1.1_import_screener_companies.py at $(date)" | tee -a "$log_file"
start1=$(date +%s)
python3 data_ingestion/onetime/1.1_import_screener_companies.py "$csv_file" | tee -a "$log_file"
echo "1.1_import_screener_companies.py completed successfully at $(date)" | tee -a "$log_file"
end1=$(date +%s)
dur1=$(( (end1 - start1) / 60 ))
echo "1.1_import_screener_companies.py duration: $dur1 minutes" | tee -a "$log_file"

# 2. Fetch yfinance info
echo "Starting 1.2_add_yf_in_companies.py at $(date)" | tee -a "$log_file"
start2=$(date +%s)
python3 data_ingestion/onetime/1.2_add_yf_in_companies.py | tee -a "$log_file"
echo "1.2_add_yf_in_companies.py completed successfully at $(date)" | tee -a "$log_file"
end2=$(date +%s)
dur2=$(( (end2 - start2) / 60 ))
echo "1.2_add_yf_in_companies.py duration: $dur2 minutes" | tee -a "$log_file"

# 3. Backup companies after yfinance info
echo "Starting 1.3_onetime_backup_companies.py at $(date)" | tee -a "$log_file"
start3=$(date +%s)
python3 data_ingestion/onetime/1.3_onetime_backup_companies.py | tee -a "$log_file"
echo "1.3_onetime_backup_companies.py completed successfully at $(date)" | tee -a "$log_file"
end3=$(date +%s)
dur3=$(( (end3 - start3) / 60 ))
echo "1.3_onetime_backup_companies.py duration: $dur3 minutes" | tee -a "$log_file"

# 4. Import historical prices
echo "Starting 2.1_onetime_prices.py at $(date)" | tee -a "$log_file"
start4=$(date +%s)
python3 data_ingestion/onetime/2.1_onetime_prices.py | tee -a "$log_file"
echo "2.1_onetime_prices.py completed successfully at $(date)" | tee -a "$log_file"
end4=$(date +%s)
dur4=$(( (end4 - start4) / 60 ))
echo "2.1_onetime_prices.py duration: $dur4 minutes" | tee -a "$log_file"

# 5. Backup prices
echo "Starting 2.2_onetime_backup_prices.py at $(date)" | tee -a "$log_file"
start5=$(date +%s)
python3 data_ingestion/onetime/2.2_onetime_backup_prices.py | tee -a "$log_file"
echo "2.2_onetime_backup_prices.py completed successfully at $(date)" | tee -a "$log_file"
end5=$(date +%s)
dur5=$(( (end5 - start5) / 60 ))
echo "2.2_onetime_backup_prices.py duration: $dur5 minutes" | tee -a "$log_file"

# 6. Import historical corporate actions
echo "Starting 3.1_onetime_corporate_actions.py at $(date)" | tee -a "$log_file"
start6=$(date +%s)
python3 data_ingestion/onetime/3.1_onetime_corporate_actions.py | tee -a "$log_file"
echo "3.1_onetime_corporate_actions.py completed successfully at $(date)" | tee -a "$log_file"
end6=$(date +%s)
dur6=$(( (end6 - start6) / 60 ))
echo "3.1_onetime_corporate_actions.py duration: $dur6 minutes" | tee -a "$log_file"

# 7. Backup corporate actions
echo "Starting 3.3_onetime_backup_corporate_actions.py at $(date)" | tee -a "$log_file"
start7=$(date +%s)
python3 data_ingestion/onetime/3.3_onetime_backup_corporate_actions.py | tee -a "$log_file"
echo "3.3_onetime_backup_corporate_actions.py completed successfully at $(date)" | tee -a "$log_file"
end7=$(date +%s)
dur7=$(( (end7 - start7) / 60 ))
echo "3.3_onetime_backup_corporate_actions.py duration: $dur7 minutes" | tee -a "$log_file"

# 8. Import historical indices
echo "Starting 4.1_onetime_indices.py at $(date)" | tee -a "$log_file"
start8=$(date +%s)
python3 data_ingestion/onetime/4.1_onetime_indices.py | tee -a "$log_file"
echo "4.1_onetime_indices.py completed successfully at $(date)" | tee -a "$log_file"
end8=$(date +%s)
dur8=$(( (end8 - start8) / 60 ))
echo "4.1_onetime_indices.py duration: $dur8 minutes" | tee -a "$log_file"

# 9. Backup indices
echo "Starting 4.3_onetime_backup_indices.py at $(date)" | tee -a "$log_file"
start9=$(date +%s)
python3 data_ingestion/onetime/4.3_onetime_backup_indices.py | tee -a "$log_file"
echo "4.3_onetime_backup_indices.py completed successfully at $(date)" | tee -a "$log_file"
end9=$(date +%s)
dur9=$(( (end9 - start9) / 60 ))
echo "4.3_onetime_backup_indices.py duration: $dur9 minutes" | tee -a "$log_file"

# Get counts after run
companies_after=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM companies;" | xargs)
prices_after=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM prices;" | xargs)

echo "Companies table row count after run: $companies_after" | tee -a "$log_file"
echo "Prices table row count after run: $prices_after" | tee -a "$log_file"

echo "Records added to companies table during this run: $((companies_after - companies_before))" | tee -a "$log_file"
echo "Records added to prices table during this run: $((prices_after - prices_before))" | tee -a "$log_file"

echo "Historical import completed successfully at $(date)" | tee -a "$log_file"
echo "Total duration: $(( (end9 - start1) / 60 )) minutes" | tee -a "$log_file"

echo "Summary of steps completed:" | tee -a "$log_file"
echo "✓ 1.1 Import companies from CSV ($dur1 min)" | tee -a "$log_file"
echo "✓ 1.2 Add yfinance info ($dur2 min)" | tee -a "$log_file"
echo "✓ 1.3 Backup companies after yfinance info ($dur3 min)" | tee -a "$log_file"
echo "✓ 2.1 Import historical prices ($dur4 min)" | tee -a "$log_file"
echo "✓ 2.2 Backup prices table ($dur5 min)" | tee -a "$log_file"
echo "✓ 3.1 Import historical corporate actions ($dur6 min)" | tee -a "$log_file"
echo "✓ 3.3 Backup corporate actions table ($dur7 min)" | tee -a "$log_file"
echo "✓ 4.1 Import historical indices ($dur8 min)" | tee -a "$log_file"
echo "✓ 4.3 Backup indices table ($dur9 min)" | tee -a "$log_file" 