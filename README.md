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

## Data Ingestion Scripts

### 1. Import Companies (Unified Code Approach)
```bash
python3 data_ingestion/1.1_import_companies_unified_code.py <csv_file_path>
```
- Imports companies from Screener CSV using unified codes (NSE/BSE)
- Handles upserts based on existing codes
- Validates and cleans data before import
- Logs all operations for tracking

### 2. Fetch YFinance Info (Unified Code Approach)
```bash
python3 data_ingestion/1.2.1_fetch_yfinance_info_unified_code.py
```
- Fetches additional company information from yfinance
- Updates companies table with sector, industry, financial metrics
- Uses unified codes for company identification
- Processes companies in batches for efficiency

### 3. Backup Companies Table
```bash
python3 data_ingestion/1.3_backup_companies_table.py
```
- Creates timestamped backup of companies table
- Run after fetching yfinance info for complete backup
- Includes all yfinance fields and updates

### 4. Import Historical Prices (Unified Code Approach)
```bash
python3 data_ingestion/2.1_import_prices_unified_code.py
```
- Fetches historical price data for all companies
- Uses unified codes instead of database IDs
- Processes companies in batches of 25
- Handles duplicate data gracefully

### 5. Fetch Latest Prices (Unified Code Approach)
```bash
python3 data_ingestion/3.1_fetch_latest_prices_unified_code.py
```
- Fetches last 3 days of price data for daily updates
- Uses unified codes for company identification
- Only inserts new dates not already in database
- Optimized for daily automation

### 6. Backup Prices Table
```bash
python3 data_ingestion/2.2_backup_prices_table_psycopg2.py
```
- Creates timestamped backup of prices table
- Run after importing historical prices or latest prices
- Includes all price data with unified codes

## Additional Features

### Corporate Actions
```bash
python3 data_ingestion/5_fetch_corporate_actions.py
python3 data_ingestion/5.2_fetch_latest_corporate_actions.py
```

### Index Prices
```bash
python3 data_ingestion/6_fetch_indices_prices.py
python3 data_ingestion/6.2_fetch_latest_indices_prices.py
```

## Database Management

### Create Database
```bash
createdb -U stockuser stockdb
```

### Run Migrations
```bash
alembic upgrade head
```

### Check Migration Status
```bash
alembic current
```

## Automation

### Daily Jobs Script
```bash
./run_daily_jobs.sh
```
Runs the latest price fetch script daily for automated updates.

## Configuration

### Database Connection
- Host: localhost
- Port: 5432
- Database: stockdb
- User: stockuser
- Password: stockpass

### Backup Tables
Backup tables are automatically excluded from Alembic migrations to prevent accidental deletion.

## Key Features

### Unified Code Approach
- Uses NSE/BSE codes as primary identifiers
- Eliminates dependency on database IDs
- Ensures data consistency across imports
- Handles code validation and cleaning

### Batch Processing
- Processes companies in configurable batches
- Reduces memory usage and improves performance
- Provides progress tracking and logging

### Error Handling
- Comprehensive error logging
- Graceful handling of API failures
- Data validation before import
- Transaction rollback on errors

### Performance Optimization
- Indexed database queries
- Efficient batch processing
- Minimal API calls to yfinance
- Optimized for daily updates

## Logging

All scripts generate timestamped log files:
- `import_companies_unified_YYYYMMDD_HHMMSS.log`
- `yfinance_info_unified_YYYYMMDD_HHMMSS.log`
- `import_prices_unified_YYYYMMDD_HHMMSS.log`
- `fetch_latest_prices_unified_YYYYMMDD_HHMMSS.log`

## Usage Examples

### Fresh Data Import
```bash
# 1. Import companies from CSV
python3 data_ingestion/1.1_import_companies_unified_code.py screener_export.csv

# 2. Fetch yfinance info
python3 data_ingestion/1.2.1_fetch_yfinance_info_unified_code.py

# 3. Backup companies (with yfinance data)
python3 data_ingestion/1.3_backup_companies_table.py

# 4. Import historical prices
python3 data_ingestion/2.1_import_prices_unified_code.py

# 5. Backup prices
python3 data_ingestion/2.2_backup_prices_table_psycopg2.py
```

### Daily Updates
```bash
# Fetch latest prices (last 3 days)
python3 data_ingestion/3.1_fetch_latest_prices_unified_code.py
```

## Dependencies

- Python 3.8+
- PostgreSQL
- SQLAlchemy
- yfinance
- pandas
- psycopg2-binary
- alembic

## Installation

1. Clone the repository
2. Install dependencies: `pip install -r requirements.txt`
3. Set up PostgreSQL database
4. Run migrations: `alembic upgrade head`
5. Configure database connection if needed

## Notes

- Backup tables are preserved during migrations
- Unified code approach is recommended for all operations
- All scripts include comprehensive logging and error handling
- Sequential execution gives you full control over the workflow 