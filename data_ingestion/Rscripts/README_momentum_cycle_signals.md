# Momentum Cycle Signals Analysis

## Table of Contents
1. [Overview](#overview)
2. [Features](#features)
3. [Input Data Requirements](#input-data-requirements)
4. [Output Columns](#output-columns)
5. [Dynamic Factors](#dynamic-factors)
6. [Database Schema](#database-schema)
7. [Usage](#usage)
8. [Maintenance](#maintenance)
9. [Troubleshooting](#troubleshooting)
10. [Examples](#examples)
11. [FAQ](#faq)
12. [License & Contact](#license--contact)

## Overview
This script analyzes stock price momentum cycles, identifies different stages of market cycles, and generates trading signals with dynamic stop losses and targets. It's designed to help traders identify potential entry and exit points based on technical analysis and stage analysis.

## Features

### Stage Detection Details
Each stage has specific technical characteristics:

#### 0: SETUP
- **Purpose**: Identify potential reversal zones
- **Indicators**: 
  - Low volatility (compression)
  - Declining volume
  - Tight price range
- **Trading Action**: Watch for breakout

#### 1: BREAKOUT
- **Purpose**: Catch early trend starts
- **Indicators**:
  - Price breaks above resistance
  - Volume expansion
  - Moving average crossovers
- **Trading Action**: Consider entry

#### 2: EARLY_MOM
- **Purpose**: Ride the early trend
- **Indicators**:
  - Strong price momentum
  - Rising moving averages
  - Increasing volume
- **Trading Action**: Add to positions

#### 3: SUSTAINED
- **Purpose**: Manage existing trends
- **Indicators**:
  - Strong ADX
  - Steep moving averages
  - Higher highs/lows
- **Trading Action**: Trail stops, take partial profits

#### 4: EXHAUSTION
- **Purpose**: Protect profits
- **Indicators**:
  - Overbought RSI
  - Divergence
  - Climax volume
- **Trading Action**: Tighten stops, prepare to exit

### 1. Stage Detection
- Identifies 5 distinct market stages:
  - **0: SETUP** - Consolidation phase with low volatility
  - **1: BREAKOUT** - Initial breakout from consolidation
  - **2: EARLY_MOM** - Early momentum phase
  - **3: SUSTAINED** - Strong trending phase
  - **4: EXHAUSTION** - Overextended price action

### 2. Dynamic Stop Loss System
- ATR-based stop loss calculation
- Stage-specific stop loss rules
- Time decay and momentum adjustments
- Support/resistance based stops
- Trailing stop functionality

### 3. Rule-Based Analysis
- Multiple technical indicators per stage
- Rule status tracking (✓/✗)
- Partial stage matching
- Dynamic factor adjustments

### 4. Data Output
- CSV files with timestamps
- Database storage with historical tracking
- Detailed trade logs

## Input Data Requirements
- Stock price data (OHLCV)
- Company information (ticker, name)
- Database connection parameters

## Output Columns

### Core Information
- `ticker` - Stock symbol
- `name` - Company name
- `date` - Analysis date
- `close` - Closing price
- `volume` - Trading volume

### Stage Information
- `stage` - Current stage (0-4)
- `stage_name` - Stage description
- `stage_age` - Days in current stage
- `optimal_holding_days` - Recommended holding period
- `days_remaining` - Days left in stage
- `rule_status` - Rule completion (e.g., "2/3")
- `stage_history` - Complete stage progression

### Technical Indicators
- `rsi` - Relative Strength Index
- `adx` - Average Directional Index
- `vol_21d` - 21-day volatility
- `range_contraction` - Recent price range
- `overextension` - Price vs moving average
- `drawdown` - Current drawdown from high

### Trade Management
- `status` - ENTRY/EXIT/HOLD/WATCH
- `stop_loss` - Dynamic stop price
- `stop_pct` - Stop as % of price
- `entry_price` - Entry price (if applicable)
- `exit_price` - Exit price (if applicable)
- `analysis_date` - Date of analysis

## Dynamic Factors Explained

### 1. Volatility Factor
- **Purpose**: Adjust position size and stop distance based on market volatility
- **Calculation**: 
  ```
  vol_factor = min(vol_21d / 0.20, 1.5)
  ```
  - 1.0 = 20% annualized volatility (baseline)
  - >1.0 in high volatility (wider stops)
  - <1.0 in low volatility (tighter stops)

### 2. Momentum Factor
- **Purpose**: Adjust risk based on trend strength
- **Calculation**:
  ```
  momentum_factor = 1 + min(max(return_21d * 5, 0), 1)
  ```
  - Ranges from 1.0 (no momentum) to 2.0 (strong momentum)
  - Allows wider stops in strong trends

### 3. Time Factor
- **Purpose**: Adjust stops as positions age
- **Calculation**:
  ```
  time_factor = max(0.5, 1 - (stage_age / optimal_holding_days) * 0.5)
  ```
  - Starts at 1.0 (new position)
  - Decreases to 0.5 over optimal holding period
  - Never goes below 0.5 to maintain minimum stop distance

### 4. Progress Factor
- **Purpose**: Track price target achievement
- **Calculation**:
  ```
  progress_factor = min((close / entry_price - 1) / target_return, 1)
  ```
  - 0% at entry
  - 100% when target is reached
  - Used for position sizing and profit taking
1. **Volatility Factor**
   - Adjusts stops based on market volatility
   - Normalized to 1.0 at 20% annualized vol

2. **Momentum Factor**
   - Widens stops in strong trends
   - Based on 21-day returns

3. **Time Factor**
   - Tightens stops as positions age
   - Ranges from 1.0 (new) to 0.5 (mature)

4. **Progress Factor**
   - Tracks progress toward price targets
   - Used for position sizing

## Database Schema
```sql
CREATE TABLE momentum_cycle_signals (
    ticker VARCHAR(20),
    name VARCHAR(100),
    date DATE,
    close DECIMAL(12,4),
    volume BIGINT,
    stage INTEGER,
    stage_name VARCHAR(20),
    status VARCHAR(10),
    stage_age INTEGER,
    optimal_holding_days INTEGER,
    days_remaining INTEGER,
    rule_status VARCHAR(20),
    stop_loss DECIMAL(12,4),
    stop_pct DECIMAL(10,4),
    rsi DECIMAL(10,4),
    adx DECIMAL(10,4),
    vol_21d DECIMAL(10,4),
    range_contraction DECIMAL(10,4),
    overextension DECIMAL(10,4),
    drawdown DECIMAL(10,4),
    trade_log TEXT,
    analysis_date DATE,
    entry_price DECIMAL(12,4),
    exit_price DECIMAL(12,4),
    entry_date DATE,
    exit_date DATE
);
CREATE INDEX idx_momentum_cycle_ticker_date ON momentum_cycle_signals(ticker, analysis_date);
```

## Usage

### Prerequisites
- R (v4.0+)
- Required R packages:
  - data.table
  - RPostgres
  - TTR
  - stringr

### Environment Variables
Set these in your environment or `.Renviron` file:
```
PGDATABASE=your_database
PGHOST=your_host
PGPORT=5432
PGUSER=your_username
PGPASSWORD=your_password
```

### Running the Script
```bash
Rscript momentum_cycle_signals.R
```

### Output Files
- CSV files in `output/` directory with timestamped filenames
- Database table `momentum_cycle_signals` with historical data

## Maintenance

### Data Retention
- The script appends new records with each run
- Consider periodic archiving of old data
- Use `analysis_date` for filtering recent data

### Performance Tips
- The database index on (ticker, analysis_date) improves query performance
- For large datasets, consider partitioning by date
- Run during off-peak hours for production use

## Troubleshooting

### Common Issues
1. **Database Connection**
   - Verify environment variables are set
   - Check network connectivity
   - Ensure user has proper permissions

2. **Missing Data**
   - Verify input data covers required lookback period
   - Check for data gaps or holidays

3. **Performance**
   - Monitor query performance
   - Consider adding additional indexes if needed
   - Review database maintenance tasks

## Examples

### Example 1: Basic Usage
```r
# Load required libraries
library(data.table)
library(RPostgres)

# Run the analysis
source("momentum_cycle_signals.R")
results <- main()

# View results
head(results[status == "ENTRY", .(ticker, stage_name, close, stop_loss, stop_pct)])
```

### Example 2: Querying the Database
```sql
-- Get latest signals for a specific ticker
SELECT * 
FROM momentum_cycle_signals 
WHERE ticker = 'AAPL' 
ORDER BY analysis_date DESC 
LIMIT 5;

-- Find all current ENTRY signals
SELECT ticker, stage_name, close, stop_loss, stop_pct, analysis_date
FROM momentum_cycle_signals 
WHERE status = 'ENTRY' 
  AND analysis_date = (SELECT MAX(analysis_date) FROM momentum_cycle_signals);
```

## FAQ

### Q: How often should I run this script?
A: For daily analysis, run it after market close. The script appends new data, so you'll maintain a complete history.

### Q: How do I interpret the stage numbers?
- 0: SETUP - Consolidation/Low Volatility
- 1: BREAKOUT - Initial Move
- 2: EARLY_MOM - Early Trend
- 3: SUSTAINED - Strong Trend
- 4: EXHAUSTION - Potential Reversal

### Q: What's the difference between status and stage?
- `status`: Action to take (ENTRY/EXIT/HOLD/WATCH)
- `stage`: Current market phase (0-4)

### Q: How are stop losses calculated?
Stops are based on:
- ATR (volatility)
- Recent swing lows
- Moving averages
- Time in trade
- Market phase

### Q: Can I modify the rules for each stage?
Yes, edit the `stage_defs` list in the script to adjust rules and parameters for each stage.

## License
MIT License

## Author
[Your Name]  
[Your Email]  
[Your Organization]  
[Date: 2025-08-16]
