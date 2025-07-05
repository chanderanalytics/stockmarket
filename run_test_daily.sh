#!/bin/bash
cd /Users/chanderbhushan/stockmkt

set -e
set -o pipefail

# Set log file with date and timestamp
log_datetime=$(date +%Y%m%d_%H%M%S)
log_file="log/test_daily_${log_datetime}.log"

echo "Starting TEST daily updates with 10 companies at $(date)" | tee -a "$log_file"
echo "⚠️  WARNING: This is a TEST daily run with limited companies!" | tee -a "$log_file"

# Get counts before run
companies_before=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM companies;" | xargs)
prices_before=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM prices;" | xargs)
corporate_actions_before=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM corporate_actions;" | xargs)
index_prices_before=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM index_prices;" | xargs)

echo "Companies table row count before run: $companies_before" | tee -a "$log_file"
echo "Prices table row count before run: $prices_before" | tee -a "$log_file"
echo "Corporate Actions table row count before run: $corporate_actions_before" | tee -a "$log_file"
echo "Index Prices table row count before run: $index_prices_before" | tee -a "$log_file"

echo "Starting TEST daily updates workflow with 10 companies..." | tee -a "$log_file"

# 1. Import companies from CSV (in case new companies added)
echo "Starting 1.1_import_screener_companies.py (TEST - first 10 companies) at $(date)" | tee -a "$log_file"
start1=$(date +%s)
# Create a temporary CSV with only first 10 companies
head -n 11 data_ingestion/screener_export_20250704.csv > data_ingestion/test_screener_10.csv
python3 data_ingestion/1.1_import_screener_companies.py data_ingestion/test_screener_10.csv | tee -a "$log_file"
echo "1.1_import_screener_companies.py completed successfully at $(date)" | tee -a "$log_file"
end1=$(date +%s)
dur1=$(( (end1 - start1) / 60 ))
echo "1.1_import_screener_companies.py duration: $dur1 minutes" | tee -a "$log_file"

# 2. Fetch yfinance info (update existing companies)
echo "Starting 1.2_add_yf_in_companies.py (TEST - 10 companies) at $(date)" | tee -a "$log_file"
start2=$(date +%s)
python3 data_ingestion/1.2_add_yf_in_companies.py --limit 10 | tee -a "$log_file"
echo "1.2_add_yf_in_companies.py completed successfully at $(date)" | tee -a "$log_file"
end2=$(date +%s)
dur2=$(( (end2 - start2) / 60 ))
echo "1.2_add_yf_in_companies.py duration: $dur2 minutes" | tee -a "$log_file"

# 3. Backup companies after daily updates
echo "Starting 1.4_daily_backup_companies.py (TEST) at $(date)" | tee -a "$log_file"
start3=$(date +%s)
python3 data_ingestion/1.4_daily_backup_companies.py | tee -a "$log_file"
echo "1.4_daily_backup_companies.py completed successfully at $(date)" | tee -a "$log_file"
end3=$(date +%s)
dur3=$(( (end3 - start3) / 60 ))
echo "1.4_daily_backup_companies.py duration: $dur3 minutes" | tee -a "$log_file"

# 4. Fetch latest prices (last 3 days)
echo "Starting 2.3_daily_prices.py (TEST - 10 companies) at $(date)" | tee -a "$log_file"
start4=$(date +%s)
python3 data_ingestion/2.3_daily_prices.py --limit 10 | tee -a "$log_file"
echo "2.3_daily_prices.py completed successfully at $(date)" | tee -a "$log_file"
end4=$(date +%s)
dur4=$(( (end4 - start4) / 60 ))
echo "2.3_daily_prices.py duration: $dur4 minutes" | tee -a "$log_file"

# 5. Backup prices after daily updates
echo "Starting 2.4_daily_backup_prices.py (TEST) at $(date)" | tee -a "$log_file"
start5=$(date +%s)
python3 data_ingestion/2.4_daily_backup_prices.py | tee -a "$log_file"
echo "2.4_daily_backup_prices.py completed successfully at $(date)" | tee -a "$log_file"
end5=$(date +%s)
dur5=$(( (end5 - start5) / 60 ))
echo "2.4_daily_backup_prices.py duration: $dur5 minutes" | tee -a "$log_file"

# 6. Fetch latest corporate actions (last 3 days)
echo "Starting 3.2_daily_corporate_actions.py (TEST - 10 companies) at $(date)" | tee -a "$log_file"
start6=$(date +%s)
python3 data_ingestion/3.2_daily_corporate_actions.py --limit 10 | tee -a "$log_file"
echo "3.2_daily_corporate_actions.py completed successfully at $(date)" | tee -a "$log_file"
end6=$(date +%s)
dur6=$(( (end6 - start6) / 60 ))
echo "3.2_daily_corporate_actions.py duration: $dur6 minutes" | tee -a "$log_file"

# 7. Backup corporate actions after daily updates
echo "Starting 3.4_daily_backup_corporate_actions.py (TEST) at $(date)" | tee -a "$log_file"
start7=$(date +%s)
python3 data_ingestion/3.4_daily_backup_corporate_actions.py | tee -a "$log_file"
echo "3.4_daily_backup_corporate_actions.py completed successfully at $(date)" | tee -a "$log_file"
end7=$(date +%s)
dur7=$(( (end7 - start7) / 60 ))
echo "3.4_daily_backup_corporate_actions.py duration: $dur7 minutes" | tee -a "$log_file"

# 8. Fetch latest index prices (last 3 days)
echo "Starting 4.2_daily_indices.py (TEST) at $(date)" | tee -a "$log_file"
start8=$(date +%s)
python3 data_ingestion/4.2_daily_indices.py | tee -a "$log_file"
echo "4.2_daily_indices.py completed successfully at $(date)" | tee -a "$log_file"
end8=$(date +%s)
dur8=$(( (end8 - start8) / 60 ))
echo "4.2_daily_indices.py duration: $dur8 minutes" | tee -a "$log_file"

# 9. Backup indices after daily updates
echo "Starting 4.4_daily_backup_indices.py (TEST) at $(date)" | tee -a "$log_file"
start9=$(date +%s)
python3 data_ingestion/4.4_daily_backup_indices.py | tee -a "$log_file"
echo "4.4_daily_backup_indices.py completed successfully at $(date)" | tee -a "$log_file"
end9=$(date +%s)
dur9=$(( (end9 - start9) / 60 ))
echo "4.4_daily_backup_indices.py duration: $dur9 minutes" | tee -a "$log_file"

# Get counts after run
companies_after=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM companies;" | xargs)
prices_after=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM prices;" | xargs)
corporate_actions_after=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM corporate_actions;" | xargs)
index_prices_after=$(psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM index_prices;" | xargs)

echo "Companies table row count after run: $companies_after" | tee -a "$log_file"
echo "Prices table row count after run: $prices_after" | tee -a "$log_file"
echo "Corporate Actions table row count after run: $corporate_actions_after" | tee -a "$log_file"
echo "Index Prices table row count after run: $index_prices_after" | tee -a "$log_file"

echo "Records added to companies table during this TEST run: $((companies_after - companies_before))" | tee -a "$log_file"
echo "Records added to prices table during this TEST run: $((prices_after - prices_before))" | tee -a "$log_file"
echo "Records added to corporate actions table during this TEST run: $((corporate_actions_after - corporate_actions_before))" | tee -a "$log_file"
echo "Records added to index prices table during this TEST run: $((index_prices_after - index_prices_before))" | tee -a "$log_file"

echo "TEST daily updates completed successfully at $(date)" | tee -a "$log_file"
echo "Total duration: $(( (end9 - start1) / 60 )) minutes" | tee -a "$log_file"

echo "Summary of TEST daily steps completed:" | tee -a "$log_file"
echo "✓ 1.1 Import companies from CSV (TEST - 10 companies) ($dur1 min)" | tee -a "$log_file"
echo "✓ 1.2 Add yfinance info (TEST - 10 companies) ($dur2 min)" | tee -a "$log_file"
echo "✓ 1.4 Backup companies after daily updates (TEST) ($dur3 min)" | tee -a "$log_file"
echo "✓ 2.3 Fetch latest prices (TEST - 10 companies) ($dur4 min)" | tee -a "$log_file"
echo "✓ 2.4 Backup prices after daily updates (TEST) ($dur5 min)" | tee -a "$log_file"
echo "✓ 3.2 Fetch latest corporate actions (TEST - 10 companies) ($dur6 min)" | tee -a "$log_file"
echo "✓ 3.4 Backup corporate actions after daily updates (TEST) ($dur7 min)" | tee -a "$log_file"
echo "✓ 4.2 Fetch latest index prices (TEST) ($dur8 min)" | tee -a "$log_file"
echo "✓ 4.4 Backup indices after daily updates (TEST) ($dur9 min)" | tee -a "$log_file"

echo "" | tee -a "$log_file"
echo "🧪 TEST DAILY RUN COMPLETED SUCCESSFULLY!" | tee -a "$log_file"
echo "📊 Check the logs to verify everything worked correctly." | tee -a "$log_file"
echo "🚀 If everything looks good, you can run the full daily updates with: ./run_daily_updates.sh" | tee -a "$log_file"

# Clean up temporary test file
rm -f data_ingestion/test_screener_10.csv 