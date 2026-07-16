# Market Runtime

The **Market Intelligence Runtime** is the single source of truth for the state
of the Indian stock market. It transforms raw database records into canonical
business objects (`MarketPulse`, `TradingSignal`, `SectorSnapshot`, …) that every
future page, API, AI summary, alert, screener and research tool consumes.

> The frontend never depends on database schemas or Power BI concepts. All market
> intelligence is produced by dedicated engines with clear responsibilities, and
> new indicators or decision rules can be added without changing the frontend.

## Architecture

```
                 ┌─────────────────────────────────────────────┐
   RAW DATA  →   │ data-source.ts  (maps SQL rows → inputs)    │
(DB / backend)   └───────────────┬─────────────────────────────┘
                                  │ plain inputs (no column names)
                                  ▼
   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
   │ IndicatorEngine│  │ BreadthEngine │  │ SectorEngine │  │ProbabilityEngine│
   └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
          └────────────────►│ SignalEngine ◄─────────────────────┘
                             └──────┬───────┘
                                    ▼
                          ┌──────────────────┐
                          │ MarketRegimeEngine│
                          └────────┬──────────┘
                                   ▼
                          ┌──────────────────┐
                          │  DecisionEngine   │  → DecisionSummary
                          └──────────────────┘
                                   ▼
                          MarketRuntime (services) → /api/* (canonical models)
```

## Data flow

1. **Data source** (`services/data-source.ts`) derives engine inputs — candles,
   breadth members, sector members, probability wide-rows — from the backend. In
   this scaffold it uses the mock dataset so the runtime is runnable end-to-end;
   replace these functions with real queries and nothing downstream changes.
2. **Engines** are pure: `input → validate → compute → normalized result`.
   Each returns a typed domain model, never a row.
3. **MarketRuntime** (`services/market-runtime.service.ts`) orchestrates the
   engines into the full set of domain models and is the only thing the API
   layer talks to.
4. **API routes** return canonical models as JSON. No route exposes raw SQL.

## Indicator flow

`IndicatorEngine.compute(name, ctx, params)` runs one calculator; `batch(metas,
ctx)` runs many. Every calculator returns an `IndicatorResult`:

```ts
{ value, signal: "buy"|"sell"|"neutral", trend, strength: 0-100, timestamp }
```

Calculators (`src/domain/indicators/calculators/`): EMA, SMA, RSI, ADX, ATR,
MACD, VWAP, ROC, OBV, Volume, Momentum, RelativeStrength,
MovingAverageEnvelope, BollingerBands, SuperTrend, AverageVolume, 52WeekHighLow.

## Signal flow

`SignalEngine.compute({ indicators, probability?, sector?, breadth?, ... })`:

1. Each indicator contributes a weighted vote (`buy` +, `sell` −).
2. Probability, sector RS and market breadth add their own weighted votes.
3. Votes combine into a 0–100 score → `TradingSignal.rating`
   (`strong_buy → buy → watch → neutral → weak → sell → avoid`).
4. `confidence` from agreement across indicators + probability confidence;
   `risk` from volatility + downside probability; `evidence[]` explains why.

## Decision flow

`DecisionEngine.compute({ regime, breadth, sectors, signals })` answers:

- **Deploy new money?** `exposure ≥ 50% && marketQuality ≥ 50`
- **How much exposure?** table keyed by regime (Capitulation → 25% … Strong Bull → 90%)
- **Cash allocation?** `100 − exposure`
- **Which sectors?** sectors flagged `leadership`, ranked
- **Which watchlist stocks?** each watchlist symbol mapped to its signal rating
- **Overall risk?** derived from market quality
- **Opportunity count?** buy/strong-buy signals
- **Market quality?** blend of participation + regime confidence + % above 200 DMA

## API reference

All endpoints return canonical domain models (JSON).

| Method & Path | Model returned |
|---------------|----------------|
| `GET /api/market/pulse` | `MarketPulse` |
| `GET /api/market/breadth` | `MarketBreadth` |
| `GET /api/market/regime` | `MarketRegime` |
| `GET /api/market/sectors` | `SectorSnapshot[]` |
| `GET /api/signals` | `TradingSignal[]` |
| `GET /api/opportunities` | `TradingOpportunity[]` |
| `GET /api/watchlist` | `WatchlistSummary` |
| `GET /api/portfolio/summary` | `PortfolioSummary` |
| `GET /api/stocks/{symbol}/snapshot` | `{ snapshot, trend, momentum, probability, signal }` |

### Example request

```bash
curl http://localhost:3000/api/market/regime
```

### Example response

```json
{
  "id": "market-regime",
  "timestamp": "2026-07-14T13:18:21.000Z",
  "regime": "Sideways",
  "confidence": "medium",
  "confidenceScore": 46.4,
  "supportingMetrics": [
    { "label": "1M Index Return", "value": "0.04%" },
    { "label": "Net Advances", "value": "-8" },
    { "label": "% Above 200 DMA", "value": "33.3%" },
    { "label": "Participation", "value": "31.8%" },
    { "label": "Volatility", "value": "17.6" },
    { "label": "Momentum", "value": "-18.2" }
  ],
  "historicalComparison": "Range-bound market; stock selection matters more than direction."
}
```

### Example: stock snapshot

```bash
curl http://localhost:3000/api/stocks/RELIANCE/snapshot
```

returns `snapshot` (`StockSnapshot`), `trend` (`StockTrend`), `momentum`
(`StockMomentum`), `probability` (`ProbabilityAnalysis`) and `signal`
(`TradingSignal`) — a complete, UI-ready view of one instrument.

## Extension guide

- **New indicator:** add a calculator in `indicators/calculators/`, register it in
  `calculators/index.ts`, add its name to `IndicatorName`. The `SignalEngine`
  picks it up automatically if you include it in `SIGNAL_INDICATORS`.
- **New signal rule:** edit `SignalEngine.compute` (evidence weights / thresholds)
  — pages and APIs are untouched.
- **New decision rule:** edit `DecisionEngine.compute` or the
  `EXPOSURE_BY_REGIME` table.
- **New endpoint:** add a route under `src/app/api/...` that calls
  `MarketRuntime.<method>()`. No schema changes leak to consumers.

## Files

```
src/domain/
  models/          canonical domain models (market, stocks, sectors, signals,
                   probability, portfolio, watchlist, research, decision, common)
  types/           engine input primitives (OHLC, IndicatorResult, ProbabilityWideRow)
  indicators/      IndicatorEngine + calculators/*
  breadth/         BreadthEngine
  sectors/         SectorEngine
  probability/     ProbabilityEngine
  signals/         SignalEngine
  regime/          MarketRegimeEngine
  decision/        DecisionEngine
  services/        data-source (mapping) + market-runtime (orchestration)
  index.ts         public barrel
src/app/api/...    business endpoints returning canonical models
```
