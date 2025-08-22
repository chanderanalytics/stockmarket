# Price Wide Table - Comprehensive Data Dictionary

## Table: `merged_price_baseline_probabilities_wide`
**Description**: Comprehensive wide table containing price data, fundamental metrics, probability calculations, and derived analytics for stock market analysis.

**Total Columns**: 389  
**Primary Key**: `company_id`  
**Date Range**: Historical price data with derived features

---

## 1. IDENTIFICATION COLUMNS

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `company_id` | text | YES | Unique company identifier | Primary key from yfinance |
| `bse_code` | integer | YES | BSE stock code | Bombay Stock Exchange code |
| `nse_code` | text | YES | NSE stock code | National Stock Exchange code |
| `name` | text | YES | Company name | Full company name |

---

## 2. INDUSTRY CLASSIFICATION

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `industry` | text | YES | Industry classification | Business sector classification |

---

## 3. PRICE & MARKET DATA

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `current_price` | numeric | YES | Current stock price | Latest closing price |
| `market_capitalization` | numeric | YES | Market cap in USD | `shares_outstanding * current_price` |

---

## 4. FINANCIAL PERFORMANCE METRICS

### Revenue & Sales
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `sales` | numeric | YES | Total sales/revenue | Annual revenue |
| `sales_growth_3years` | numeric | YES | 3-year sales growth % | Compound annual growth rate |
| `expected_quarterly_sales` | numeric | YES | Expected quarterly sales | Analyst estimates |

### Profitability Metrics
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `profit_after_tax` | numeric | YES | Net profit after tax | PAT = Revenue - Expenses - Tax |
| `profit_growth_3years` | numeric | YES | 3-year profit growth % | Compound annual growth rate |
| `profit_growth_5years` | numeric | YES | 5-year profit growth % | Compound annual growth rate |
| `operating_profit` | numeric | YES | Operating profit | EBIT = Revenue - Operating Expenses |
| `opm` | numeric | YES | Operating profit margin % | `operating_profit / sales * 100` |
| `expected_quarterly_net_profit` | numeric | YES | Expected quarterly net profit | Analyst estimates |

### Earnings Metrics
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `eps` | numeric | YES | Earnings per share | `net_profit / shares_outstanding` |
| `eps_growth_3years` | numeric | YES | 3-year EPS growth % | Compound annual growth rate |
| `expected_quarterly_eps` | numeric | YES | Expected quarterly EPS | Analyst estimates |

### Return Metrics
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `return_on_capital_employed` | numeric | YES | ROCE percentage | `operating_profit / capital_employed * 100` |
| `return_on_assets` | numeric | YES | ROA percentage | `net_profit / total_assets * 100` |
| `return_on_equity` | numeric | YES | ROE percentage | `net_profit / shareholders_equity * 100` |

---

## 5. BALANCE SHEET METRICS

### Capital Structure
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `debt` | numeric | YES | Total debt | Long-term + short-term debt |
| `equity_capital` | numeric | YES | Equity capital | Paid-up equity capital |
| `preference_capital` | numeric | YES | Preference capital | Preference shares |
| `reserves` | numeric | YES | Reserves and surplus | Retained earnings + reserves |
| `contingent_liabilities` | numeric | YES | Contingent liabilities | Potential future obligations |

### Financial Ratios
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `debt_to_equity` | numeric | YES | Debt-to-equity ratio | `total_debt / shareholders_equity` |
| `price_to_earning` | numeric | YES | P/E ratio | `current_price / eps` |
| `price_to_book_value` | numeric | YES | P/B ratio | `current_price / book_value_per_share` |
| `dividend_yield` | numeric | YES | Dividend yield % | `annual_dividend / current_price * 100` |
| `earnings_yield` | numeric | YES | Earnings yield % | `eps / current_price * 100` |

---

## 6. CASH FLOW METRICS

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `free_cash_flow_3years` | numeric | YES | 3-year free cash flow | Operating cash flow - CapEx |
| `operating_cash_flow_3years` | numeric | YES | 3-year operating cash flow | Cash from operations |

---

## 7. SHAREHOLDING PATTERNS

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `promoter_holding` | numeric | YES | Promoter holding % | Percentage held by promoters |
| `public_holding` | numeric | YES | Public holding % | Retail and other investors |
| `fii_holding` | numeric | YES | FII holding % | Foreign institutional investors |
| `change_in_promoter_holding_3years` | numeric | YES | 3-year promoter holding change % | Change in promoter stake |
| `pledged_percentage` | numeric | YES | Pledged shares % | Percentage of shares pledged |

---

## 8. OPERATIONAL METRICS

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `inventory_turnover_ratio` | numeric | YES | Inventory turnover | `cost_of_goods_sold / average_inventory` |
| `asset_turnover_ratio` | numeric | YES | Asset turnover | `sales / total_assets` |
| `financial_leverage` | numeric | YES | Financial leverage | `total_assets / shareholders_equity` |
| `working_capital_days` | numeric | YES | Working capital days | Days of working capital |
| `exports_percentage` | numeric | YES | Exports as % of sales | `exports / sales * 100` |

---

## 9. SHARE INFORMATION

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `number_of_equity_shares` | bigint | YES | Number of equity shares | Total shares outstanding |
| `number_of_shareholders` | integer | YES | Number of shareholders | Total shareholder count |
| `book_value` | numeric | YES | Book value per share | `shareholders_equity / shares_outstanding` |

---

## 10. OTHER INCOME & EXPENSES

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `other_income` | numeric | YES | Other income | Non-operating income |

---

## 11. PRICE RETURNS & VOLATILITY

### Daily Returns
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `return_1d` | numeric | YES | 1-day return | `(close_today - close_yesterday) / close_yesterday` |
| `return_5d` | numeric | YES | 5-day return | `(close_today - close_5d_ago) / close_5d_ago` |
| `return_21d` | numeric | YES | 21-day return | `(close_today - close_21d_ago) / close_21d_ago` |

### Volatility Measures
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `volatility_5d` | numeric | YES | 5-day volatility | `STDDEV(returns_5d)` |
| `volatility_21d` | numeric | YES | 21-day volatility | `STDDEV(returns_21d)` |

### Price Volatility (PVOL) - Multiple Timeframes
**Description**: Price volatility calculated over different time periods using log returns

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `pvol_1d` | numeric | YES | 1-day price volatility | NA (needs >1 return) |
| `pvol_2d` | numeric | YES | 2-day price volatility | `100 * STDDEV(log_returns_2d)` |
| `pvol_3d` | numeric | YES | 3-day price volatility | `100 * STDDEV(log_returns_3d)` |
| `pvol_4d` | numeric | YES | 4-day price volatility | `100 * STDDEV(log_returns_4d)` |
| `pvol_5d` | numeric | YES | 5-day price volatility | `100 * STDDEV(log_returns_5d)` |
| `pvol_21d` | numeric | YES | 21-day price volatility | `100 * STDDEV(log_returns_21d)` |
| `pvol_63d` | numeric | YES | 63-day price volatility | `100 * STDDEV(log_returns_63d)` |
| `pvol_126d` | numeric | YES | 126-day price volatility | `100 * STDDEV(log_returns_126d)` |
| `pvol_252d` | numeric | YES | 252-day price volatility | `100 * STDDEV(log_returns_252d)` |
| `pvol_504d` | numeric | YES | 504-day price volatility | `100 * STDDEV(log_returns_504d)` |
| `pvol_756d` | numeric | YES | 756-day price volatility | `100 * STDDEV(log_returns_756d)` |
| `pvol_1260d` | numeric | YES | 1260-day price volatility | `100 * STDDEV(log_returns_1260d)` |
| `pvol_2520d` | numeric | YES | 2520-day price volatility | `100 * STDDEV(log_returns_2520d)` |

### Volume Volatility (VVOL) - Multiple Timeframes
**Description**: Volume volatility calculated over different time periods using log of volumes

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `vvol_21d` | numeric | YES | 21-day volume volatility | `100 * STDDEV(log(volumes_21d))` |
| `vvol_126d` | numeric | YES | 126-day volume volatility | `100 * STDDEV(log(volumes_126d))` |
| `vvol_1260d` | numeric | YES | 1260-day volume volatility | `100 * STDDEV(log(volumes_1260d))` |
| `vvol_2520d` | numeric | YES | 2520-day volume volatility | `100 * STDDEV(log(volumes_2520d))` |

**Note**: 
- **PVOL**: Price volatility using log returns, expressed as percentage
- **VVOL**: Volume volatility using log of volumes, expressed as percentage
- **Timeframes**: 1d, 2d, 3d, 4d, 5d, 21d, 63d, 126d, 252d, 504d, 756d, 1260d, 2520d
- **Calculation**: Standard deviation of log returns/volumes multiplied by 100

---

## 12. PRICE RETURN PROBABILITIES (1-100%)

**Description**: Probability of achieving specific return ranges based on historical analysis

| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `price_return_1_5` | numeric | YES | Probability of 1-5% return | Historical probability calculation |
| `price_return_5_10` | numeric | YES | Probability of 5-10% return | Historical probability calculation |
| `price_return_10_15` | numeric | YES | Probability of 10-15% return | Historical probability calculation |
| `price_return_15_20` | numeric | YES | Probability of 15-20% return | Historical probability calculation |
| `price_return_20_25` | numeric | YES | Probability of 20-25% return | Historical probability calculation |
| `price_return_25_30` | numeric | YES | Probability of 25-30% return | Historical probability calculation |
| `price_return_30_35` | numeric | YES | Probability of 30-35% return | Historical probability calculation |
| `price_return_35_40` | numeric | YES | Probability of 35-40% return | Historical probability calculation |
| `price_return_40_45` | numeric | YES | Probability of 40-45% return | Historical probability calculation |
| `price_return_45_50` | numeric | YES | Probability of 45-50% return | Historical probability calculation |
| `price_return_50_55` | numeric | YES | Probability of 50-55% return | Historical probability calculation |
| `price_return_55_60` | numeric | YES | Probability of 55-60% return | Historical probability calculation |
| `price_return_60_65` | numeric | YES | Probability of 60-65% return | Historical probability calculation |
| `price_return_65_70` | numeric | YES | Probability of 65-70% return | Historical probability calculation |
| `price_return_70_75` | numeric | YES | Probability of 70-75% return | Historical probability calculation |
| `price_return_75_80` | numeric | YES | Probability of 75-80% return | Historical probability calculation |
| `price_return_80_85` | numeric | YES | Probability of 80-85% return | Historical probability calculation |
| `price_return_85_90` | numeric | YES | Probability of 85-90% return | Historical probability calculation |
| `price_return_90_95` | numeric | YES | Probability of 90-95% return | Historical probability calculation |
| `price_return_95_100` | numeric | YES | Probability of 95-100% return | Historical probability calculation |

---

## 13. DECILE RANKINGS (1-10)

**Description**: All financial metrics ranked into deciles (1 = top 10%, 10 = bottom 10%)

### Profitability Deciles
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `return_on_equity_decile` | text | YES | ROE decile ranking | `RANK(-roe_value)` |
| `return_on_assets_decile` | text | YES | ROA decile ranking | `RANK(-roa_value)` |
| `net_profit_margin_decile` | text | YES | Net profit margin decile | `RANK(-margin_value)` |
| `operating_profit_margin_decile` | text | YES | Operating margin decile | `RANK(-opm_value)` |

### Growth Deciles
| Column Name | Data Type | Nullable | Description | Formula/Business Logic |
|-------------|-----------|----------|-------------|------------------------|
| `sales_growth_3years_decile`