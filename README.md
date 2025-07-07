# Stock Market Data Pipeline

A comprehensive, production-ready data pipeline for fetching, storing, and analyzing Indian stock market data using PostgreSQL, SQLAlchemy, and yfinance.

## 🚀 Features

- **Complete Data Coverage**: Companies, prices, corporate actions, and indices
- **Robust Data Quality**: Comprehensive validation and quality checks
- **Efficient Processing**: Batch operations and optimized database queries
- **Automated Workflows**: Historical imports and daily updates
- **Comprehensive Logging**: Detailed tracking and monitoring
- **Data Integrity**: Duplicate prevention and error handling
- **Scalable Architecture**: Modular design for easy maintenance
- **Cross-Platform Compatibility**: Fixed numpy/PostgreSQL compatibility issues

## 📊 Data Sources

- **Screener.in**: Company fundamentals and financial data
- **Yahoo Finance**: Real-time and historical market data
- **PostgreSQL**: Reliable data storage with proper indexing

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Screener CSV  │    │   YFinance API  │    │   PostgreSQL    │
│   (Companies)   │───▶│   (Prices,      │───▶│   Database      │
│                 │    │    Actions)     │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Data Quality  │
                       │   Validation    │
                       └─────────────────┘
```

## 📋 Prerequisites

### System Requirements
- **Python**: 3.8 or higher
- **PostgreSQL**: 12 or higher
- **Memory**: 4GB+ RAM recommended
- **Storage**: 10GB+ free space

### Python Dependencies
```bash
pip install -r requirements.txt
```

### Database Setup
```bash
# Create database and user
sudo -u postgres createdb stockdb
sudo -u postgres createuser stockuser
sudo -u postgres psql -c "ALTER USER stockuser WITH PASSWORD 'stockpass';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE stockdb TO stockuser;"
```

## 🗄️ Database Schema

### Core Tables

#### `companies`
| Column | Type | Description |
|--------|------|-------------|
| `id` | SERIAL | Primary key |
| `name` | VARCHAR | Company name |
| `nse_code` | VARCHAR | NSE ticker symbol |
| `bse_code` | VARCHAR | BSE ticker symbol |
| `sector` | VARCHAR | Business sector |
| `industry` | VARCHAR | Industry classification |
| `market_cap` | BIGINT | Market capitalization |
| `pe_ratio` | DECIMAL | Price-to-earnings ratio |
| `pb_ratio` | DECIMAL | Price-to-book ratio |
| `roe` | DECIMAL | Return on equity |
| `roa` | DECIMAL | Return on assets |
| `exchange` | VARCHAR | Primary exchange (NSE/BSE) |
| `yf_not_found` | BOOLEAN | YFinance data availability |

#### `prices`
| Column | Type | Description |
|--------|------|-------------|
| `id` | SERIAL | Primary key |
| `company_code` | VARCHAR | Unified company code |
| `company_name` | VARCHAR | Company name |
| `company_id` | INTEGER | Foreign key to companies |
| `date` | DATE | Trading date |
| `open` | DECIMAL | Opening price |
| `high` | DECIMAL | Highest price |
| `low` | DECIMAL | Lowest price |
| `close` | DECIMAL | Closing price |
| `volume` | BIGINT | Trading volume |
| `adj_close` | DECIMAL | Adjusted closing price |

#### `corporate_actions`
| Column | Type | Description |
|--------|------|-------------|
| `id` | SERIAL | Primary key |
| `company_code` | VARCHAR | Unified company code |
| `company_name` | VARCHAR | Company name |
| `date` | DATE | Action date |
| `type` | VARCHAR | Action type (split/dividend) |
| `details` | TEXT | Action details |

#### `indices`
| Column | Type | Description |
|--------|------|-------------|
| `id` | SERIAL | Primary key |
| `name` | VARCHAR | Index name |
| `ticker` | VARCHAR | YFinance ticker symbol |
| `region` | VARCHAR | Geographic region |
| `description` | TEXT | Index description |

#### `index_prices`
| Column | Type | Description |
|--------|------|-------------|
| `id` | SERIAL | Primary key |
| `name` | VARCHAR | Index name |
| `ticker` | VARCHAR | Index ticker |
| `region` | VARCHAR | Geographic region |
| `description` | TEXT | Index description |
| `date` | DATE | Trading date |
| `open` | DECIMAL | Opening value |
| `high` | DECIMAL | Highest value |
| `low` | DECIMAL | Lowest value |
| `close` | DECIMAL | Closing value |
| `volume` | BIGINT | Trading volume |

### Indexes
- `prices(company_code, date)` - Primary query index
- `prices(company_id, date)` - Legacy support
- `corporate_actions(company_code, date, type)` - Unique constraint
- `index_prices(name, ticker, date)` - Unique constraint

## 📁 Project Structure

```
stockmkt/
├── backend/
│   ├── models.py          # SQLAlchemy models
│   └── database.py        # Database configuration
├── data_ingestion/
│   ├── 1.1_import_screener_companies.py
│   ├── 1.2_add_yf_in_companies.py
│   ├── 2.1_onetime_prices.py
│   ├── 2.3_daily_prices.py
│   ├── 3.1_onetime_corporate_actions.py
│   ├── 3.2_daily_corporate_actions.py
│   ├── 4.1_onetime_indices.py
│   ├── 4.2_daily_indices.py
│   ├── 4.3_onetime_backup_indices.py
│   └── backup_scripts/    # Data backup utilities
├── log/                   # Timestamped log files
├── migrations/            # Alembic database migrations
├── run_*.sh              # Job runner scripts
└── requirements.txt       # Python dependencies
```

## 🔧 Data Ingestion Scripts

### Phase 1: Company Data
| Script | Purpose | Frequency | Status |
|--------|---------|-----------|--------|
| `1.1_import_screener_companies.py` | Import companies from CSV | One-time | ✅ Ready |
| `1.2_add_yf_in_companies.py` | Fetch YFinance company info | One-time/Daily | ✅ Ready |

### Phase 2: Price Data
| Script | Purpose | Frequency | Status |
|--------|---------|-----------|--------|
| `2.1_onetime_prices.py` | Historical prices (10 years) | One-time | ✅ Ready |
| `2.3_daily_prices.py` | Latest prices (3 days) | Daily | ✅ Ready |

### Phase 3: Corporate Actions
| Script | Purpose | Frequency | Status |
|--------|---------|-----------|--------|
| `3.1_onetime_corporate_actions.py` | Historical splits/dividends | One-time | ✅ Ready |
| `3.2_daily_corporate_actions.py` | Latest corporate actions | Daily (fetches/updates last 3 days) | ✅ Ready |

### Phase 4: Market Indices
| Script | Purpose | Frequency | Status |
|--------|---------|-----------|--------|
| `4.1_onetime_indices.py` | Historical index prices | One-time | ✅ **COMPLETED** |
| `4.2_daily_indices.py` | Latest index prices | Daily (fetches/updates last 3 days) | ✅ **READY** |
| `4.3_onetime_backup_indices.py` | Create data backups | One-time | ✅ **COMPLETED** |

## 🚀 Quick Start

### 1. Initial Setup
```bash
# Clone and setup
git clone <repository-url>
cd stockmkt

# Install dependencies
pip install -r requirements.txt

# Initialize database
./0_init_db.sh
```

### 2. Fresh Data Import (One-time)
```bash
# Run complete historical import
./run_historical_import.sh

# Or run step by step:
python3 data_ingestion/1.1_import_screener_companies.py data_ingestion/screener_export.csv
python3 data_ingestion/1.2_add_yf_in_companies.py
python3 data_ingestion/2.1_onetime_prices.py
python3 data_ingestion/3.1_onetime_corporate_actions.py
python3 data_ingestion/4.1_onetime_indices.py
```

### 3. Daily Updates
```bash
# Run daily updates for all data types
./run_daily_updates.sh

# Or run individual daily scripts:
python3 data_ingestion/2.3_daily_prices.py
python3 data_ingestion/3.2_daily_corporate_actions.py
python3 data_ingestion/4.2_daily_indices.py
```

## 🔧 Recent Fixes & Improvements

### Numpy/PostgreSQL Compatibility
- **Issue**: Numpy data types (`np.float64`) were causing PostgreSQL schema errors
- **Solution**: Updated `get_scalar()` function in all scripts to convert numpy types to native Python types
- **Impact**: All scripts now work without psycopg2 errors

### Data Population Status
- **Indices Table**: ✅ 35 records (all major global indices)
- **Index Prices Table**: ✅ 72,584 records (10 years of historical data)
- **Data Quality**: ✅ 100% completion rates across all columns

### Backup System
- **Automatic Backups**: Timestamped backup tables created
- **Data Safety**: Historical data preserved before major operations

## 📊 Current Data Status

### Indices Coverage
- **India**: Nifty 50, Nifty Bank, Sensex, BSE indices
- **US**: S&P 500, Dow Jones, Nasdaq, Russell 2000
- **Europe**: FTSE 100, DAX, CAC 40, Euro Stoxx 50
- **Asia-Pacific**: Nikkei 225, Hang Seng, Shanghai Composite, KOSPI, Straits Times, ASX 200
- **Global**: MSCI World ETF, MSCI Emerging Markets ETF
- **Commodities**: Gold, Silver, Crude Oil (WTI/Brent), Natural Gas, Copper, Platinum, Palladium, Corn, Soybeans, Wheat
- **Currency**: US Dollar Index

### Data Quality Metrics
- **Success Rate**: 82.86% (29/35 indices processed successfully)
- **Total Records**: 72,584 price records
- **Time Coverage**: 10 years of historical data
- **Data Completeness**: 100% for all required fields

## 🛠️ Troubleshooting

### Common Issues

#### Numpy/PostgreSQL Errors
```bash
# Error: schema "np" does not exist
# Solution: All scripts now handle numpy types correctly
```

#### Database Connection Issues
```bash
# Check PostgreSQL service
sudo systemctl status postgresql

# Verify connection
psql -U stockuser -d stockdb -c "SELECT 1;"
```

#### Memory Issues
```bash
# For large datasets, increase Python memory limit
export PYTHONOPTIMIZE=1
python3 -X maxsize=4G data_ingestion/2.1_onetime_prices.py
```

## 📈 Monitoring & Logs

### Log Files
- **Location**: `log/` directory
- **Format**: Timestamped files with detailed execution logs
- **Retention**: Keep for debugging and monitoring

### Data Quality Reports
- **Automatic**: Generated after each script execution
- **Metrics**: Success rates, record counts, data completeness
- **Validation**: Price range checks, duplicate detection

## 🔄 Automation

### Cron Jobs (Recommended)
```bash
# Daily updates at 6 PM
0 18 * * * cd /path/to/stockmkt && ./run_daily_updates.sh

# Weekly backups
0 20 * * 0 cd /path/to/stockmkt && python3 data_ingestion/4.3_onetime_backup_indices.py
```

### Manual Execution
```bash
# Check current data status
psql -U stockuser -d stockdb -c "SELECT COUNT(*) FROM index_prices;"

# Run specific script
python3 data_ingestion/4.2_daily_indices.py
```

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch
3. **Test** your changes thoroughly
4. **Submit** a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review log files in `log/` directory
3. Create an issue with detailed error information

## 🕒 Daily vs. Onetime Jobs

### Company Info (YFinance)
- **Onetime Script (`1.2_add_yf_in_companies.py`)**: Fetches and updates yfinance company metadata for all companies. Used for full/historical imports. Fetches the latest available info for each company sequentially (one by one).
- **Daily Script (`1.2_add_yf_in_companies_daily.py`)**: Fetches and updates yfinance company metadata for all companies as part of the daily update. Also fetches the latest available info for each company sequentially.
- **Limitation**: yfinance `.info` does not support batch fetching for company metadata. Each company requires a separate API call, and the time taken is dominated by network/API latency, not by the amount of data or the time window.
- **Optimization**: The main way to speed up this step is to use parallelization (multi-threading or async requests) to fetch info for multiple companies at once. This is not yet implemented in the scripts, but is recommended for large datasets.

### Price & Corporate Actions Data
- **Onetime Scripts**: Fetch full historical data (e.g., 5-10 years) for prices and corporate actions. Price data is batched using `yf.download()` for efficiency.
- **Daily Scripts**: Fetch only the last 3 days of data for prices, corporate actions, and indices. For prices, batching is used; for corporate actions, each company is still fetched individually due to yfinance limitations.

### Key Points
- **Company info (metadata)**: Always fetches the latest info, regardless of daily or onetime run. No batching possible for `.info`.
- **Price/corporate actions**: Daily scripts fetch only recent data, onetime scripts fetch all history. Price data can be batched; actions cannot.

---

## ⚡ Performance Notes & Recommendations

- **yfinance `.info` (company metadata)**: Slow for large numbers of companies because each API call is sequential. The time taken is similar whether you fetch daily or for a full import, because each call is a separate network request.
- **yfinance price data**: Fast, because batching is supported.
- **yfinance corporate actions**: Slow, because each company is fetched individually and Yahoo often returns the full history regardless of the date range requested.
- **Database indexing**: Does not help with yfinance API speed; it only helps with local query performance.

### Recommendations
- **Parallelize yfinance info fetching**: Use Python's `concurrent.futures.ThreadPoolExecutor` or `asyncio` to fetch info for multiple companies in parallel. This can dramatically reduce the time required for both daily and onetime jobs.
- **Implement retry logic**: To reduce data gaps due to transient network errors.
- **Monitor API limits**: Be aware of Yahoo's rate limits and consider adding delays or backoff as needed.
- **Log missing/failed fetches**: For later review and possible re-fetching.

---

## 📜 Script Descriptions: What Each Script Does

### Phase 1: Company Data

#### `1.1_import_screener_companies.py` (Onetime)
- **Purpose:** Imports all companies from a Screener.in CSV export into the database.
- **How it works:** Reads the CSV, cleans and validates company codes, adds new companies, and updates existing ones if details have changed. Used for full, one-time imports.

#### `1.1_import_screener_companies_daily.py` (Daily)
- **Purpose:** Imports only new companies (and updates changed details) from the latest Screener.in CSV.
- **How it works:** Reads the latest CSV, checks for companies not already in the database, adds them, and updates details for existing companies if there are changes. Intended for daily use.

#### `1.2_add_yf_in_companies.py` (Onetime)
- **Purpose:** Fetches and updates company metadata (profile, sector, industry, etc.) from Yahoo Finance for all companies.
- **How it works:** Loops through all companies, fetches the latest metadata using `yfinance.Ticker.info`, and updates only changed fields. Used for full, one-time enrichment.

#### `1.2_add_yf_in_companies_daily.py` (Daily)
- **Purpose:** Updates company metadata from Yahoo Finance for all companies as part of the daily update.
- **How it works:** Loops through all companies, fetches the latest metadata using `yfinance.Ticker.info`, and updates only changed fields. Intended for daily use to keep company info current.

### Phase 2: Price Data

#### `2.1_onetime_prices.py` (Onetime)
- **Purpose:** Fetches and stores historical daily price data (e.g., 5-10 years) for all companies.
- **How it works:** Uses `yfinance.download()` to fetch price data in batches, stores open, high, low, close, volume, and adjusted close prices in the database. Used for full, one-time import.

#### `2.3_daily_prices.py` (Daily)
- **Purpose:** Fetches and stores the latest daily price data (last 3 days) for all companies.
- **How it works:** Uses `yfinance.download()` to fetch recent price data in batches, updates the database with new price records for the last 3 days. Intended for daily use.

### Phase 3: Corporate Actions

#### `3.1_onetime_corporate_actions.py` (Onetime)
- **Purpose:** Fetches and stores all historical corporate actions (splits, dividends) for all companies.
- **How it works:** For each company, fetches all available splits and dividends from yfinance, stores each action in the database, avoiding duplicates. Used for full, one-time import.

#### `3.2_daily_corporate_actions.py` (Daily)
- **Purpose:** Fetches and stores only the latest corporate actions (last 3 days) for all companies.
- **How it works:** For each company, fetches splits and dividends from yfinance, filters actions to only those in the last 3 days, and updates the database with new actions. Intended for daily use.

### Phase 4: Market Indices

#### `4.1_onetime_indices.py` (Onetime)
- **Purpose:** Fetches and stores historical price data for major market indices.
- **How it works:** Uses yfinance to fetch historical prices for a predefined list of indices, stores the data in the `index_prices` table. Used for one-time, full import.

#### `4.2_daily_indices.py` (Daily)
- **Purpose:** Fetches and stores the latest price data (last 3 days) for major market indices.
- **How it works:** Uses yfinance to fetch recent prices for each index, updates the `index_prices` table with new records. Intended for daily use.

### Backup Scripts

#### `1.4_daily_backup_companies.py`, `2.4_daily_backup_prices.py`, `3.4_daily_backup_corporate_actions.py`, `4.3_onetime_backup_indices.py`
- **Purpose:** Create timestamped backup tables for each main data table.
- **How they work:** Copy the current table to a new table with a timestamp in the name. Used for data safety before major updates or as part of regular backups.

### Runner Scripts

#### `run_historical_import.sh`
- **Purpose:** Automates the full, one-time import process.
- **How it works:** Runs all onetime scripts in sequence: company import, yfinance info, prices, corporate actions, indices, and backups.

#### `run_daily_updates.sh`
- **Purpose:** Automates the daily update process.
- **How it works:** Runs all daily scripts in sequence: company import, yfinance info, prices, corporate actions, indices, and backups.

### Summary Table

| Script                                 | Purpose/Description                                                                 | Frequency      |
|-----------------------------------------|-------------------------------------------------------------------------------------|----------------|
| 1.1_import_screener_companies.py        | Import all companies from CSV (full import)                                         | Onetime        |
| 1.1_import_screener_companies_daily.py  | Import new/updated companies from CSV (incremental)                                 | Daily          |
| 1.2_add_yf_in_companies.py              | Fetch/update company metadata from yfinance (full import)                           | Onetime        |
| 1.2_add_yf_in_companies_daily.py        | Fetch/update company metadata from yfinance (incremental, but all companies)        | Daily          |
| 2.1_onetime_prices.py                   | Fetch/store historical price data for all companies                                 | Onetime        |
| 2.3_daily_prices.py                     | Fetch/store latest price data (last 3 days) for all companies                       | Daily          |
| 3.1_onetime_corporate_actions.py        | Fetch/store all historical corporate actions for all companies                      | Onetime        |
| 3.2_daily_corporate_actions.py          | Fetch/store latest corporate actions (last 3 days) for all companies                | Daily          |
| 4.1_onetime_indices.py                  | Fetch/store historical price data for major indices                                 | Onetime        |
| 4.2_daily_indices.py                    | Fetch/store latest price data (last 3 days) for major indices                       | Daily          |
| 1.4_daily_backup_companies.py           | Backup companies table                                                              | Daily/Onetime  |
| 2.4_daily_backup_prices.py              | Backup prices table                                                                 | Daily/Onetime  |
| 3.4_daily_backup_corporate_actions.py   | Backup corporate actions table                                                      | Daily/Onetime  |
| 4.3_onetime_backup_indices.py           | Backup index prices table                                                           | Onetime        |
| run_historical_import.sh                | Run all onetime scripts in sequence                                                 | Onetime        |
| run_daily_updates.sh                    | Run all daily scripts in sequence                                                   | Daily          |

--- 