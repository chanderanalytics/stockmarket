# Frontend Data Sources

Maps every frontend page/component to the best existing PostgreSQL source.

**Rule**: Reuse existing analytics tables and views. Do not create new tables or views unless an equivalent does not exist.

---

## Pages

### Home (`/`)
- **Status**: Static landing page
- **Data source**: None
- **Notes**: No database query needed

### Dashboard (`/dashboard`)
- **Market indices**: `indices` + `index_prices`
- **Top gainers/losers**: `companies_with_price_features_with_corp_action_flags` (order by `return_over_1year` or `pchg_1d`)
- **Portfolio summary**: `vw_portfolio` or `trade_details` + `companies`
- **Watchlist**: `vw_watchlist` or `trade_details` + `companies`
- **Market pulse**: `vw_market_pulse`
- **Sector heatmap**: `vw_sector_snapshot`

### Markets (`/markets`)
- **Indices**: `indices` + `index_prices`
- **Movers (gainers/losers)**: `companies_with_price_features_with_corp_action_flags`
- **Sector performance**: `vw_sector_snapshot`
- **Market breadth**: `vw_market_breadth`

### Stock Detail (`/stocks/[symbol]`)
- **Company info**: `companies` or `vw_stock_snapshot`
- **Price history**: `prices_bhavcopy_2` (latest 252 days)
- **Indicators/trend**: `vw_stock_snapshot` (phi_21d, phi_50d, phi_252d, pchg_*, pvol_*)
- **Probability**: `vw_probability` or `merged_price_baseline_probabilities_wide`
- **Signal/rating**: `vw_trading_opportunities`
- **Quality scores**: `companies_with_price_features_with_corp_action_flags` (quality_score, value_score_composite)

### Screener (`/screener`)
- **Company list**: `companies_with_price_features_with_corp_action_flags`
- **Filters**: `quality_score`, `leverage_risk`, `return_over_1year`, `market_capitalization`, `industry`
- **Sort**: Any numeric column from the analytics table

### Watchlist (`/watchlist`)
- **Watchlist items**: `vw_watchlist` or `trade_details` (status = 'open')
- **Current prices**: `companies.current_price` or `vw_stock_snapshot`
- **Changes**: `vw_watchlist.change_pct`

### Portfolio (`/portfolio`)
- **Holdings**: `vw_portfolio` or `trade_details` + `companies`
- **Current values**: `companies.current_price`
- **P&L**: Computed from `trade_details.entry_price` and `companies.current_price`
- **Sector allocation**: `vw_portfolio.sector`

### Settings (`/settings`)
- **Status**: Static/preferences page
- **Data source**: None

---

## API Endpoints → Database Mapping

| Frontend API | Current Source | Recommended DB Source |
|---|---|---|
| `GET /api/market/pulse` | `MarketRuntime.pulse()` (mock) | `vw_market_pulse` |
| `GET /api/market/breadth` | `MarketRuntime.breadth()` (mock) | `vw_market_breadth` |
| `GET /api/market/regime` | `MarketRuntime.regime()` (mock) | Derived from `vw_market_breadth` + `vw_market_pulse` |
| `GET /api/market/sectors` | `MarketRuntime.sectors()` (mock) | `vw_sector_snapshot` |
| `GET /api/stocks/[symbol]/snapshot` | `MarketRuntime.stockSnapshot()` (mock) | `vw_stock_snapshot` + `prices_bhavcopy_2` |
| `GET /api/signals` | `MarketRuntime.signals()` (mock) | `vw_trading_opportunities` |
| `GET /api/opportunities` | `MarketRuntime.opportunities()` (mock) | `vw_trading_opportunities` (filter rating IN ('buy', 'strong_buy')) |
| `GET /api/portfolio/summary` | `MarketRuntime.portfolioSummary()` (mock) | `vw_portfolio` |
| `GET /api/watchlist` | `MarketRuntime.watchlistSummary()` (mock) | `vw_watchlist` |
| `GET /api/knowledge/*` | `KnowledgeRuntime` (mock) | Derived from domain models backed by views above |
| `GET /api/volume-profile` | `VolumeProfileRepository` | `merged_price_baseline_probabilities_wide` (single table, no join) |

### Volume Profile (`GET /api/volume-profile`)

Source: `merged_price_baseline_probabilities_wide` only. No new table, no duplicate
calculation — filtering/aggregation/sorting/pagination are all done in SQL.

Required metric -> physical column mapping:

| Logical | Physical column |
|---|---|
| Company | `name` / `nse_code` (id) |
| Sector | `Sector.Name_bse` |
| Industry | `Industry.New.Name_bse` |
| IndustrySubGroup | `ISubgroup.Name_bse` (the plain `industry` column equals this subgroup) |
| MarketCap | `market_capitalization` |
| MarketCapBucket | `cap_class` (`top 10perc by mcap` / `50-90% by mcap` / `bottom 50% by mcap`) |
| Volume | `volume` |
| AvgVol_1W | `volume_1week_average` |
| AvgVol_1M | `volume_1month_average` |
| AvgVol_1Y | `volume_1year_average` |
| VolSortPct | `volume_vs_1year_avg` (a **multiple** of 1Y avg, e.g. 27.1x — not a %) |
| Rank | **Not stored** — computed server-side (1-based, by `sortMetric`) |

Hierarchy drill-down: `sector -> industry -> industrySubGroup -> company` (one level
returned per request via `hierarchyLevel` + `parent`).

---

## Domain Model → Database Mapping

| Domain Model | Primary DB Source | Notes |
|---|---|---|
| `MarketPulse` | `vw_market_pulse` | Direct mapping |
| `MarketBreadth` | `vw_market_breadth` | Direct mapping |
| `MarketRegime` | Derived | From `vw_market_breadth` + `vw_market_pulse` |
| `SectorSnapshot` | `vw_sector_snapshot` | Direct mapping |
| `StockSnapshot` | `vw_stock_snapshot` + `companies` | Join for name/exchange |
| `StockTrend` | `vw_stock_snapshot` | phi_* columns as MAs |
| `StockMomentum` | `vw_stock_snapshot` | pchg_* columns |
| `ProbabilityAnalysis` | `vw_probability` | Map return buckets |
| `TradingSignal` | `vw_trading_opportunities` | Map rating/confidence |
| `TradingOpportunity` | `vw_trading_opportunities` | Direct mapping |
| `DecisionSummary` | Derived | From breadth + regime + signals |
| `WatchlistSummary` | `vw_watchlist` | Direct mapping |
| `PortfolioSummary` | `vw_portfolio` | Aggregate from trade_details |
| `ResearchSnapshot` | `composite_quality_scores` + `companies` | Join required |

---

## Views Created

The following views were created to support frontend data consumption:

| View | Purpose | Based On |
|---|---|---|
| `vw_market_pulse` | Market sentiment | `companies_with_price_features_with_corp_action_flags` |
| `vw_market_breadth` | Breadth metrics | `companies_with_price_features_with_corp_action_flags` |
| `vw_sector_snapshot` | Sector aggregates | `companies_with_price_features_with_corp_action_flags` |
| `vw_stock_snapshot` | Stock snapshot | `companies_with_price_features_with_corp_action_flags` |
| `vw_probability` | Probability analysis | `merged_price_baseline_probabilities_wide` |
| `vw_trading_opportunities` | Signals/opportunities | `companies_with_price_features_with_corp_action_flags` |
| `vw_portfolio` | Portfolio with P&L | `trade_details` + `companies` |
| `vw_watchlist` | Active watchlist | `trade_details` + `companies` |

---

## Recommendations

1. **Start with views**: All frontend pages can be powered by the 8 views above. No new tables needed.
2. **Keep repositories thin**: Repositories should SELECT from views and map to domain models. No business logic.
3. **Symbol normalization**: DB uses `nse_code` or `company_code`. Frontend uses `symbol`. Map in repository.
4. **Null safety**: Wide tables have NULLs for illiquid stocks. Filter `WHERE nse_code IS NOT NULL AND latest_close IS NOT NULL`.
5. **Performance**: `companies_with_price_features_with_corp_action_flags` is 18 MB, 4,660 rows. Full table scans are acceptable. For `prices_bhavcopy_2` (10.6M rows), always filter by `company_id` and limit by date.
