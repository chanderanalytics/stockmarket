#!/bin/bash
cd /Users/chanderbhushan/stockmkt

# Activate virtualenv for Python dependencies
source /Users/chanderbhushan/stockmkt/.venv/bin/activate

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

set -e
set -o pipefail

# Set log file with date and timestamp
log_datetime=$(date +%Y%m%d_%H%M%S)
log_file="log/daily_updates_${log_datetime}.log"

echo "Starting daily updates at $(date)" | tee -a "$log_file"

# Log Python and PostgreSQL versions and relevant environment variables
python_version=$(/Users/chanderbhushan/stockmkt/.venv/bin/python --version 2>&1)
psql_version=$(/opt/homebrew/bin/psql --version 2>&1)
echo "Python version: $python_version" | tee -a "$log_file"
echo "PostgreSQL version: $psql_version" | tee -a "$log_file"
echo "PATH: $PATH" | tee -a "$log_file"
echo "VIRTUAL_ENV: $VIRTUAL_ENV" | tee -a "$log_file"

# Get counts before run
companies_before=$(/opt/homebrew/bin/psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM companies;" | xargs)
prices_before=$(/opt/homebrew/bin/psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM prices;" | xargs)

echo "Companies table row count before run: $companies_before" | tee -a "$log_file"
echo "Prices table row count before run: $prices_before" | tee -a "$log_file"

# Check if companies table has data
if [ "$companies_before" -eq 0 ]; then
    echo "ERROR: Companies table is empty! Please run historical import first." | tee -a "$log_file"
    echo "Run: ./run_historical_import.sh" | tee -a "$log_file"
    exit 1
fi

echo "Starting daily updates workflow..." | tee -a "$log_file"

# 1. Import companies from CSV (in case new companies added)
# Dynamically set today's CSV file name
csv_file="data_ingestion/screener_export_$(date +%Y%m%d).csv"

# Check if the file exists
if [ ! -f "$csv_file" ]; then
    echo "ERROR: CSV file $csv_file not found!" | tee -a "$log_file"
    exit 1
fi

echo "Starting 1.1_import_screener_companies_daily.py at $(date)" | tee -a "$log_file"
start1=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/1.1_import_screener_companies_daily.py "$csv_file" | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 1.1_import_screener_companies_daily.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "1.1_import_screener_companies_daily.py completed successfully at $(date)" | tee -a "$log_file"
end1=$(date +%s)
dur1=$(( (end1 - start1) / 60 ))
echo "1.1_import_screener_companies_daily.py duration: $dur1 minutes" | tee -a "$log_file"

# 2. Fetch yfinance info (update existing companies)
# echo "Starting 1.2_add_yf_in_companies_daily.py at $(date)" | tee -a "$log_file"
# start2=$(date +%s)
# /Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/1.2_add_yf_in_companies_daily.py | tee -a "$log_file"
# if [ $? -ne 0 ]; then
#   echo "ERROR: 1.2_add_yf_in_companies_daily.py failed!" | tee -a "$log_file"
#   exit 1
# fi
# echo "1.2_add_yf_in_companies_daily.py completed successfully at $(date)" | tee -a "$log_file"
# end2=$(date +%s)
# dur2=$(( (end2 - start2) / 60 ))
# echo "1.2_add_yf_in_companies_daily.py duration: $dur2 minutes" | tee -a "$log_file"

# 3. Backup companies after daily updates
echo "Starting 1.4_daily_backup_companies.py at $(date)" | tee -a "$log_file"
start3=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/1.4_daily_backup_companies.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 1.4_daily_backup_companies.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "1.4_daily_backup_companies.py completed successfully at $(date)" | tee -a "$log_file"
end3=$(date +%s)
dur3=$(( (end3 - start3) / 60 ))
echo "1.4_daily_backup_companies.py duration: $dur3 minutes" | tee -a "$log_file"

# 4. Fetch latest prices
echo "Starting 2.3_daily_prices.py at $(date)" | tee -a "$log_file"
start4=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/2.3_daily_prices.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 2.3_daily_prices.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "2.3_daily_prices.py completed successfully at $(date)" | tee -a "$log_file"
end4=$(date +%s)
dur4=$(( (end4 - start4) / 60 ))
echo "2.3_daily_prices.py duration: $dur4 minutes" | tee -a "$log_file"

# 5. Backup prices after daily updates
echo "Starting 2.4_daily_backup_prices.py at $(date)" | tee -a "$log_file"
start5=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/2.4_daily_backup_prices.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 2.4_daily_backup_prices.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "2.4_daily_backup_prices.py completed successfully at $(date)" | tee -a "$log_file"
end5=$(date +%s)
dur5=$(( (end5 - start5) / 60 ))
echo "2.4_daily_backup_prices.py duration: $dur5 minutes" | tee -a "$log_file"

# 6. Fetch latest corporate actions
echo "Starting 3.2_daily_corporate_actions.py at $(date)" | tee -a "$log_file"
start6=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/3.2_daily_corporate_actions.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 3.2_daily_corporate_actions.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "3.2_daily_corporate_actions.py completed successfully at $(date)" | tee -a "$log_file"
end6=$(date +%s)
dur6=$(( (end6 - start6) / 60 ))
echo "3.2_daily_corporate_actions.py duration: $dur6 minutes" | tee -a "$log_file"

# 7. Backup corporate actions after daily updates
echo "Starting 3.4_daily_backup_corporate_actions.py at $(date)" | tee -a "$log_file"
start7=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/3.4_daily_backup_corporate_actions.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 3.4_daily_backup_corporate_actions.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "3.4_daily_backup_corporate_actions.py completed successfully at $(date)" | tee -a "$log_file"
end7=$(date +%s)
dur7=$(( (end7 - start7) / 60 ))
echo "3.4_daily_backup_corporate_actions.py duration: $dur7 minutes" | tee -a "$log_file"

# 8. Fetch latest index prices
echo "Starting 4.2_daily_indices.py at $(date)" | tee -a "$log_file"
start8=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/4.2_daily_indices.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 4.2_daily_indices.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "4.2_daily_indices.py completed successfully at $(date)" | tee -a "$log_file"
end8=$(date +%s)
dur8=$(( (end8 - start8) / 60 ))
echo "4.2_daily_indices.py duration: $dur8 minutes" | tee -a "$log_file"

# 9. Backup indices after daily updates
echo "Starting 4.4_daily_backup_indices.py at $(date)" | tee -a "$log_file"
start9=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/4.4_daily_backup_indices.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 4.4_daily_backup_indices.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "4.4_daily_backup_indices.py completed successfully at $(date)" | tee -a "$log_file"
end9=$(date +%s)
dur9=$(( (end9 - start9) / 60 ))
echo "4.4_daily_backup_indices.py duration: $dur9 minutes" | tee -a "$log_file"

# 10. Fetch latest financial statements
echo "Starting 6.2_daily_financial_statements.py at $(date)" | tee -a "$log_file"
start11=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/6.2_daily_financial_statements.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 6.2_daily_financial_statements.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "6.2_daily_financial_statements.py completed successfully at $(date)" | tee -a "$log_file"
end11=$(date +%s)
dur11=$(( (end11 - start11) / 60 ))
echo "6.2_daily_financial_statements.py duration: $dur11 minutes" | tee -a "$log_file"

# 11. Fetch latest analyst recommendations
echo "Starting 7.2_daily_analyst_recommendations.py at $(date)" | tee -a "$log_file"
start12=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/7.2_daily_analyst_recommendations.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 7.2_daily_analyst_recommendations.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "7.2_daily_analyst_recommendations.py completed successfully at $(date)" | tee -a "$log_file"
end12=$(date +%s)
dur12=$(( (end12 - start12) / 60 ))
echo "7.2_daily_analyst_recommendations.py duration: $dur12 minutes" | tee -a "$log_file"

# 12. Fetch latest major holders
echo "Starting 8.2_daily_major_holders.py at $(date)" | tee -a "$log_file"
start13=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/8.2_daily_major_holders.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 8.2_daily_major_holders.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "8.2_daily_major_holders.py completed successfully at $(date)" | tee -a "$log_file"
end13=$(date +%s)
dur13=$(( (end13 - start13) / 60 ))
echo "8.2_daily_major_holders.py duration: $dur13 minutes" | tee -a "$log_file"

# 13. Fetch latest institutional holders
echo "Starting 9.2_daily_institutional_holders.py at $(date)" | tee -a "$log_file"
start14=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/9.2_daily_institutional_holders.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 9.2_daily_institutional_holders.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "9.2_daily_institutional_holders.py completed successfully at $(date)" | tee -a "$log_file"
end14=$(date +%s)
dur14=$(( (end14 - start14) / 60 ))
echo "9.2_daily_institutional_holders.py duration: $dur14 minutes" | tee -a "$log_file"

# 14. Fetch latest options data
echo "Starting 10.2_daily_options_data.py at $(date)" | tee -a "$log_file"
start15=$(date +%s)
/Users/chanderbhushan/stockmkt/.venv/bin/python data_ingestion/10.2_daily_options_data.py | tee -a "$log_file"
if [ $? -ne 0 ]; then
  echo "ERROR: 10.2_daily_options_data.py failed!" | tee -a "$log_file"
  exit 1
fi
echo "10.2_daily_options_data.py completed successfully at $(date)" | tee -a "$log_file"
end15=$(date +%s)
dur15=$(( (end15 - start15) / 60 ))
echo "10.2_daily_options_data.py duration: $dur15 minutes" | tee -a "$log_file"

# Get counts after run
companies_after=$(/opt/homebrew/bin/psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM companies;" | xargs)
prices_after=$(/opt/homebrew/bin/psql -U stockuser -d stockdb -t -c "SELECT COUNT(*) FROM prices;" | xargs)

echo "Companies table row count after run: $companies_after" | tee -a "$log_file"
echo "Prices table row count after run: $prices_after" | tee -a "$log_file"

echo "Records added to companies table during this run: $((companies_after - companies_before))" | tee -a "$log_file"
echo "Records added to prices table during this run: $((prices_after - prices_before))" | tee -a "$log_file"

echo "Daily updates completed successfully at $(date)" | tee -a "$log_file"
echo "Total duration: $(( (end15 - start1) / 60 )) minutes" | tee -a "$log_file"

echo "Summary of steps completed:" | tee -a "$log_file"
echo "✓ 1.1 Import companies from CSV ($dur1 min)" | tee -a "$log_file"
# echo "✓ 1.2 Add yfinance info ($dur2 min)" | tee -a "$log_file"
echo "✓ 1.4 Backup companies after daily updates ($dur3 min)" | tee -a "$log_file"
echo "✓ 2.3 Fetch latest prices ($dur4 min)" | tee -a "$log_file"
echo "✓ 2.4 Backup prices after daily updates ($dur5 min)" | tee -a "$log_file"
echo "✓ 3.2 Fetch latest corporate actions ($dur6 min)" | tee -a "$log_file"
echo "✓ 3.4 Backup corporate actions after daily updates ($dur7 min)" | tee -a "$log_file"
echo "✓ 4.2 Fetch latest index prices ($dur8 min)" | tee -a "$log_file"
echo "✓ 4.4 Backup indices after daily updates ($dur9 min)" | tee -a "$log_file"
echo "✓ 6.2 Fetch latest financial statements ($dur11 min)" | tee -a "$log_file"
echo "✓ 7.2 Fetch latest analyst recommendations ($dur12 min)" | tee -a "$log_file"
echo "✓ 8.2 Fetch latest major holders ($dur13 min)" | tee -a "$log_file"
echo "✓ 9.2 Fetch latest institutional holders ($dur14 min)" | tee -a "$log_file"
echo "✓ 10.2 Fetch latest options data ($dur15 min)" | tee -a "$log_file"

# Error summary at the end
grep ERROR "$log_file" && echo "Errors found during run! See above." | tee -a "$log_file"

env > /tmp/cron_env.txt 