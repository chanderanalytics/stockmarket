# Stock Market Data Pipeline

A comprehensive data pipeline for fetching, storing, and analyzing Indian stock market data using PostgreSQL, SQLAlchemy, and yfinance.

## Overview

This project provides a complete solution for:
- Importing company data from Screener CSV files
- Fetching historical and real-time stock prices from yfinance
- Storing data in a PostgreSQL database with proper indexing
- Running automated daily data updates

## Database Schema

### Companies Table
- Primary key: `id` (auto-increment)
- Unique identifiers: `nse_code`, `bse_code`
- Financial metrics from Screener CSV
- Additional data from yfinance

### Prices Table
- Primary key: `id` (auto-increment)
- Foreign key: `company_id` references `companies.id`
- Unified code: `company_code` (NSE or BSE code)
- Indexed on `(company_id, date)` and `(company_code, date)` for efficient queries
- Historical price data with OHLCV values

## Data Ingestion Scripts (Current)

### 1. Import Companies
```bash
python3 data_ingestion/1.1_import_screener_companies.py <csv_file_path>
```
- Imports companies from Screener CSV using unified codes (NSE/BSE)
- Handles upserts based on existing codes
- Validates and cleans data before import
- Logs all operations for tracking

### 2. Fetch YFinance Info
```bash
python3 data_ingestion/1.2_add_yf_in_companies.py
```
- Fetches additional company information from yfinance
- Updates companies table with sector, industry, financial metrics
- Uses unified codes for company identification
- Processes companies in batches for efficiency

### 3. Import Historical Prices
```bash
python3 data_ingestion/2.1_onetime_prices.py
```
- Fetches historical price data for all companies
- Uses unified codes instead of database IDs
- Processes companies in batches
- Handles duplicate data gracefully

### 4. Fetch Latest Prices (Daily)
```bash
python3 data_ingestion/2.3_daily_prices.py
```
- Fetches last 3 days of price data for daily updates
- Uses unified codes for company identification
- Only inserts new dates not already in database
- Optimized for daily automation

### 5. Import Historical Corporate Actions
```bash
python3 data_ingestion/3.1_onetime_corporate_actions.py
```
- Fetches and stores historical splits and dividends for all companies

### 6. Fetch Latest Corporate Actions (Daily)
```bash
python3 data_ingestion/3.2_daily_corporate_actions.py
```
- Fetches and stores splits and dividends for the last 3 days for all companies

### 7. Import Historical Indices
```bash
python3 data_ingestion/4.1_onetime_indices.py
```
- Fetches and stores historical index prices

### 8. Fetch Latest Indices (Daily)
```bash
python3 data_ingestion/4.2_daily_indices.py
```
- Fetches and stores index prices for the last 3 days

### 9. Backup Scripts
- `1.3_onetime_backup_companies.py`, `1.4_daily_backup_companies.py`
- `2.2_onetime_backup_prices.py`, `2.4_daily_backup_prices.py`
- `3.3_onetime_backup_corporate_actions.py`, `3.4_daily_backup_corporate_actions.py`
- `4.3_onetime_backup_indices.py`, `4.4_daily_backup_indices.py`

## Job Runner Scripts

### Historical Import (Full)
```bash
./run_historical_import.sh
```
- Runs all steps for a full historical import, including schema initialization, company import, yfinance info, prices, corporate actions, indices, and backups.

### Daily Updates
```bash
./run_daily_updates.sh
```
- Runs all steps for daily updates, including schema check, company update, yfinance info, daily prices, daily corporate actions, daily indices, and backups.

### Test Jobs
- `run_test_import.sh` (historical, limited companies)
- `run_test_daily.sh` (daily, limited companies)

## Logging

All scripts generate timestamped log files in the `log/` folder:
- `log/import_companies_onetime_<timestamp>.log`
- `log/yfinance_info_onetime_<timestamp>.log`
- `log/price_import_onetime_<timestamp>.log`
- `log/daily_prices_<timestamp>.log`
- `log/daily_corporate_actions_<timestamp>.log`
- `log/daily_indices_<timestamp>.log`
- ...and more for each step

## Usage Examples

### Fresh Data Import
```bash
# 1. Initialize schema
./0_init_db.sh

# 2. Import companies from CSV
python3 data_ingestion/1.1_import_screener_companies.py data_ingestion/screener_export.csv

# 3. Fetch yfinance info
python3 data_ingestion/1.2_add_yf_in_companies.py

# 4. Import historical prices
python3 data_ingestion/2.1_onetime_prices.py

# 5. Import historical corporate actions
python3 data_ingestion/3.1_onetime_corporate_actions.py

# 6. Import historical indices
python3 data_ingestion/4.1_onetime_indices.py
```

### Daily Updates
```bash
./run_daily_updates.sh
```

## Dependencies

- Python 3.8+
- PostgreSQL
- SQLAlchemy
- yfinance
- pandas
- psycopg2-binary
- alembic

## Notes
- All backup and log files are excluded from git via `.gitignore`.
- All scripts are optimized for batch processing and efficient database operations.
- See each script for more details and options (e.g., `--limit` for test runs). 