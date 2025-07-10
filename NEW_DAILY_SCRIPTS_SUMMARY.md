# New Daily Scripts Summary

This document summarizes the new daily data ingestion scripts that have been added to the stock market data system.

## Overview

We have successfully created 5 new daily scripts to fetch additional data types from yfinance:

1. **Financial Statements** - Income statements, balance sheets, and cash flow statements
2. **Analyst Recommendations** - Analyst ratings and price targets
3. **Major Holders** - Major shareholders and their holdings
4. **Institutional Holders** - Institutional investors and their holdings
5. **Options Data** - Options chain data with Greeks and volatility

## Script Details

### 1. Financial Statements (`6.2_daily_financial_statements.py`)

**Purpose**: Fetches financial statements data (income statement, balance sheet, cash flow) from yfinance.

**Data Types**:
- Income Statement: Revenue, gross profit, operating income, net income, EPS
- Balance Sheet: Total assets, liabilities, equity, cash, debt
- Cash Flow: Operating, financing, and free cash flow

**Features**:
- Fetches both annual and quarterly data
- Filters to recent data (last 2 years)
- Compares with existing database records
- Inserts only new or changed records
- Handles missing data gracefully

**yfinance Methods Used**:
- `yf_ticker.financials` - Annual income statement
- `yf_ticker.quarterly_financials` - Quarterly income statement
- `yf_ticker.balance_sheet` - Annual balance sheet
- `yf_ticker.quarterly_balance_sheet` - Quarterly balance sheet
- `yf_ticker.cashflow` - Annual cash flow
- `yf_ticker.quarterly_cashflow` - Quarterly cash flow

### 2. Analyst Recommendations (`7.2_daily_analyst_recommendations.py`)

**Purpose**: Fetches analyst recommendations and ratings from yfinance.

**Data Types**:
- Firm and analyst names
- Action (upgrade, downgrade, maintain, initiate)
- Ratings (buy, sell, hold, strong buy, strong sell)
- Price targets
- Recommendation dates

**Features**:
- Fetches both individual and consensus recommendations
- Filters to recent recommendations (last 30 days)
- Maps recommendations to standardized actions
- Handles missing analyst information

**yfinance Methods Used**:
- `yf_ticker.recommendations` - Individual analyst recommendations
- `yf_ticker.recommendations_summary` - Consensus recommendations

### 3. Major Holders (`8.2_daily_major_holders.py`)

**Purpose**: Fetches major shareholders/holders data from yfinance.

**Data Types**:
- Holder names and types (promoter, FII, DII, public, institution)
- Shares held and percentage holdings
- Value of holdings
- Currency information

**Features**:
- Categorizes holders by type based on name analysis
- Fetches both major holders and institutional holders
- Handles percentage conversions
- Includes all holder data (no date filtering needed)

**yfinance Methods Used**:
- `yf_ticker.major_holders` - Major shareholders
- `yf_ticker.institutional_holders` - Institutional holders

### 4. Institutional Holders (`9.2_daily_institutional_holders.py`)

**Purpose**: Fetches institutional holders data from yfinance.

**Data Types**:
- Institution names and types (mutual fund, insurance, pension fund, etc.)
- Shares held and percentage holdings
- Value of holdings
- Currency information

**Features**:
- Categorizes institutions by type (mutual fund, insurance, bank, etc.)
- Fetches both institutional and major holders data
- Filters to institutional entities only
- Handles missing data gracefully

**yfinance Methods Used**:
- `yf_ticker.institutional_holders` - Institutional holders
- `yf_ticker.major_holders` - Major holders (filtered for institutions)

### 5. Options Data (`10.2_daily_options_data.py`)

**Purpose**: Fetches options data from yfinance.

**Data Types**:
- Expiration dates and option types (call/put)
- Strike prices and last traded prices
- Bid/ask spreads
- Volume and open interest
- Greeks (delta, gamma, theta, vega)
- Implied volatility

**Features**:
- Fetches next 3 expiration dates to limit data volume
- Processes both calls and puts
- Handles missing Greeks and volatility data
- Includes all current options data

**yfinance Methods Used**:
- `yf_ticker.options` - Available expiration dates
- `yf_ticker.option_chain(date).calls` - Call options
- `yf_ticker.option_chain(date).puts` - Put options

## Database Tables

All scripts work with the corresponding tables defined in `backend/models.py`:

1. `financial_statements` - Financial statement data
2. `analyst_recommendations` - Analyst recommendations
3. `major_holders` - Major shareholders
4. `institutional_holders` - Institutional holders
5. `options_data` - Options chain data

## Integration

All new scripts have been integrated into the main daily updates workflow (`run_daily_updates.sh`):

- Scripts run in sequence after existing data types
- Each script includes proper error handling and logging
- Duration tracking for performance monitoring
- Summary reporting at the end

## Key Features Across All Scripts

1. **Smart Filtering**: All scripts filter data appropriately for daily updates
2. **Change Detection**: Only insert/update records that have actually changed
3. **Error Handling**: Comprehensive error handling and retry logic
4. **Logging**: Detailed logging to separate log files
5. **Rate Limiting**: Built-in delays to avoid yfinance rate limits
6. **Progress Tracking**: Progress updates every 50 companies
7. **Batch Processing**: Efficient database operations

## Usage

To run all daily updates including the new scripts:

```bash
./run_daily_updates.sh
```

To run individual scripts:

```bash
python data_ingestion/6.2_daily_financial_statements.py
python data_ingestion/7.2_daily_analyst_recommendations.py
python data_ingestion/8.2_daily_major_holders.py
python data_ingestion/9.2_daily_institutional_holders.py
python data_ingestion/10.2_daily_options_data.py
```

## Performance Considerations

- **Financial Statements**: May take longer due to multiple data types and periods
- **Analyst Recommendations**: Generally fast, limited recent data
- **Major/Institutional Holders**: Moderate speed, holder data doesn't change frequently
- **Options Data**: May be slower due to multiple expiration dates and Greeks calculations

## Log Files

Each script creates its own log file in the `log/` directory:

- `daily_financial_statements.log`
- `daily_analyst_recommendations.log`
- `daily_major_holders.log`
- `daily_institutional_holders.log`
- `daily_options_data.log`

## Next Steps

1. **Test the scripts** with a small subset of companies first
2. **Monitor performance** and adjust batch sizes if needed
3. **Review log files** for any data quality issues
4. **Consider scheduling** different scripts at different times to spread the load
5. **Add backup scripts** for the new data types if needed

## Notes

- All scripts follow the same pattern as existing daily scripts
- They use the CSV date approach for consistency
- yfinance limitations are handled gracefully (no date-specific filtering)
- Data is filtered client-side to match the CSV date requirement
- Scripts are designed to be idempotent and safe to re-run 