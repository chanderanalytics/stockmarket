# Stock Market Database - Data Dictionary

## Overview
This document provides a comprehensive description of all tables, columns, formulas, and business logic in the stock market database. The database contains financial data, price information, corporate actions, and derived analytics for stock market analysis.

---

## Table: `companies`
**Description**: Core company information and fundamental data

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key, auto-increment | `nextval('companies_id_seq')` |
| `company_id` | text | YES | Unique company identifier | From yfinance ticker |
| `name` | text | YES | Company name | Full company name |
| `sector` | text | YES | Business sector | Industry classification |
| `industry` | text | YES | Specific industry | Sub-sector classification |
| `market_capitalization` | numeric | YES | Market cap in USD | `shares_outstanding * current_price` |
| `enterprise_value` | numeric | YES | Enterprise value in USD | `market_cap + total_debt - cash` |
| `return_on_equity` | numeric | YES | ROE percentage | `net_income / shareholders_equity * 100` |
| `return_on_assets` | numeric | YES | ROA percentage | `net_income / total_assets * 100` |
| `net_profit_margin` | numeric | YES | Net profit margin % | `net_income / revenue * 100` |
| `revenue_growth` | numeric | YES | Revenue growth % | `(current_revenue - prev_revenue) / prev_revenue * 100` |
| `ebitda_margin` | numeric | YES | EBITDA margin % | `ebitda / revenue * 100` |
| `sales_growth_3years` | numeric | YES | 3-year sales growth % | Compound annual growth rate |
| `profit_growth_3years` | numeric | YES | 3-year profit growth % | Compound annual growth rate |
| `eps_growth_3years` | numeric | YES | 3-year EPS growth % | Compound annual growth rate |
| `expected_quarterly_sales` | numeric | YES | Expected quarterly sales | Analyst estimates |
| `expected_quarterly_eps` | numeric | YES | Expected quarterly EPS | Analyst estimates |
| `expected_quarterly_net_profit` | numeric | YES | Expected quarterly net profit | Analyst estimates |
| `price_to_earning` | numeric | YES | P/E ratio | `current_price / eps` |
| `price_to_book_value` | numeric | YES | P/B ratio | `current_price / book_value_per_share` |
| `debt_to_equity` | numeric | YES | Debt-to-equity ratio | `total_debt / shareholders_equity` |
| `peg_ratio` | numeric | YES | PEG ratio | `pe_ratio / eps_growth_rate` |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated on changes |

---

## Table: `prices`
**Description**: Historical stock price data

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key, auto-increment | `nextval('prices_id_seq')` |
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Trading date | Date of price data |
| `open` | numeric | YES | Opening price | First trade of the day |
| `high` | numeric | YES | Highest price | Maximum price during day |
| `low` | numeric | YES | Lowest price | Minimum price during day |
| `close` | numeric | YES | Closing price | Last trade of the day |
| `adj_close` | numeric | YES | Adjusted closing price | Adjusted for splits/dividends |
| `volume` | bigint | YES | Trading volume | Number of shares traded |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated on changes |

---

## Table: `composite_quality_scores`
**Description**: Composite quality scoring for companies based on multiple financial metrics

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `composite_score` | double precision | YES | Raw sum of all decile values | `SUM(all_decile_values)` |
| `normalized_composite_score` | double precision | YES | Average decile score | `composite_score / valid_deciles_count` |
| `avg_composite_score` | double precision | YES | Average of decile values | `AVERAGE(all_decile_values)` |
| `composite_decile` | text | YES | Quality decile (1-10) | `CUT(normalized_score, 10_bins)` |
| `composite_quintile` | text | YES | Quality quintile (1-5) | `CUT(normalized_score, 5_bins)` |
| `is_top_10_percent` | boolean | YES | Top 10% indicator | `composite_decile = "1"` |
| `is_top_20_percent` | boolean | YES | Top 20% indicator | `composite_quintile = "1"` |
| `quality_tier` | text | YES | Quality classification | Based on composite_decile |
| `valid_deciles_count` | integer | YES | Number of valid deciles used | Count of non-null deciles |
| `avg_decile` | double precision | YES | Average decile value | `AVERAGE(decile_values)` |

**Quality Tier Classification:**
- **High Quality**: composite_decile 1-2
- **Medium Quality**: composite_decile 3-5  
- **Low Quality**: composite_decile 6-8
- **Poor Quality**: composite_decile 9-10

**Raw Value Columns** (for cross-checking):
- `return_on_equity`, `return_on_assets`, `net_profit_margin`
- `sales_growth_3years`, `profit_growth_3years`, `eps_growth_3years`
- `expected_quarterly_sales`, `expected_quarterly_eps`, `expected_quarterly_net_profit`
- `price_to_earning`, `price_to_book_value`, `debt_to_equity`, `peg_ratio`

**Decile Value Columns** (for verification):
- All corresponding `_decile` columns for the above raw values

**Usage Flag Columns** (boolean indicators):
- `used_roe_decile`, `used_roa_decile`, etc. (indicates which deciles were used in calculation)

---

## Table: `merged_price_baseline_probabilities_wide`
**Description**: Wide table with price data, features, and probability calculations

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `company_id` | text | YES | Company identifier | Primary key |
| `date` | date | YES | Trading date | Date of data |
| `adj_close` | numeric | YES | Adjusted closing price | From prices table |
| `volume` | bigint | YES | Trading volume | From prices table |
| `return_1d` | numeric | YES | 1-day return | `(close_today - close_yesterday) / close_yesterday` |
| `return_5d` | numeric | YES | 5-day return | `(close_today - close_5d_ago) / close_5d_ago` |
| `return_21d` | numeric | YES | 21-day return | `(close_today - close_21d_ago) / close_21d_ago` |
| `volatility_5d` | numeric | YES | 5-day volatility | `STDDEV(returns_5d)` |
| `volatility_21d` | numeric | YES | 21-day volatility | `STDDEV(returns_21d)` |
| `price_return_1_5` | numeric | YES | Probability of 1-5% return | Calculated probability |
| `price_return_5_10` | numeric | YES | Probability of 5-10% return | Calculated probability |
| `price_return_10_15` | numeric | YES | Probability of 10-15% return | Calculated probability |
| `price_return_15_20` | numeric | YES | Probability of 15-20% return | Calculated probability |
| `price_return_20_25` | numeric | YES | Probability of 20-25% return | Calculated probability |
| `price_return_25_30` | numeric | YES | Probability of 25-30% return | Calculated probability |
| `price_return_30_35` | numeric | YES | Probability of 30-35% return | Calculated probability |
| `price_return_35_40` | numeric | YES | Probability of 35-40% return | Calculated probability |
| `price_return_40_45` | numeric | YES | Probability of 40-45% return | Calculated probability |
| `price_return_45_50` | numeric | YES | Probability of 45-50% return | Calculated probability |
| `price_return_50_55` | numeric | YES | Probability of 50-55% return | Calculated probability |
| `price_return_55_60` | numeric | YES | Probability of 55-60% return | Calculated probability |
| `price_return_60_65` | numeric | YES | Probability of 60-65% return | Calculated probability |
| `price_return_65_70` | numeric | YES | Probability of 65-70% return | Calculated probability |
| `price_return_70_75` | numeric | YES | Probability of 70-75% return | Calculated probability |
| `price_return_75_80` | numeric | YES | Probability of 75-80% return | Calculated probability |
| `price_return_80_85` | numeric | YES | Probability of 80-85% return | Calculated probability |
| `price_return_85_90` | numeric | YES | Probability of 85-90% return | Calculated probability |
| `price_return_90_95` | numeric | YES | Probability of 90-95% return | Calculated probability |
| `price_return_95_100` | numeric | YES | Probability of 95-100% return | Calculated probability |

**Decile Columns** (for all financial metrics):
- `return_on_equity_decile`, `return_on_assets_decile`, etc.
- **Formula**: `RANK(-value)` for higher-is-better metrics, `RANK(value)` for lower-is-better metrics
- **Range**: 1-10 (1 = top 10%, 10 = bottom 10%)

---

## Table: `merged_volume_baseline_probabilities_wide`
**Description**: Wide table with volume data and probability calculations

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `company_id` | text | YES | Company identifier | Primary key |
| `date` | date | YES | Trading date | Date of data |
| `volume` | bigint | YES | Trading volume | From prices table |
| `volume_return_1_5` | numeric | YES | Probability of 1-5% volume change | Calculated probability |
| `volume_return_5_10` | numeric | YES | Probability of 5-10% volume change | Calculated probability |
| ... (similar pattern for all volume return probabilities) | | | | |

---

## Table: `corporate_actions`
**Description**: Corporate action events (splits, dividends, etc.)

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Action date | Date of corporate action |
| `action_type` | text | YES | Type of action | 'split', 'dividend', etc. |
| `value` | numeric | YES | Action value | Split ratio, dividend amount |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Table: `corp_action_flags`
**Description**: Flags for days with corporate actions

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Trading date | Date of flag |
| `has_corp_action` | boolean | YES | Corporate action flag | `TRUE` if action exists |
| `action_type` | text | YES | Type of action | From corporate_actions table |

---

## Table: `indices`
**Description**: Market indices information

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `index_id` | text | YES | Index identifier | e.g., '^GSPC' for S&P 500 |
| `name` | text | YES | Index name | Full index name |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Table: `index_prices`
**Description**: Historical index price data

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `index_id` | text | YES | Index identifier | Foreign key to indices |
| `date` | date | YES | Trading date | Date of price data |
| `open` | numeric | YES | Opening price | First trade of the day |
| `high` | numeric | YES | Highest price | Maximum price during day |
| `low` | numeric | YES | Lowest price | Minimum price during day |
| `close` | numeric | YES | Closing price | Last trade of the day |
| `adj_close` | numeric | YES | Adjusted closing price | Adjusted for splits |
| `volume` | bigint | YES | Trading volume | Number of shares traded |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Table: `analyst_recommendations`
**Description**: Analyst recommendations and ratings

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Recommendation date | Date of recommendation |
| `recommendation` | text | YES | Analyst recommendation | 'Buy', 'Hold', 'Sell', etc. |
| `target_price` | numeric | YES | Target price | Analyst's price target |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Table: `financial_statements`
**Description**: Financial statement data

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Statement date | Date of financial statement |
| `statement_type` | text | YES | Type of statement | 'income', 'balance', 'cash_flow' |
| `data` | jsonb | YES | Financial data | JSON structure of financial data |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Table: `fundamentals`
**Description**: Fundamental financial metrics

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Data date | Date of fundamental data |
| `metric_name` | text | YES | Metric name | Name of financial metric |
| `value` | numeric | YES | Metric value | Actual metric value |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Table: `shareholding_patterns`
**Description**: Shareholding pattern data

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Pattern date | Date of shareholding data |
| `promoter_holding` | numeric | YES | Promoter holding % | Percentage held by promoters |
| `fii_holding` | numeric | YES | FII holding % | Foreign institutional investors |
| `dii_holding` | numeric | YES | DII holding % | Domestic institutional investors |
| `public_holding` | numeric | YES | Public holding % | Retail and other investors |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Table: `major_holders`
**Description**: Major shareholders information

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Data date | Date of holder data |
| `holder_name` | text | YES | Holder name | Name of major shareholder |
| `shares_held` | bigint | YES | Shares held | Number of shares owned |
| `percentage` | numeric | YES | Holding percentage | Percentage of total shares |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Table: `institutional_holders`
**Description**: Institutional shareholders information

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Data date | Date of institutional data |
| `institution_name` | text | YES | Institution name | Name of institutional investor |
| `shares_held` | bigint | YES | Shares held | Number of shares owned |
| `percentage` | numeric | YES | Holding percentage | Percentage of total shares |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Table: `options_data`
**Description**: Options trading data

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `id` | integer | NO | Primary key | Auto-increment |
| `company_id` | text | YES | Company identifier | Foreign key to companies |
| `date` | date | YES | Trading date | Date of options data |
| `strike_price` | numeric | YES | Strike price | Option strike price |
| `expiration_date` | date | YES | Expiration date | Option expiration date |
| `option_type` | text | YES | Option type | 'call' or 'put' |
| `open_interest` | integer | YES | Open interest | Number of open contracts |
| `volume` | integer | YES | Trading volume | Number of contracts traded |
| `implied_volatility` | numeric | YES | Implied volatility | Calculated IV |
| `last_modified` | timestamp without time zone | YES | Last update timestamp | Auto-updated |

---

## Key Relationships

1. **companies** ↔ **prices**: `companies.company_id = prices.company_id`
2. **companies** ↔ **composite_quality_scores**: `companies.company_id = composite_quality_scores.company_id`
3. **companies** ↔ **corporate_actions**: `companies.company_id = corporate_actions.company_id`
4. **indices** ↔ **index_prices**: `indices.index_id = index_prices.index_id`

---

## Data Quality Notes

- **Decile Calculations**: All decile columns use `RANK()` function with proper ordering
- **Probability Calculations**: Based on historical distribution analysis
- **Corporate Actions**: Automatically flagged in price data
- **Data Completeness**: Composite scores handle missing data with normalization
- **Last Modified**: All tables have automatic timestamp updates

---

## Power BI Integration Notes

- **Primary Key**: Use `company_id` for relationships
- **Date Dimension**: Use `date` columns for time-based analysis
- **Quality Filter**: Use `composite_quality_scores.quality_tier` for filtering
- **Probability Measures**: Use probability columns for risk analysis
- **Decile Analysis**: Use decile columns for ranking and comparison

---

*Last Updated: August 1, 2025*
*Database Version: 1.0* 