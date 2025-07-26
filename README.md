# Stock Market Data Pipeline & Analytics Platform

A comprehensive, production-grade pipeline for ingesting, processing, and analyzing Indian stock market data, with robust support for Power BI dashboards and advanced analytics.

---

## 📑 Table of Contents
- [Project Overview](#project-overview)
- [Architecture & Data Flow](#architecture--data-flow)
- [Key Tables & Outputs](#key-tables--outputs)
- [Directory Structure](#directory-structure)
- [Setup & Prerequisites](#setup--prerequisites)
- [How to Run the Pipeline](#how-to-run-the-pipeline)
  - [One-time Historical Import](#one-time-historical-import)
  - [Daily/Incremental Updates](#dailyincremental-updates)
  - [Batch & Vectorized Processing](#batch--vectorized-processing)
- [R Scripts & Feature Engineering](#r-scripts--feature-engineering)
- [Power BI Dashboard Integration](#power-bi-dashboard-integration)
- [Logging, Monitoring & Data Quality](#logging-monitoring--data-quality)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Contributing](#contributing)
- [License & Support](#license--support)

---

## Project Overview

This project provides a scalable, modular, and highly automated solution for collecting, validating, and analyzing Indian stock market data. It is designed for:
- **Analysts & quants** needing reliable, up-to-date market data
- **Developers** building dashboards, analytics, or trading systems
- **Researchers** requiring historical and real-time financial datasets

**Key Features:**
- End-to-end ingestion: companies, prices, corporate actions, indices, and more
- Batch and vectorized processing for speed and scalability
- Smart upserts, duplicate prevention, and robust data quality checks
- Detailed logging and monitoring
- Power BI-ready wide tables for instant dashboarding

---

## Architecture & Data Flow

### Complete Data Pipeline Flow

```
1. INPUT SOURCES
   ├── Screener CSV (NSE/BSE listed companies)
   ├── yfinance API (prices, corporate actions, indices)
   └── Manual company additions

2. DATA INGESTION (Python Scripts)
   ├── 1.1_import_screener_companies.py → companies table
   ├── 2.1_onetime_prices.py → prices table
   ├── 3.1_onetime_corporate_actions.py → corporate_actions table
   └── 4.1_onetime_indices.py → indices table

3. FEATURE ENGINEERING (R Scripts)
   ├── 2_companies_insights.R → company features
   ├── 3_companies_prices_features.R → price-based features
   ├── 4_corporate_action_flags.R → corp_action_flags table
   └── 5_price_volume_probabilities_vectorized.R → wide probability tables

4. OUTPUT TABLES
   ├── merged_price_baseline_probabilities_wide
   ├── merged_volume_baseline_probabilities_wide
   ├── merged_price_spike_probabilities_wide
   └── merged_volume_spike_probabilities_wide

5. POWER BI DASHBOARD
   └── Connect to wide tables for interactive analytics
```

### Data Processing Strategy

**Batch Processing for Large Datasets:**
- Companies processed in batches (default: 500 per batch)
- Intermediate results saved to temporary CSV files
- Final recombination and merging with corporate action flags
- Memory-efficient handling of large datasets

**Vectorized Operations:**
- R `data.table` for high-performance data manipulation
- Rolling windows, volatility calculations, probability computations
- Efficient handling of time series data

---

## Key Tables & Outputs

### Core Tables

| Table Name | Description | Key Columns | Purpose |
|------------|-------------|-------------|---------|
| `companies` | Company metadata | `company_id`, `name`, `sector`, `industry`, `market_cap` | Master company reference |
| `prices` | Daily OHLCV data | `company_id`, `date`, `open`, `high`, `low`, `close`, `adj_close`, `volume` | Historical price data |
| `corporate_actions` | Corporate events | `company_id`, `date`, `action_type`, `details` | Splits, dividends, etc. |
| `corp_action_flags` | Company features + flags | `company_id`, `sector`, `market_cap`, `has_split`, `has_dividend` | Analytics-ready features |

### Wide Analytics Tables (Power BI Ready)

| Table Name | Description | Key Features | Use Case |
|------------|-------------|--------------|----------|
| `merged_price_baseline_probabilities_wide` | Price return probabilities | `price_return_1_0.01`, `price_return_3_0.03`, etc. | Return prediction models |
| `merged_volume_baseline_probabilities_wide` | Volume change probabilities | `volume_change_1_0.1`, `volume_change_5_0.2`, etc. | Volume analysis |
| `merged_price_spike_probabilities_wide` | Price spike probabilities | `price_spike_1_0.05`, `price_spike_3_0.1`, etc. | Volatility analysis |
| `merged_volume_spike_probabilities_wide` | Volume spike probabilities | `volume_spike_1_0.5`, `volume_spike_3_1.0`, etc. | Unusual activity detection |

**Probability Column Naming Convention:**
- `{metric}_{days}_{threshold}` (e.g., `price_return_3_0.03` = 3-day return > 3%)
- Days: 1, 3, 5, 10, 20, 60
- Thresholds: Vary by metric (returns: 0.01-0.10, volumes: 0.1-2.0, spikes: 0.05-0.5)

---

## Directory Structure

```
stockmkt/
├── backend/                           # SQLAlchemy models, DB config
│   ├── models/                        # Database table definitions
│   ├── config.py                      # Database connection settings
│   └── database.py                    # Database initialization
├── data_ingestion/
│   ├── onetime/                       # One-time import scripts (Python)
│   │   ├── 1.1_import_screener_companies.py
│   │   ├── 2.1_onetime_prices.py
│   │   ├── 3.1_onetime_corporate_actions.py
│   │   └── 4.1_onetime_indices.py
│   ├── Rscripts/                      # R scripts for feature engineering
│   │   ├── 2_companies_insights.R
│   │   ├── 3_companies_prices_features.R
│   │   ├── 4_corporate_action_flags.R
│   │   ├── 5_price_volume_probabilities_vectorized.R
│   │   └── 5b_recombine_batches_and_merge.R
│   ├── daily/                         # Daily update scripts
│   ├── archived_scripts/              # Old/deprecated scripts
│   └── screener_export.csv            # Input company list
├── log/                               # Timestamped log files
│   ├── *.log                          # Script execution logs
│   └── powerbi_*.log                  # Power BI creation logs
├── output/                            # All CSV outputs
│   ├── *.csv                          # Wide tables for Power BI
│   ├── batch_*.csv                    # Temporary batch outputs
│   └── *_export.csv                   # Database exports
├── migrations/                        # Alembic DB migrations
├── run_*.sh                           # Job runner scripts
├── requirements.txt                   # Python dependencies
├── .Renviron                          # R environment variables
└── README.md                          # This documentation
```

---

## Setup & Prerequisites

### System Requirements
- **Python 3.8+** with pip
- **R 4.0+** with RStudio or R console
- **PostgreSQL 12+** with psql client
- **Power BI Desktop** (for dashboarding)
- **4GB+ RAM, 10GB+ free disk space**
- **Git** for version control

### Step 1: Clone and Setup Repository
```bash
git clone <repository-url>
cd stockmkt
```

### Step 2: Install Python Dependencies
```bash
pip install -r requirements.txt
```

**Key Python packages:**
- `yfinance`: Yahoo Finance API wrapper
- `sqlalchemy`: Database ORM
- `psycopg2-binary`: PostgreSQL adapter
- `pandas`: Data manipulation
- `logging`: Logging framework

### Step 3: Install R Dependencies
Open R console and run:
```r
# Install required packages
install.packages(c(
  'data.table',    # High-performance data manipulation
  'DBI',           # Database interface
  'RPostgres',     # PostgreSQL connector
  'futile.logger', # Logging framework
  'zoo'            # Time series operations
))

# Verify installations
library(data.table)
library(DBI)
library(RPostgres)
library(futile.logger)
library(zoo)
```

### Step 4: Database Setup

**Create Database and User:**
```bash
# Connect as postgres superuser
sudo -u postgres psql

# Create database and user
CREATE DATABASE stockdb;
CREATE USER stockuser WITH PASSWORD 'stockpass';
GRANT ALL PRIVILEGES ON DATABASE stockdb TO stockuser;
GRANT ALL ON SCHEMA public TO stockuser;
\q
```

**Verify Connection:**
```bash
psql stockdb -U stockuser -h localhost -c "SELECT version();"
```

### Step 5: Environment Configuration

**Create `.Renviron` file:**
```bash
# In project root directory
cat > .Renviron << EOF
PGHOST=localhost
PGPORT=5432
PGDATABASE=stockdb
PGUSER=stockuser
PGPASSWORD=stockpass
EOF
```

**Verify R can connect:**
```r
# Test database connection
library(DBI)
library(RPostgres)

con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("PGDATABASE"),
  host = Sys.getenv("PGHOST"),
  port = as.integer(Sys.getenv("PGPORT")),
  user = Sys.getenv("PGUSER"),
  password = Sys.getenv("PGPASSWORD")
)

# Test query
result <- dbGetQuery(con, "SELECT version();")
print(result)
dbDisconnect(con)
```

---

## How to Run the Pipeline

### One-time Historical Import

**Step 1: Import Company List**
```bash
# Import companies from screener CSV
python3 data_ingestion/onetime/1.1_import_screener_companies.py data_ingestion/screener_export.csv

# Verify import
psql stockdb -c "SELECT COUNT(*) as company_count FROM companies;"
psql stockdb -c "SELECT name, sector, market_cap FROM companies LIMIT 5;"
```

**Step 2: Import Historical Prices**
```bash
# Import 10 years of price data for all companies
python3 data_ingestion/onetime/2.1_onetime_prices.py

# Monitor progress in log file
tail -f log/2.1_onetime_prices_*.log

# Verify import
psql stockdb -c "SELECT COUNT(*) as price_records FROM prices;"
psql stockdb -c "SELECT company_id, date, adj_close, volume FROM prices WHERE company_id = 1 ORDER BY date DESC LIMIT 5;"
```

**Step 3: Import Corporate Actions**
```bash
# Import corporate actions (splits, dividends, etc.)
python3 data_ingestion/onetime/3.1_onetime_corporate_actions.py

# Verify import
psql stockdb -c "SELECT COUNT(*) as action_count FROM corporate_actions;"
psql stockdb -c "SELECT action_type, COUNT(*) FROM corporate_actions GROUP BY action_type;"
```

**Step 4: Import Market Indices**
```bash
# Import major indices (NIFTY, SENSEX, etc.)
python3 data_ingestion/onetime/4.1_onetime_indices.py

# Verify import
psql stockdb -c "SELECT COUNT(*) as index_records FROM indices;"
```

### Feature Engineering (R Scripts)

**Step 5: Generate Company Insights**
```bash
# Run in R console or RStudio
Rscript data_ingestion/Rscripts/2_companies_insights.R

# Monitor progress
tail -f log/2_companies_insights_*.log

# Verify output
psql stockdb -c "SELECT COUNT(*) FROM companies_insights;"
```

**Step 6: Calculate Price Features**
```bash
# Generate price-based features (returns, volatility, etc.)
Rscript data_ingestion/Rscripts/3_companies_prices_features.R

# Monitor progress
tail -f log/3_companies_prices_features_*.log

# Verify output
psql stockdb -c "SELECT COUNT(*) FROM companies_prices_features;"
```

**Step 7: Create Corporate Action Flags**
```bash
# Join company features with corporate action flags
Rscript data_ingestion/Rscripts/4_corporate_action_flags.R

# Monitor progress
tail -f log/4_corporate_action_flags_*.log

# Verify output
psql stockdb -c "SELECT COUNT(*) FROM corp_action_flags;"
psql stockdb -c "SELECT has_split, has_dividend, COUNT(*) FROM corp_action_flags GROUP BY has_split, has_dividend;"
```

**Step 8: Generate Probability Tables (Batch Processing)**
```bash
# This is the most intensive step - processes companies in batches
Rscript data_ingestion/Rscripts/5_price_volume_probabilities_vectorized.R

# Monitor progress (this may take 1-2 hours for full dataset)
tail -f log/5_price_volume_probabilities_vectorized_*.log

# Check batch progress
ls -la output/batch_*.csv

# Verify final outputs
psql stockdb -c "SELECT COUNT(*) FROM merged_price_baseline_probabilities_wide;"
psql stockdb -c "SELECT COUNT(*) FROM merged_volume_baseline_probabilities_wide;"
psql stockdb -c "SELECT COUNT(*) FROM merged_price_spike_probabilities_wide;"
psql stockdb -c "SELECT COUNT(*) FROM merged_volume_spike_probabilities_wide;"
```

### Daily/Incremental Updates

**For Daily Updates (Run after market close):**
```bash
# Update prices for last N days
python3 data_ingestion/daily/update_prices.py --days 1

# Update corporate actions
python3 data_ingestion/daily/update_corporate_actions.py --days 7

# Re-run feature engineering for updated companies
Rscript data_ingestion/Rscripts/5_price_volume_probabilities_vectorized.R --days 30
```

**For Backfilling Missing Data:**
```bash
# Backfill last 30 days of prices
python3 data_ingestion/daily/update_prices.py --days 30

# Backfill last 90 days of corporate actions
python3 data_ingestion/daily/update_corporate_actions.py --days 90
```

### Batch & Vectorized Processing

**Understanding Batch Processing:**
- Large datasets are processed in batches (default: 500 companies per batch)
- Each batch creates temporary CSV files in `output/batch_*.csv`
- Final step recombines all batches and merges with corporate action flags
- If a batch fails, you can resume from the last successful batch

**Recovery from Batch Failures:**
```bash
# If the main script fails after batch processing, use recovery script
Rscript data_ingestion/Rscripts/5b_recombine_batches_and_merge.R

# This will recombine existing batch files and complete the pipeline
```

**Monitoring Batch Progress:**
```bash
# Check how many batches are complete
ls output/batch_*_price_baseline.csv | wc -l

# Check batch file sizes (should be similar)
ls -lh output/batch_*_price_baseline.csv

# Monitor memory usage during processing
top -p $(pgrep -f "Rscript.*5_price_volume_probabilities")
```

---

## R Scripts & Feature Engineering

### Script 2: Companies Insights (`2_companies_insights.R`)

**Purpose:** Generate company-level features and rankings

**Key Features Created:**
- Market cap deciles and percentiles
- Sector and industry rankings
- Outlier detection (companies with unusual characteristics)
- Financial ratios and metrics

**Output:** `companies_insights` table

**Sample Output Columns:**
```sql
SELECT 
  company_id, name, sector, market_cap,
  market_cap_decile, sector_rank, is_outlier
FROM companies_insights 
LIMIT 5;
```

### Script 3: Price Features (`3_companies_prices_features.R`)

**Purpose:** Calculate price-based features from historical data

**Key Features Created:**
- Rolling returns (1, 3, 5, 10, 20, 60 days)
- Rolling volatility (standard deviation of returns)
- Price momentum indicators
- Support and resistance levels

**Output:** `companies_prices_features` table

**Sample Output Columns:**
```sql
SELECT 
  company_id, date,
  return_1d, return_5d, return_20d,
  volatility_20d, momentum_60d
FROM companies_prices_features 
WHERE company_id = 1 
ORDER BY date DESC 
LIMIT 5;
```

### Script 4: Corporate Action Flags (`4_corporate_action_flags.R`)

**Purpose:** Join company features with corporate action flags

**Key Features Created:**
- Binary flags for splits, dividends, bonus issues
- Date-based flags (days since last action)
- Action frequency indicators

**Output:** `corp_action_flags` table

**Sample Output Columns:**
```sql
SELECT 
  company_id, name, sector,
  has_split, has_dividend, days_since_split,
  split_frequency, dividend_frequency
FROM corp_action_flags 
LIMIT 5;
```

### Script 5: Probability Calculations (`5_price_volume_probabilities_vectorized.R`)

**Purpose:** Calculate probability features for price and volume movements

**Key Features Created:**
- Probability of returns exceeding thresholds (1%, 3%, 5%, 10%)
- Probability of volume changes exceeding thresholds (10%, 20%, 50%, 100%)
- Probability of price spikes (5%, 10%, 20%, 50%)
- Probability of volume spikes (50%, 100%, 200%, 500%)

**Processing Strategy:**
1. **Batch Processing:** Companies processed in batches of 500
2. **Vectorized Operations:** Uses `data.table` for high performance
3. **Rolling Windows:** Calculates probabilities over different time periods
4. **Memory Management:** Saves intermediate results to avoid memory issues

**Output Tables:**
- `merged_price_baseline_probabilities_wide`
- `merged_volume_baseline_probabilities_wide`
- `merged_price_spike_probabilities_wide`
- `merged_volume_spike_probabilities_wide`

**Sample Output Columns:**
```sql
SELECT 
  company_id, name, sector,
  price_return_1_0.01,    -- 1-day return > 1%
  price_return_3_0.03,    -- 3-day return > 3%
  volume_change_1_0.1,    -- 1-day volume change > 10%
  price_spike_1_0.05      -- 1-day price spike > 5%
FROM merged_price_baseline_probabilities_wide 
LIMIT 5;
```

### Recovery Script (`5b_recombine_batches_and_merge.R`)

**Purpose:** Recover from batch processing failures

**When to Use:**
- Main script fails after batch processing but before final merge
- Need to recombine existing batch files
- Want to complete the pipeline without re-processing all data

**Process:**
1. Finds all batch CSV files in `output/`
2. Recombines them using `rbindlist()`
3. Merges with corporate action flags
4. Writes final wide tables to database and CSV

---

## Power BI Dashboard Integration

### Connecting to Data

**Option 1: Direct Database Connection (Recommended)**
1. Open Power BI Desktop
2. Click "Get Data" → "Database" → "PostgreSQL database"
3. Enter connection details:
   - Server: `localhost`
   - Database: `stockdb`
   - Username: `stockuser`
   - Password: `stockpass`
4. Select the wide tables for import

**Option 2: Import CSV Files**
1. Export wide tables to CSV:
```bash
psql stockdb -c "\COPY merged_price_baseline_probabilities_wide TO 'output/merged_price_baseline_probabilities_wide_export.csv' CSV HEADER;"
psql stockdb -c "\COPY merged_volume_baseline_probabilities_wide TO 'output/merged_volume_baseline_probabilities_wide_export.csv' CSV HEADER;"
psql stockdb -c "\COPY merged_price_spike_probabilities_wide TO 'output/merged_price_spike_probabilities_wide_export.csv' CSV HEADER;"
psql stockdb -c "\COPY merged_volume_spike_probabilities_wide TO 'output/merged_volume_spike_probabilities_wide_export.csv' CSV HEADER;"
psql stockdb -c "\COPY companies TO 'output/companies_export.csv' CSV HEADER;"
psql stockdb -c "\COPY corp_action_flags TO 'output/corp_action_flags_export.csv' CSV HEADER;"
```

2. Import CSVs into Power BI

### Data Model Setup

**Create Relationships:**
- `companies[company_id]` → `merged_price_baseline_probabilities_wide[company_id]`
- `companies[company_id]` → `merged_volume_baseline_probabilities_wide[company_id]`
- `companies[company_id]` → `merged_price_spike_probabilities_wide[company_id]`
- `companies[company_id]` → `merged_volume_spike_probabilities_wide[company_id]`
- `companies[company_id]` → `corp_action_flags[company_id]`

**Key Measures (DAX):**
```dax
// Average return probability across all companies
Avg Return Probability = AVERAGE(merged_price_baseline_probabilities_wide[price_return_1_0.01])

// Count of high probability stocks
High Probability Count = COUNTROWS(
    FILTER(
        merged_price_baseline_probabilities_wide,
        merged_price_baseline_probabilities_wide[price_return_1_0.01] > 0.5
    )
)

// Sector performance
Sector Avg Return = AVERAGEX(
    merged_price_baseline_probabilities_wide,
    merged_price_baseline_probabilities_wide[price_return_1_0.01]
)
```

### Dashboard Design

**Page 1: Market Overview**
- **KPIs:** Total companies, average market cap, sector distribution
- **Visuals:** 
  - Market cap distribution by sector (treemap)
  - Top/bottom performing sectors (bar chart)
  - Market breadth indicators (gauge charts)

**Page 2: Last Day Highlights**
- **KPIs:** Stocks with >5% gain/loss, unusual volume activity
- **Visuals:**
  - Top gainers/losers table
  - Volume spike heatmap
  - Sector performance heatmap

**Page 3: Probability Analysis**
- **KPIs:** High probability stocks count, average probabilities
- **Visuals:**
  - Probability distribution histograms
  - Correlation matrix (price vs volume probabilities)
  - Probability by sector/industry

**Page 4: Stock Drilldown**
- **Filters:** Company, sector, market cap range
- **Visuals:**
  - Price chart with volume
  - Probability metrics for selected stock
  - Peer comparison table

**Page 5: Predictive Insights**
- **KPIs:** Next-day prediction confidence
- **Visuals:**
  - Probability trend charts
  - Alert dashboard for high-probability events
  - Risk assessment matrix

### Interactivity Features

**Slicers and Filters:**
- Date range selector
- Sector/industry filter
- Market cap range filter
- Probability threshold slider

**Drill-down Capabilities:**
- Sector → Industry → Company
- Company → Detailed metrics
- Date → Day → Hour (if available)

**Conditional Formatting:**
- High probability cells highlighted in green
- Low probability cells highlighted in red
- Volume spikes highlighted in orange

---

## Logging, Monitoring & Data Quality

### Log File Structure

**Log File Naming:**
- Format: `log/{script_name}_{timestamp}.log`
- Example: `log/5_price_volume_probabilities_vectorized_20241201_143022.log`

**Log Content:**
- Start/end timestamps
- Progress updates (every 100 companies or major step)
- Error messages with stack traces
- Data quality summaries
- Performance metrics

### Monitoring Script Execution

**Real-time Monitoring:**
```bash
# Monitor current script execution
tail -f log/$(ls -t log/*.log | head -1)

# Monitor specific script
tail -f log/5_price_volume_probabilities_vectorized_*.log

# Check for errors
grep -i error log/*.log

# Check completion status
grep -i "complete\|finished" log/*.log
```

**Data Quality Checks:**
```bash
# Check for NULL values in key columns
psql stockdb -c "
SELECT 
  'prices' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE adj_close IS NULL) as null_adj_close,
  COUNT(*) FILTER (WHERE volume IS NULL) as null_volume
FROM prices
UNION ALL
SELECT 
  'companies' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE market_cap IS NULL) as null_market_cap,
  COUNT(*) FILTER (WHERE sector IS NULL) as null_sector
FROM companies;
"

# Check for duplicates
psql stockdb -c "
SELECT 
  'prices' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(DISTINCT company_id, date) as duplicates
FROM prices
UNION ALL
SELECT 
  'companies' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(DISTINCT company_id) as duplicates
FROM companies;
"
```

### Performance Monitoring

**Database Performance:**
```sql
-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

**Script Performance:**
```bash
# Monitor memory usage
top -p $(pgrep -f "Rscript\|python")

# Monitor disk I/O
iostat -x 1

# Check log file growth
watch -n 5 'ls -lh log/*.log | tail -5'
```

---

## Troubleshooting & FAQ

### Common Issues and Solutions

**Q: Script fails with "vector memory limit reached"**
- **Cause:** R runs out of memory processing large datasets
- **Solution:** 
  - Reduce batch size in script 5 (change `batch_size <- 500` to `batch_size <- 250`)
  - Close other applications to free memory
  - Use the recovery script if batches were already created

**Q: Database connection fails**
- **Cause:** Incorrect credentials or database not running
- **Solution:**
  ```bash
  # Check if PostgreSQL is running
  sudo systemctl status postgresql
  
  # Test connection
  psql stockdb -U stockuser -h localhost -c "SELECT 1;"
  
  # Check .Renviron file
  cat .Renviron
  ```

**Q: R packages not found**
- **Cause:** Packages not installed or R version mismatch
- **Solution:**
  ```r
  # Install missing packages
  install.packages(c('data.table', 'DBI', 'RPostgres', 'futile.logger', 'zoo'))
  
  # Check R version
  R.version.string
  ```

**Q: Log files show wrong timestamps**
- **Cause:** System timezone or clock issues
- **Solution:**
  ```bash
  # Check system time
  date
  
  # Set timezone if needed
  sudo timedatectl set-timezone Asia/Kolkata
  ```

**Q: Power BI can't connect to database**
- **Cause:** Network, firewall, or authentication issues
- **Solution:**
  - Verify PostgreSQL is listening on correct port: `netstat -an | grep 5432`
  - Check firewall settings: `sudo ufw status`
  - Test connection from Power BI machine: `telnet localhost 5432`

**Q: Batch processing fails partway through**
- **Cause:** Memory issues, network problems, or script errors
- **Solution:**
  ```bash
  # Check which batches completed
  ls output/batch_*_price_baseline.csv
  
  # Use recovery script
  Rscript data_ingestion/Rscripts/5b_recombine_batches_and_merge.R
  
  # Check logs for specific errors
  grep -i error log/5_price_volume_probabilities_vectorized_*.log
  ```

**Q: Data quality issues (NULLs, duplicates, etc.)**
- **Cause:** Source data problems or processing errors
- **Solution:**
  ```sql
  -- Identify problematic data
  SELECT company_id, COUNT(*) 
  FROM prices 
  WHERE adj_close <= 0 OR volume <= 0 
  GROUP BY company_id;
  
  -- Clean data if needed
  UPDATE prices SET adj_close = NULL WHERE adj_close <= 0;
  UPDATE prices SET volume = NULL WHERE volume <= 0;
  ```

### Performance Optimization

**Database Optimization:**
```sql
-- Create indexes for better performance
CREATE INDEX idx_prices_company_date ON prices(company_id, date);
CREATE INDEX idx_companies_sector ON companies(sector);
CREATE INDEX idx_corp_actions_company_date ON corporate_actions(company_id, date);

-- Analyze tables for query optimization
ANALYZE prices;
ANALYZE companies;
ANALYZE corporate_actions;
```

**R Script Optimization:**
- Use `data.table` instead of `data.frame` for large datasets
- Process data in chunks to manage memory
- Use vectorized operations instead of loops
- Set appropriate memory limits: `memory.limit(size = 8000)`

**Python Script Optimization:**
- Use bulk inserts instead of row-by-row inserts
- Implement connection pooling for database operations
- Use multiprocessing for parallel data processing
- Cache frequently accessed data

### Data Recovery

**Recovering from Failed Imports:**
```bash
# Check what data was imported
psql stockdb -c "SELECT COUNT(*) FROM companies;"
psql stockdb -c "SELECT COUNT(*) FROM prices;"

# If partial data exists, you can resume from where it left off
# Most scripts have resume capabilities or can be run with date ranges
```

**Recovering from Corrupted Data:**
```sql
-- Backup current data
pg_dump stockdb > backup_$(date +%Y%m%d).sql

-- Restore from backup if needed
psql stockdb < backup_20241201.sql
```

---

## Contributing

### Development Workflow

1. **Fork the repository** on GitHub
2. **Create a feature branch:**
   ```bash
   git checkout -b feature/new-feature
   ```
3. **Make your changes** following the coding standards
4. **Test thoroughly:**
   - Run scripts on a small dataset first
   - Check for data quality issues
   - Verify outputs match expectations
5. **Update documentation** if needed
6. **Submit a pull request** with a clear description

### Coding Standards

**Python:**
- Use PEP 8 style guide
- Add type hints where appropriate
- Include docstrings for functions
- Handle exceptions gracefully

**R:**
- Use consistent naming conventions
- Add comments for complex logic
- Use `data.table` for performance
- Implement proper error handling

**SQL:**
- Use consistent formatting
- Add comments for complex queries
- Use appropriate indexes
- Optimize for performance

### Testing

**Unit Tests:**
- Test individual functions and scripts
- Use small, known datasets
- Verify outputs match expected results

**Integration Tests:**
- Test complete pipeline end-to-end
- Verify data flows correctly between scripts
- Check database consistency

**Performance Tests:**
- Test with large datasets
- Monitor memory and CPU usage
- Identify bottlenecks

---

## License & Support

### License
This project is licensed under the MIT License. See the LICENSE file for details.

### Support

**For Technical Issues:**
1. Check the troubleshooting section above
2. Review logs in the `log/` directory
3. Search existing issues on GitHub
4. Open a new issue with:
   - Detailed error message
   - Steps to reproduce
   - System information
   - Relevant log files

**For Feature Requests:**
1. Check if the feature already exists
2. Open an issue describing the desired functionality
3. Provide use cases and examples

**For Documentation Issues:**
1. Open an issue with specific suggestions
2. Submit a pull request with improvements

### Community

- **GitHub Issues:** For bug reports and feature requests
- **Discussions:** For general questions and community support
- **Wiki:** For additional documentation and examples

---

*This pipeline is built for reliability, extensibility, and data quality in financial analytics. It provides a solid foundation for stock market analysis and can be extended for additional data sources, features, and analytics.* 