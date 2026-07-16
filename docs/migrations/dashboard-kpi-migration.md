# Dashboard KPI Migration

Migrates the legacy top KPI section of `/dashboard` from hand-built `StatCard` markup to the new
**KPI Widget Framework** (Analytics Widget layer), demonstrating the full visualization architecture
on the live frontend for the first time.

---

## Previous architecture

```
DashboardPage
  └─ <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
       ├─ <StatCard title="Market" ... />          (indices.length + sentiment)
       ├─ <StatCard title="Top Gainer" ... />      (movers[0])
       ├─ <StatCard title="Watchlist" ... />       (watchlist.itemCount)
       └─ <StatCard title="Portfolio" ... />       (portfolio.totalValue / pnl)
```

- KPI markup was authored directly in the page using `StatCard` from
  `@/components/data-display/stat-card`.
- Each card mixed multiple data sources (`indices`, `movers`, `watchlist`, `portfolio`) inline.
- No shared config model, no reusable state handling, no adapter layer.

## New architecture

```
DashboardPage
  └─ <KPIStripWidget items={mapPulseToKpis(pulse)} variant="cards" state={...} onRefresh={...} />
        └─ KPIWidget  (per item)
              └─ MetricCardPrimitive
                    └─ ReactComponentsAdapter  → themed card view
```

- The page only knows about `KPIStripWidget` (and its `KPIWidgetConfig` type).
- KPIs are derived from the `MarketPulse` domain model via a pure mapper
  (`mapPulseToKpis`) and rendered through the visualization primitives + adapter.
- Loading / error / empty / refreshing are delegated to the widget's `state` prop, wired to the
  existing React Query `pulseQ` (`isLoading`, `error`, `data`, `isFetching`, `refetch`).

## Data flow

```
GET /api/market/pulse  (PostgreSQL-backed)
   ↓  marketService.pulse()
useApiQuery(queryKeys.market.pulse())   ← existing React Query hook, reused (not duplicated)
   ↓  pulseQ.data : MarketPulse
mapPulseToKpis(pulse)  →  KPIWidgetConfig[]
   ↓
KPIStripWidget → KPIWidget → MetricCardPrimitive → ReactComponentsAdapter
```

## Business mapping (MarketPulse → KPIs)

Only fields exposed by `MarketPulse` are used. No metrics are invented or calculated beyond
counting the existing `risks` array.

| KPI            | Source field                         | Notes                                  |
|----------------|--------------------------------------|----------------------------------------|
| Market Regime  | `marketRegime`                       | `status: "info"`; tooltip = confidence |
| Sentiment      | `overallSentiment`                   | `bullish→ok`, `bearish→warning`, else neutral |
| Risk Level     | `risks.length`                       | severity by count; tooltip = risks list |
| Last Updated   | `timestamp`                          | formatted as local HH:MM               |

KPIs from the menu that are **not** present in `MarketPulse` (Market Status, Breadth, Opportunity
Count) were intentionally omitted, per the "only use fields already exposed" rule.

## Components removed

- Dashboard-specific inline KPI grid (the `grid grid-cols-2 lg:grid-cols-4` block of four `StatCard`s).
- Unused dashboard locals after migration: `pfQ` (`portfolioService.summary()`) and `portfolio`
  (the portfolio value was only shown in the removed KPI card, so the fetch is dead).
- Unused imports removed from the page: `StatCard`, icons `TrendingUp`/`Star`/`Briefcase`/`Activity`,
  `formatINR`, `Sparkline`, `portfolioService`.

## Components reused (not deleted)

- `StatCard` (`@/components/data-display/stat-card`) — a reusable component still used by
  `/stocks/[symbol]`, `/markets`, `/portfolio`, `/watchlist`. **Kept.**
- Existing React Query hooks, `queryKeys`, and `marketService`.
- All other dashboard sections: charts (`AreaChartCard`), Top Movers table (`DataTable`),
  Watchlist (`List`), indices list — left completely unchanged.

## Success criteria met

- ✓ Dashboard uses the new KPI Widget Framework (`KPIStripWidget`).
- ✓ Page imports no primitives/adapters/visualization library for the KPI section.
- ✓ Live PostgreSQL data (`/api/market/pulse`) displayed.
- ✓ Existing appearance preserved (4-up responsive card strip, same spacing/theme).
- ✓ Loading, error, empty, refreshing states wired via `state` + `onRefresh`.
- ✓ Duplicate dashboard KPI code removed.
- ✓ Application builds; TypeScript passes.

## Lessons learned

- A page should depend only on the widget (`KPIStripWidget`), never on primitives/adapters. This
  keeps business pages decoupled from the rendering technology.
- Mapping domain models → `KPIWidgetConfig` in a small pure function is the clean seam between the
  API layer and the widget layer.
- Removing a data source (portfolio) from the top row naturally removes its now-dead fetch; prune
  those to avoid silent, wasted requests.
