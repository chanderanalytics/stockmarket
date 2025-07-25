# Stock Market Data Pipeline & Analytics Platform

A modern, production-grade pipeline for ingesting, processing, and analyzing Indian stock market data, with robust support for Power BI dashboards and advanced analytics.

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

```
Screener CSV/Manual List ──▶ Companies Table
                                 │
                                 ▼
                        [Batch/Vectorized ETL]
                                 │
                                 ▼
         Prices Table ──▶ Feature Engineering ──▶ Wide Analytics Tables
                                 │
                                 ▼
                        Power BI Dashboard
```

- **Raw data** (CSV, yfinance API) ingested into normalized tables (`companies`, `prices`, `corporate_actions`, etc.)
- **Batch & vectorized scripts** process and engineer features in R/Python
- **Wide tables** (one row per company) are created for analytics and dashboarding
- **Power BI** connects directly to these wide tables for rich, interactive insights

---

## Key Tables & Outputs

| Table Name                                 | Description                                                      |
|--------------------------------------------|------------------------------------------------------------------|
| `companies`                               | Company metadata (name, sector, industry, market cap, etc.)      |
| `prices`                                  | Daily OHLCV price and volume data                                |
| `corporate_actions`                       | Splits, dividends, and other actions                             |
| `corp_action_flags`                       | Company features + corporate action flags/types                  |
| `merged_price_baseline_probabilities_wide` | Wide table: price return probabilities/features (1 row/company)  |
| `merged_volume_baseline_probabilities_wide`| Wide table: volume change probabilities/features (1 row/company) |
| `merged_price_spike_probabilities_wide`    | Wide table: price spike probabilities (1 row/company)            |
| `merged_volume_spike_probabilities_wide`   | Wide table: volume spike probabilities (1 row/company)           |

- All wide tables are joined on `company_id` to `companies` and `corp_action_flags`.
- These are the main sources for Power BI and analytics.

---

## Directory Structure

```
stockmkt/
├── backend/                # SQLAlchemy models, DB config
├── data_ingestion/
│   ├── onetime/            # One-time import scripts (Python)
│   ├── Rscripts/           # R scripts for feature engineering, analytics
│   ├── archived_scripts/   # Old/deprecated scripts
│   └── ...                 # Batch, vectorized, and daily scripts
├── log/                    # Timestamped log files
├── output/                 # All CSV outputs for Power BI, QA, etc.
├── migrations/             # Alembic DB migrations
├── run_*.sh                # Job runner scripts
└── requirements.txt        # Python dependencies
```

---

## Setup & Prerequisites

### System Requirements
- Python 3.8+
- R 4.0+
- PostgreSQL 12+
- Power BI Desktop (for dashboarding)
- 4GB+ RAM, 10GB+ free disk space

### Install Python Dependencies
```bash
pip install -r requirements.txt
```

### Install R Dependencies
- Open R and run:
```r
install.packages(c('data.table', 'DBI', 'RPostgres', 'futile.logger', 'zoo'))
```

### Database Setup
```bash
sudo -u postgres createdb stockdb
sudo -u postgres createuser stockuser
sudo -u postgres psql -c "ALTER USER stockuser WITH PASSWORD 'stockpass';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE stockdb TO stockuser;"
```

---

## How to Run the Pipeline

### One-time Historical Import
Run all onetime scripts in sequence:
```bash
python3 data_ingestion/onetime/1.1_import_screener_companies.py data_ingestion/screener_export.csv
python3 data_ingestion/onetime/2.1_onetime_prices.py
python3 data_ingestion/onetime/3.1_onetime_corporate_actions.py
python3 data_ingestion/onetime/4.1_onetime_indices.py
```

### Daily/Incremental Updates
- Use daily scripts to fetch and upsert only new data (prices, actions, indices, etc.)
- All scripts accept `--days` or date arguments for flexible backfilling

### Batch & Vectorized Processing
- For large datasets, R scripts process companies in batches (default: 500 per batch)
- Batch outputs are recombined and merged with corporate action flags for final wide tables
- If a batch fails, use `5b_recombine_batches_and_merge.R` to recover and finish from CSVs

---

## R Scripts & Feature Engineering

- All R scripts are in `data_ingestion/Rscripts/`
- **Key scripts:**
  - `2_companies_insights.R`: Company-level features, rankings, deciles, outliers
  - `3_companies_prices_features.R`: Price-based features (returns, volatility, etc.)
  - `4_corporate_action_flags.R`: Joins company features with corporate action flags
  - `5_price_volume_probabilities_vectorized.R`: Vectorized calculation of price/volume probabilities (batch-ready)
  - `5b_recombine_batches_and_merge.R`: Recombine batch outputs and merge with flags (ad hoc recovery)
- All scripts log progress and data quality to `log/`
- Outputs are written to `output/` and to the database

---

## Power BI Dashboard Integration

- **Connect Power BI to your PostgreSQL DB** or import the wide CSVs from `output/`
- **Main tables for dashboarding:**
  - `merged_price_baseline_probabilities_wide`
  - `merged_volume_baseline_probabilities_wide`
  - `merged_price_spike_probabilities_wide`
  - `merged_volume_spike_probabilities_wide`
  - `companies`, `corp_action_flags`
- **Set up relationships** on `company_id`
- **Key visuals/pages:**
  - Market overview (KPI cards, heatmaps, top/bottom performers)
  - Last day highlights (buzzing sectors/stocks, crashes, actions)
  - Stock drilldown (price/volume chart, peer comparison, corporate actions)
  - Predictive insights (next-day probabilities, alerts)
- **Interactivity:**
  - Slicers/filters for sector, industry, market cap, date, etc.
  - Drilldown from sector to company, company to details
  - Conditional formatting for high price/volume spike probabilities
  - Correlation analysis between price and volume features

---

## Logging, Monitoring & Data Quality

- All scripts log to timestamped files in `log/`
- Logs include start/end times, batch progress, errors, and data quality summaries
- Data quality checks: duplicates, NULLs, out-of-range values
- Smart upserts: only new/changed records are written
- Use logs for debugging, monitoring, and audit trails

---

## Troubleshooting & FAQ

**Q: How do I recover from a failed batch?**
- Use `5b_recombine_batches_and_merge.R` to recombine batch CSVs and finish the pipeline.

**Q: How do I add new features or metrics?**
- Edit the relevant R script (e.g., add new columns to `3_companies_prices_features.R` or `5_price_volume_probabilities_vectorized.R`)

**Q: How do I connect Power BI to my database?**
- Use the PostgreSQL connector in Power BI Desktop, or import the wide CSVs from `output/`

**Q: Where do I find logs and outputs?**
- All logs are in `log/`, all CSV outputs in `output/`

**Q: How do I check for data quality issues?**
- Review the logs for NULLs, duplicates, and out-of-range values. Use the DQ scripts in `Rscripts/` for more checks.

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with a clear description

---

## License & Support

This project is licensed under the MIT License.

**For support:**
- Check the troubleshooting section
- Review logs in `log/`
- Open an issue with detailed error information

---

*Built for reliability, extensibility, and data quality in financial analytics.* 