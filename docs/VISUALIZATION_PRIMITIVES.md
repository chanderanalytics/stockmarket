# Visualization Primitives

Domain-agnostic building blocks that sit between **Analytics Widgets** and **Visualization Adapters**.
These primitives know nothing about the stock market, trading, sectors, probabilities, portfolios, or any
business domain. They declare *what* to render and delegate *how* to the active adapter.

```
Analytics Widget
      ↓
Visualization Primitive   (generic, domain-free)
      ↓
Visualization Adapter     (echarts | tradingview | tanstack | react | recharts-legacy)
      ↓
Visualization Library     (Apache ECharts | TradingView | TanStack Table | React | Recharts)
```

---

## Common interface

Every chart, card, and table primitive exposes the **same** props contract:

```ts
interface PrimitiveProps<T = unknown> {
  data: T;                                  // domain-free payload
  config: VisualizationConfiguration;       // primitive type, adapter, options, theme
  loading: boolean;                         // loading state delegation
  error: string | null;                     // error state delegation
  adapter: VisualizationAdapter;            // the active adapter instance
}
```

The primitive itself never imports a charting library. It forwards `config`, `data`, and the resolved
`adapter` down the chain. Loading and error states short-circuit rendering before the adapter is invoked.

A small shared helper `buildPrimitiveRef(config)` produces the `VisualizationPrimitive` reference handed
to `adapter.render(...)`.

---

## Configuration contract

Every primitive reads its behavior from `VisualizationConfiguration`:

| Field       | Type                                   | Purpose                                           |
|-------------|----------------------------------------|---------------------------------------------------|
| `primitive` | `PrimitiveType`                        | Which primitive is being rendered                 |
| `adapter`   | `AdapterLibrary`                       | Which adapter resolves the render                 |
| `data`      | `ChartData \| HierarchyData \| TableData \| Record<string, unknown>` | Payload |
| `options`   | `Record<string, unknown>`              | title, subtitle, height, width, theme, toolbar, legend, tooltip, fullscreen, export, responsive, loading, error, empty |
| `theme`     | `Record<string, unknown>`              | Theme overrides passed to the adapter             |
| `accessibility` | `{ ariaLabel?, ariaDescription?, role? }` | A11y metadata                                  |

Common `options` keys supported by the contract: `title`, `subtitle`, `height`, `width`, `theme`,
`toolbar`, `legend`, `tooltip`, `fullscreen`, `export`, `loading`, `error`, `empty`, `responsive`.

---

## Cards

| Primitive              | Adapter        | Purpose                                                        |
|------------------------|----------------|----------------------------------------------------------------|
| `MetricCardPrimitive`  | `react`        | Single headline metric with label/value/delta.                 |
| `KPIGridPrimitive`     | `react`        | Grid of KPI tiles.                                             |
| `SummaryStripPrimitive`| `react`        | Compact horizontal strip of summarized values.                 |
| `StatusCardPrimitive`  | `react`        | Status/health indicator card (ok / warning / error).           |
| `ValueComparisonPrimitive` | `react`   | Compares a current value against a previous/baseline value.    |

## Tables

| Primitive               | Adapter      | Purpose                                                      |
|-------------------------|--------------|--------------------------------------------------------------|
| `DataTablePrimitive`    | `tanstack`   | Flat, sortable, paginated tabular data.                      |
| `HierarchyTablePrimitive` | `tanstack` | Parent/child rows with level metadata.                       |
| `TreeTablePrimitive`    | `tanstack`   | Expandable tree of rows.                                     |
| `MatrixTablePrimitive`  | `tanstack`   | Row × column matrix of intersecting values.                  |
| `RankingTablePrimitive` | `tanstack`   | Ordered ranking table with rank positions.                   |

## Charts

| Primitive              | Adapter                                       | Purpose                                   |
|------------------------|-----------------------------------------------|-------------------------------------------|
| `LineChartPrimitive`   | `recharts-legacy` / `tradingview`             | Time-series lines.                        |
| `AreaChartPrimitive`   | `recharts-legacy` / `tradingview`             | Filled line areas.                        |
| `BarChartPrimitive`    | `recharts-legacy`                             | Single-series bars.                       |
| `StackedBarPrimitive`  | `echarts`                                     | Stacked bar series.                       |
| `GroupedBarPrimitive`  | `echarts`                                     | Grouped/clustered bars.                   |
| `HeatmapPrimitive`     | `echarts`                                     | Color-mapped matrix.                      |
| `TreemapPrimitive`     | `echarts`                                     | Hierarchical area sizing.                 |
| `ScatterPrimitive`     | `echarts`                                     | X/Y point distribution.                   |
| `DistributionPrimitive`| `echarts`                                     | Histogram / distribution.                 |
| `GaugePrimitive`       | `echarts`                                     | Radial gauge meter.                       |
| `TimelinePrimitive`    | `echarts`                                     | Event timeline.                           |
| `SparklinePrimitive`   | `recharts-legacy` / `tradingview`             | Mini trend line.                          |
| `CandlestickPrimitive` | `tradingview`                                 | OHLC candlesticks.                        |
| `OHLCPrimitive`        | `tradingview`                                 | OHLC bars.                                |

## Layout primitives

These are generic UI building blocks, not tied to a data payload.

| Primitive                 | Purpose                                              |
|---------------------------|------------------------------------------------------|
| `VisualizationContainer`  | Wrapper with title/config/width/height/fullscreen.   |
| `VisualizationToolbar`    | Toolbar of action buttons.                           |
| `VisualizationLegend`     | Color/label legend.                                  |
| `VisualizationTooltip`    | Floating tooltip surface.                            |
| `VisualizationLoading`    | Loading indicator.                                   |
| `VisualizationEmpty`      | Empty-state message.                                 |
| `VisualizationError`      | Error panel with retry.                              |

---

## Supported adapters

| Adapter            | Library                | Typical primitives                                  |
|--------------------|------------------------|-----------------------------------------------------|
| `react`            | React DOM              | cards, toolbar, legend, tooltip                     |
| `tanstack`         | TanStack Table         | all table primitives                                |
| `recharts-legacy`  | Recharts               | line, area, bar, sparkline                          |
| `echarts`          | Apache ECharts         | stacked/grouped bars, heatmap, treemap, scatter, distribution, gauge, timeline |
| `tradingview`      | TradingView Lightweight Charts | line, area, candlestick, ohlc, sparkline     |

The primitive does **not** know which adapter it receives. Swapping `adapter="echarts"` for
`adapter="recharts-legacy"` changes the render path without modifying the primitive.

---

## Adapter flow

```
<MetricCardPrimitive adapter={reactAdapter} ... />
        │
        ├─ loading?  → render loading UI (short-circuit)
        ├─ error?    → render error UI   (short-circuit)
        │
        └─ else → buildPrimitiveRef(config)
                  → reactAdapter.render(primitiveRef, data, options)
                        → VisualizationAdapter.render(...) returns ReactNode
```

Each adapter exposes:
- `library: AdapterLibrary`
- `supportedPrimitives: readonly PrimitiveType[]`
- `canHandle(primitive)` — capability check
- `render(primitive, data, options)` — produces the `ReactNode`

The current adapter stubs return a neutral placeholder node (`data-primitive`, `data-adapter`)
so the architecture can be verified end-to-end before a library is wired in. Analytics Widgets
replace the stub `render` with real library calls.

---

## Rendering lifecycle

1. **Resolve props** — Analytics Widget supplies `data`, `config`, `loading`, `error`, `adapter`.
2. **Guard states** — If `loading` is true the primitive renders its loading UI and stops.
   If `error` is non-null the primitive renders its error UI and stops.
3. **Build reference** — `buildPrimitiveRef(config)` creates the `VisualizationPrimitive`
   contract object (`type`, `config`, `render`, `update`, `destroy`).
4. **Delegate** — `adapter.render(primitiveRef, data, config.options ?? {})` is invoked.
5. **Adapter resolves library** — The adapter maps the primitive type to the concrete
   visualization library component and returns the `ReactNode` to mount.
6. **Update / Destroy** — Widgets may call `update()` to push new config or `destroy()` on
   unmount; the adapter owns the lifecycle of the underlying library instance.

---

## Example usage

```tsx
import { MetricCardPrimitive } from "@/visualization/primitives";
import { ReactComponentsAdapter } from "@/visualization/adapters";

const adapter = new ReactComponentsAdapter();

<MetricCardPrimitive
  data={{ label: "Active Users", value: 1284, delta: "+3.2%" }}
  config={{
    primitive: "metric-card",
    adapter: "react",
    data: {},
    options: { title: "Metric Card", height: 140 },
  }}
  loading={false}
  error={null}
  adapter={adapter}
/>;
```

---

## Showcase

Run the internal showcase page (no backend) to validate rendering and adapter integration:

- Route: `/showcase`
- Renders one example of every primitive using static mock data.
- Cycles adapters per primitive family (react, tanstack, recharts-legacy, echarts, tradingview).
- Demonstrates loading and error short-circuits.

---

## Rules enforced

- No business logic, market calculations, signal/portfolio/probability logic.
- No SQL, no API, no Power BI widget migration.
- Recharts remains untouched (used only via the `recharts-legacy` adapter).
- Every primitive shares the identical `PrimitiveProps<T>` contract.
