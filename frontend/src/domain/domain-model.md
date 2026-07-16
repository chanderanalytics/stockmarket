# Domain Model

The Market Intelligence Runtime expresses the Indian stock market as a set of
**business objects** that a trader understands. Nothing in this layer exposes
database column names or Power BI constructs. Downstream consumers (frontend
pages, APIs, AI summaries, alerts, screeners) only ever see these models.

## Guiding rules

- **No raw SQL rows.** Database records are mapped to domain models in the data
  service (`src/domain/services/data-source.ts`), never passed through.
- **No Power BI / column names.** `percent_above_50_dma` becomes
  `breadth.percentageAbove50DMA`. `price_return_1_5` becomes
  `probability.expectedReturn`.
- **Understandable by a trader.** Models are named after concepts:
  `MarketPulse`, `TradingSignal`, `SectorSnapshot`, `PortfolioRisk`.
- **Pure computation.** Engines take plain inputs and return models. No UI, no
  network, no side effects.

## Model catalogue

### Market (`src/domain/models/market.ts`)

| Model | Purpose |
|-------|---------|
| `MarketPulse` | Headline sentiment, regime, drivers, risks, outlook |
| `MarketBreadth` | Advance/decline, % above DMA, new highs/lows, participation, thrust |
| `MarketHealth` | Volatility, liquidity, credit spreads, yield curve |
| `MarketInternals` | Put/call, order flow, institutional vs retail sentiment |
| `MarketRegime` | Classification (Strong Bull … Capitulation) + confidence + metrics |
| `MarketData` | Convenience union of all market models |

### Stocks (`src/domain/models/stocks.ts`)

| Model | Purpose |
|-------|---------|
| `StockSnapshot` | Quote + fundamentals for one instrument |
| `StockTrend` | Price trend, MA structure, support/resistance, volatility |
| `StockMomentum` | Momentum score, relative strength, volume trend |
| `TradingOpportunity` | Entry/target/stop, R:R, probability, catalyst |

### Sectors (`src/domain/models/sectors.ts`)

| Model | Purpose |
|-------|---------|
| `SectorStrength` | Relative strength + leadership flag for a sector |
| `SectorRotation` | Leaders/laggards and rotation signal |
| `SectorSnapshot` | Full per-sector view: performance, RS, participation, rank |

### Signals / Probability (`src/domain/models/signals.ts`, `probability.ts`)

| Model | Purpose |
|-------|---------|
| `TradingSignal` | Rating (strong_buy … avoid), confidence, risk, reason, evidence |
| `ProbabilityAnalysis` | Expected return, upside/downside prob, holding period, score |

### Portfolio (`src/domain/models/portfolio.ts`)

| Model | Purpose |
|-------|---------|
| `PortfolioSummary` | Value, P&L, exposure, diversification, top/worst sectors |
| `PortfolioRisk` | Risk score, VaR, concentration, stress scenarios, hedge advice |

### Watchlist / Research (`src/domain/models/watchlist.ts`, `research.ts`)

| Model | Purpose |
|-------|---------|
| `WatchlistSummary` | Trend, advancers/decliners, strongest/weakest, alerts |
| `ResearchSnapshot` | Thesis, bull/bear case, metrics, consensus, sources |

### Decision (`src/domain/models/decision.ts`)

| Model | Purpose |
|-------|---------|
| `DecisionSummary` | Deploy cash?, exposure, preferred sectors, watchlist actions, risk |

## Shared vocabulary (`src/domain/models/common.ts`)

`SignalStrength` (`weak|moderate|strong`), `TrendDirection`
(`up|down|sideways`), `SignalAction`, `ConfidenceLevel`, `RiskLevel`,
`TimeFrame`. Every model extends `BaseModel { id; timestamp }`.

## Example transformation

```
DB column:  percent_above_50_dma = 0.51
            price_return_1_5     = 14.2
            price_return_5_10    = 11.8
                    │
                    ▼  (data service maps → engine computes)
                    │
Domain model:  breadth.percentageAbove50DMA = 51
               probability.expectedReturn[0].value = 3.8   // weighted midpoint
               probability.upsideProbability   = 59.3
```

## Extension guide

1. Add a new model in `src/domain/models/<area>.ts` and export it from
   `src/domain/models/index.ts`.
2. If it needs computation, add an engine in `src/domain/<area>/<Area>Engine.ts`.
3. Wire it into `MarketRuntime` (`src/domain/services/market-runtime.service.ts`)
   and expose it via an API route under `src/app/api/...`.
4. Frontend pages consume the model — they never change when indicators or
   scoring logic change.
