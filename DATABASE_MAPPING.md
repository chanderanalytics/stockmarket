# Database → Domain Model Mapping

This document is the contract between PostgreSQL and the application. Every canonical domain model must be sourced from the tables below. The frontend and runtime never see raw SQL column names.

---

## MarketPulse

**Derived from**: runtime computation (no single table)

| Field | Source | Notes |
|---|---|---|
| `id` | computed `"market-pulse"` | |
| `overallSentiment` | computed | Bullish if regime ∈ {Strong Bull, Bull, Recovering} |
| `marketRegime` | `MarketRegime.regime` | |
| `regimeConfidence` | `MarketRegime.confidence` | |
| `keyDrivers` | computed | Built from `MarketBreadth` |
| `risks` | computed | Built from `MarketRegime` + `MarketBreadth` |
| `outlook` | `MarketRegime.historicalComparison` | |

---

## MarketBreadth

**Derived from**: `prices_bhavcopy_2` + `companies`

| Field | Source | SQL / Notes |
|---|---|---|
| `id` | computed `"market-breadth"` | |
| `marketParticipationScore` | computed | % of stocks above 50 DMA from price table |
| `percentageAbove50DMA` | computed | COUNT(close > ma50) / total * 100 |
| `percentageAbove200DMA` | computed | COUNT(close > ma200) / total * 100 |
| `netAdvances` | computed | advancers - declancers from daily price change |
| `breadthTrend` | computed | `up` / `down` / `stable` from rolling comparison |
| `breadthMomentum` | computed | `strong` / `weak` / `neutral` |
| `newHighs` | computed | COUNT of 52-week highs |
| `newLows` | computed | COUNT of 52-week lows |
| `advanceDeclineRatio` | computed | advancers / decliners |

---

## MarketRegime

**Derived from**: runtime computation (no single table)

| Field | Source | Notes |
|---|---|---|
| `id` | computed | |
| `regime` | computed | 9 regimes: Strong Bull, Bull, Recovering, Sideways, High Risk, Correction, Bear, Capitulation, Weak |
| `confidence` | computed | 0-100 |
| `historicalComparison` | computed | Narrative comparing current breadth to history |
| `supportingMetrics` | computed | Breadth, momentum, volatility, sector rotation |

---

## SectorSnapshot / SectorStrength / SectorRotation

**Derived from**: `companies` + `prices_bhavcopy_2`

| Field | Source | Notes |
|---|---|---|
| `sector` | `companies.industry` | Maps to `industry` column |
| `rank` | computed | 1 = strongest |
| `leadership` | computed | boolean |
| `weakening` | computed | boolean |
| `relativeStrength` | computed | vs market average |
| `participation` | computed | % of constituents advancing |
| `momentum` | computed | Sector-level momentum score |
| `performance1D` | computed | Avg daily return |
| `performance1W` | computed | Avg weekly return |
| `performance1M` | computed | Avg monthly return |
| `performanceYTD` | computed | Avg YTD return |
| `topStocks` | computed | Top 5 performers by symbol |
| `marketCap` | computed | Total sector market cap |

---

## StockSnapshot

**Derived from**: `companies` + `prices_bhavcopy_2` (latest)

| Field | Source | SQL / Notes |
|---|---|---|
| `id` | computed `"stock-{symbol}"` | |
| `symbol` | `companies.nse_code` | Primary lookup key |
| `name` | `companies.name` | |
| `exchange` | `companies.exchange` | |
| `sector` | `companies.industry` | |
| `industry` | `companies.industry` | |
| `currentPrice` | `prices_bhavcopy_2.close` | Latest close by symbol |
| `priceChange` | computed | latest close - prev close |
| `priceChangePercent` | computed | priceChange / prev close * 100 |
| `marketCap` | `companies.market_capitalization` | |
| `volume` | `prices_bhavcopy_2.total_traded_quantity` | Latest |
| `avgVolume` | computed | 20-day average volume |
| `dayHigh` | `prices_bhavcopy_2.high` | Latest |
| `dayLow` | `prices_bhavcopy_2.low` | Latest |
| `week52High` | computed | MAX(high) over last 252 sessions |
| `week52Low` | computed | MIN(low) over last 252 sessions |
| `peRatio` | `companies.price_to_earning` | |
| `pbRatio` | `companies.price_to_book_value` | |
| `dividendYield` | `companies.dividend_yield` | |

---

## StockTrend

**Derived from**: `prices_bhavcopy_2` (rolling windows)

| Field | Source | Notes |
|---|---|---|
| `id` | computed `"trend-{symbol}"` | |
| `symbol` | input | |
| `priceTrend` | computed | `up` / `down` / `sideways` from MA cross |
| `trendStrength` | computed | `strong` / `moderate` / `weak` |
| `movingAverages.ma20` | computed | 20-day SMA |
| `movingAverages.ma50` | computed | 50-day SMA |
| `movingAverages.ma100` | computed | 100-day SMA |
| `movingAverages.ma200` | computed | 200-day SMA |
| `movingAverages.priceVsMA20` | computed | (price - ma20) / ma20 * 100 |
| `movingAverages.priceVsMA50` | computed | (price - ma50) / ma50 * 100 |
| `movingAverages.priceVsMA100` | computed | (price - ma100) / ma100 * 100 |
| `movingAverages.priceVsMA200` | computed | (price - ma200) / ma200 * 100 |
| `momentum` | computed | RSI value |
| `volatility` | computed | Annualized from returns |
| `supportLevel` | computed | Recent swing low / Fib level |
| `resistanceLevel` | computed | Recent swing high / Fib level |

---

## StockMomentum

**Derived from**: `prices_bhavcopy_2` + `companies_with_price_features`

| Field | Source | Notes |
|---|---|---|
| `id` | computed `"momentum-{symbol}"` | |
| `symbol` | input | |
| `momentumScore` | computed | 0-100 composite |
| `relativeStrength` | computed | vs sector/market |
| `earningsMomentum` | computed | EPS growth trend from `companies` |
| `priceMomentum` | computed | e.g. 12-1 month return |
| `volumeTrend` | computed | `increasing` / `decreasing` / `stable` |
| `institutionalInterest` | computed | `accumulation` / `distribution` / `neutral` |

---

## ProbabilityAnalysis

**Derived from**: `merged_price_baseline_probabilities_wide`

| Field | Source | SQL / Notes |
|---|---|---|
| `id` | computed `"probability-{symbol}"` | |
| `symbol` | `merged_price_baseline_probabilities_wide.nse_code` | |
| `upsideProbability` | computed | Sum of positive return bucket probabilities |
| `downsideProbability` | computed | 100 - upside, adjusted by volatility |
| `expectedReturn[]` | computed | Base / bull / bear scenarios |
| `confidenceScore` | computed | Weighted function of upside + vol |
| `volatilityExpectation` | `merged_price_baseline_probabilities_wide.volatility21d` | Annualized % |
| `rewardRiskRatio` | computed | expectedBase / downsideMagnitude |
| `recommendation` | computed | strong_buy / buy / watch / neutral / weak / sell / avoid |
| `normalizedScore` | computed | 0-100 composite |

**Important**: Never expose the 397 raw columns from `merged_price_baseline_probabilities_wide`. Map them into `ProbabilityWideRow` first, then compute `ProbabilityAnalysis`.

---

## TradingSignal

**Derived from**: runtime computation (no single table)

| Field | Source | Notes |
|---|---|---|
| `id` | computed | |
| `symbol` | input | |
| `rating` | `SignalEngine.compute()` | strong_buy / buy / watch / neutral / weak / sell / avoid |
| `confidence` | computed | low / medium / high |
| `confidenceScore` | computed | 0-100 |
| `risk` | computed | low / medium / high |
| `riskScore` | computed | 0-100 |
| `reason` | computed | Human-readable rationale |
| `evidence` | computed | `SignalEvidence[]` from indicators + probability + sector + breadth |
| `targetPrice` | computed | From probability / technical levels |
| `stopLoss` | computed | From support / ATR |
| `horizonDays` | computed | From probability expected holding period |

---

## TradingOpportunity

**Derived from**: runtime computation from `TradingSignal`

| Field | Source | Notes |
|---|---|---|
| `id` | computed `"opp-{symbol}"` | |
| `symbol` | from signal | |
| `opportunityType` | computed | breakout / breakdown / pullback / bounce |
| `entryPrice` | computed | Current price or pullback level |
| `targetPrice` | computed | Based on resistance / R:R |
| `stopLoss` | computed | Based on support / ATR |
| `riskRewardRatio` | computed | (target - entry) / (entry - stop) |
| `probabilityOfSuccess` | `TradingSignal.confidenceScore` | |
| `horizon` | computed | short / medium / long |
| `catalyst` | `TradingSignal.reason` | |

---

## DecisionSummary

**Derived from**: runtime computation (no single table)

| Field | Source | Notes |
|---|---|---|
| `id` | computed | |
| `deployNewMoney` | computed | Based on regime + breadth |
| `recommendedExposure` | computed | % of capital to deploy |
| `cashAllocation` | computed | 100 - recommendedExposure |
| `preferredSectors` | computed | Top sectors from `SectorSnapshot[]` |
| `watchlistActions` | computed | Per-symbol actions |
| `overallRisk` | computed | low / medium / high |
| `opportunityCount` | computed | Count of buy/strong_buy signals |
| `marketQuality` | computed | 0-100 composite |
| `summary` | computed | Human-readable decision |
| `thesis` | computed | Array of reasoning bullets |

---

## WatchlistSummary

**Derived from**: `companies` + `prices_bhavcopy_2`

| Field | Source | Notes |
|---|---|---|
| `id` | computed | |
| `watchlistId` | frontend state / future table | |
| `name` | frontend state | |
| `itemCount` | count of watchlist symbols | |
| `overallTrend` | computed | up / down / sideways |
| `advancers` | computed | Count of symbols with positive change |
| `decliners` | computed | Count of symbols with negative change |
| `strongest` | computed | Top advancer symbol |
| `weakest` | computed | Top decliner symbol |
| `avgChangePercent` | computed | Average of all changes |
| `alerts` | computed | `WatchlistAlert[]` |

---

## PortfolioSummary

**Derived from**: frontend state / future `portfolios` table

| Field | Source | Notes |
|---|---|---|
| `id` | computed | |
| `portfolioId` | frontend state / future table | |
| `name` | frontend state | |
| `totalValue` | computed | Sum of (price * quantity) + cash |
| `dayChange` | computed | Session P&L |
| `dayChangePercent` | computed | dayChange / previous total |
| `totalPnl` | computed | Unrealized P&L |
| `totalPnlPercent` | computed | totalPnl / cost basis |
| `cash` | computed | Unallocated capital |
| `invested` | computed | Sum of position values |
| `exposure` | computed | invested / totalValue * 100 |
| `holdingsCount` | computed | Count of positions |
| `beta` | computed | Portfolio beta vs NIFTY |
| `sharpeRatio` | computed | Risk-adjusted return |
| `maxDrawdown` | computed | Max peak-to-trough |
| `diversificationScore` | computed | 0-100 |
| `topSectors` | computed | Top 3 sectors by weight |
| `worstSectors` | computed | Bottom 2 sectors by weight |

---

## ResearchSnapshot

**Derived from**: `companies` + `analyst_recommendations` + `composite_quality_scores`

| Field | Source | Notes |
|---|---|---|
| `id` | computed | |
| `symbol` | `companies.nse_code` | |
| `name` | `companies.name` | |
| `thesis` | computed | Summary narrative |
| `bullCase` | computed | Fundamental strengths |
| `bearCase` | computed | Fundamental risks |
| `keyMetrics` | `companies` | PE, PB, ROE, etc. |
| `analystConsensus` | `analyst_recommendations` | Aggregated rating |
| `targetPrice` | `analyst_recommendations.price_target` | Latest |
| `upsidePercent` | computed | (target - current) / current * 100 |
| `confidence` | computed | low / medium / high |
| `lastUpdated` | `companies.last_modified` | |
| `sources` | computed | Analyst firm references |

---

## Knowledge Models

All knowledge models are **derived** from the runtime. They do not map to a single table.

| Model | Inputs |
|---|---|
| `Knowledge` | `MarketPulse`, `MarketBreadth`, `MarketRegime`, `SectorSnapshot[]`, `TradingSignal[]`, `DecisionSummary`, `TradingOpportunity[]` |
| `Evidence` | `MarketBreadth`, `SectorSnapshot[]`, `TradingSignal.evidence[]` |
| `Narrative` | `Knowledge[]` + domain objects |
| `InvestmentThesis` | `StockSnapshot`, `StockTrend`, `StockMomentum`, `TradingSignal`, `SectorSnapshot`, `MarketRegime`, `ProbabilityAnalysis` |
| `Insight` | `Knowledge[]` + `TradingSignal[]` |
| `Alert` | `Knowledge[]` + `TradingSignal[]` |
| `Explanation` | `TradingSignal` / `Knowledge` / `DecisionSummary` |
| `KnowledgeGraph` | All domain objects |

---

## Critical Rules

1. **Never expose raw wide-table columns** (`merged_price_baseline_probabilities_wide`, `corp_action_flags`, etc.) to the frontend.
2. **Never let the frontend reference SQL table names**. All access goes through canonical domain models.
3. **Mapping happens in repositories**, not in pages or components.
4. **Symbol normalization**: DB `nse_code` → domain `symbol`. Fallback to `bse_code` if `nse_code` is null.
5. **Null safety**: All numeric fields must be coerced to `0` or `null` before entering domain models.
