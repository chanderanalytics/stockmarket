# Visualization Architecture

> **Status:** Architecture established. No Power BI pages migrated yet.
> **Goal:** Every future Power BI migration follows this contract.

---

## 1. Why This Architecture Exists

Most frontends couple business widgets directly to chart libraries:
- `MarketPulseChart` imports Recharts
- `VolumeProfileChart` imports Recharts
- `SectorHeatmap` imports Recharts

When you need to swap libraries, add interactions, or support mobile, you must rewrite every widget.

This architecture separates:
1. **Business meaning** — what the chart represents
2. **Visual form** — bars, lines, heatmaps
3. **Technology** — Recharts, ECharts, TradingView, TanStack

No widget should know which library renders it.

---

## 2. Layers

```
Application
    ↓
Analytics Widgets (Business Layer)
    ↓
Visualization Primitives (Presentation Layer)
    ↓
Visualization Adapters (Technology Layer)
    ↓
Visualization Libraries
```

### Layer 1 — Analytics Widgets

Represent business concepts. They:
- Accept canonical domain models as input
- Configure visualization primitives
- Handle business rules, filtering, drill-down
- Do NOT import ECharts, TradingView, TanStack, or Recharts

Examples:
- `MarketPulseWidget`
- `VolumeProfileWidget`
- `SectorHeatmapWidget`
- `TradingSignalsWidget`
- `ProbabilityDistributionWidget`
- `PortfolioSummaryWidget`
- `WatchlistWidget`
- `StockSnapshotWidget`
- `PriceHistoryWidget`
- `SectorLeadershipWidget`
- `RiskMatrixWidget`

### Layer 2 — Visualization Primitives

Generic visualization types. They:
- Are completely domain-agnostic
- Accept `ChartData`, `HierarchyData`, or `TableData`
- Expose a common interface
- Do NOT know about markets, stocks, or portfolios

Examples:
- `MetricCard`
- `SummaryStrip`
- `KPIGrid`
- `RankedTable`
- `HierarchyTable`
- `LineChart`
- `AreaChart`
- `StackedBarChart`
- `GroupedBarChart`
- `Heatmap`
- `Treemap`
- `ScatterPlot`
- `DistributionChart`
- `Gauge`
- `Timeline`
- `Sparkline`
- `CandlestickChart`
- `OHLCChart`
- `Toolbar`
- `Legend`
- `Tooltip`
- `FilterPanel`

### Layer 3 — Visualization Adapters

Connect primitives to visualization libraries. They:
- Implement `VisualizationAdapter` interface
- Declare which primitives they support
- Translate primitive config into library-specific code
- Can be swapped without changing widgets

Supported adapters:
- `EChartsAdapter` — complex charts, heatmaps, high-density visuals
- `TradingViewAdapter` — price/volume financial charts
- `TanStackAdapter` — data tables with sorting/filtering/virtualization
- `ReactComponentsAdapter` — non-chart UI (cards, KPIs, filters)
- `RechartsLegacyAdapter` — backward compatibility only

---

## 3. Folder Structure

```
frontend/src/
├── analytics/
│   └── widgets/
│       ├── index.ts
│       ├── market/
│       │   ├── MarketPulseWidget.tsx
│       │   ├── MarketBreadthWidget.tsx
│       │   └── MarketRegimeWidget.tsx
│       ├── sectors/
│       │   ├── SectorHeatmapWidget.tsx
│       │   ├── SectorLeadershipWidget.tsx
│       │   └── SectorRotationWidget.tsx
│       ├── stocks/
│       │   ├── StockSnapshotWidget.tsx
│       │   ├── PriceHistoryWidget.tsx
│       │   └── ProbabilityDistributionWidget.tsx
│       ├── portfolio/
│       │   ├── PortfolioSummaryWidget.tsx
│       │   └── PortfolioRiskWidget.tsx
│       ├── signals/
│       │   └── TradingSignalsWidget.tsx
│       ├── probability/
│       │   └── ProbabilityAnalysisWidget.tsx
│       └── watchlist/
│           └── WatchlistWidget.tsx
│
├── visualization/
│   ├── index.ts
│   ├── types/
│   │   └── index.ts
│   ├── interfaces/
│   │   └── index.ts
│   ├── primitives/
│   │   ├── index.ts
│   │   ├── cards/
│   │   │   ├── MetricCard.tsx
│   │   │   ├── SummaryStrip.tsx
│   │   │   └── KPIGrid.tsx
│   │   ├── charts/
│   │   │   ├── StackedBarChart.tsx
│   │   │   ├── LineChart.tsx
│   │   │   ├── AreaChart.tsx
│   │   │   ├── Heatmap.tsx
│   │   │   ├── CandlestickChart.tsx
│   │   │   └── ...
│   │   ├── tables/
│   │   │   ├── RankedTable.tsx
│   │   │   └── HierarchyTable.tsx
│   │   ├── filters/
│   │   │   ├── Toolbar.tsx
│   │   │   ├── Legend.tsx
│   │   │   ├── Tooltip.tsx
│   │   │   └── FilterPanel.tsx
│   │   └── layout/
│   │       └── ChartFrame.tsx
│   ├── adapters/
│   │   ├── index.ts
│   │   ├── echarts/
│   │   │   └── index.ts
│   │   ├── tradingview/
│   │   │   └── index.ts
│   │   ├── tanstack/
│   │   │   └── index.ts
│   │   ├── react/
│   │   │   └── index.ts
│   │   └── recharts/
│   │       └── index.ts
│   └── utils/
│       ├── data-transformers.ts
│       └── theme-mappers.ts
│
└── shared/
    └── charts/          ← LEGACY — keep for backward compatibility
        ├── bar-chart.tsx
        ├── line-chart.tsx
        ├── heatmap.tsx
        └── ...
```

---

## 4. Interfaces

### VisualizationPrimitive

```ts
interface VisualizationPrimitive {
  readonly type: PrimitiveType;
  readonly config: VisualizationConfiguration;
  render(data?: unknown): React.ReactNode;
  update(config: Partial<VisualizationConfiguration>): void;
  destroy(): void;
}
```

### VisualizationAdapter

```ts
interface VisualizationAdapter {
  readonly library: AdapterLibrary;
  readonly supportedPrimitives: readonly PrimitiveType[];
  canHandle(primitive: PrimitiveType): boolean;
  render(
    primitive: VisualizationPrimitive,
    data: unknown,
    config: Record<string, unknown>,
  ): React.ReactNode;
}
```

### WidgetDefinition

```ts
interface WidgetDefinition {
  readonly id: string;
  readonly config: WidgetConfiguration;
  readonly visualization: VisualizationConfiguration;
  mount(container: HTMLElement): void;
  unmount(): void;
  update(data: unknown): void;
}
```

---

## 5. Adapter Selection Rules

| Primitive | Preferred Adapter | Fallback | Notes |
|---|---|---|---|
| `stacked-bar-chart` | ECharts | Recharts | ECharts handles dense data better |
| `grouped-bar-chart` | ECharts | Recharts | |
| `heatmap` | ECharts | Recharts | ECharts has native heatmap |
| `treemap` | ECharts | Recharts | |
| `scatter-plot` | ECharts | Recharts | |
| `distribution-chart` | ECharts | — | |
| `timeline` | ECharts | — | |
| `line-chart` | TradingView | ECharts | For price/volume data |
| `area-chart` | TradingView | ECharts | For price/volume data |
| `candlestick-chart` | TradingView | Recharts | Native financial charts |
| `ohlc-chart` | TradingView | Recharts | |
| `sparkline` | TradingView | Recharts | Lightweight |
| `ranked-table` | TanStack | React | Large datasets |
| `hierarchy-table` | TanStack | React | Drill-down tables |
| `metric-card` | React | — | |
| `summary-strip` | React | — | |
| `kpi-grid` | React | — | |
| `toolbar` | React | — | |
| `legend` | React | — | |
| `tooltip` | React | — | |
| `filter-panel` | React | — | |

---

## 6. Migration Strategy

### Phase 1: Architecture (Current)
- ✅ Establish folder structure
- ✅ Define interfaces
- ✅ Create adapter stubs
- ✅ Document contracts
- ❌ No pages migrated
- ❌ No Recharts removed

### Phase 2: Widget-by-Widget Migration
For each Power BI tab:
1. Identify the business widget needed
2. Create widget in `src/analytics/widgets/`
3. Select appropriate adapter based on rules above
4. Implement primitive if needed
5. Wire to existing backend endpoint
6. Replace old page component
7. Keep old component as fallback until verified

### Phase 3: Cleanup
- Remove legacy Recharts components after all widgets migrated
- Remove `RechartsLegacyAdapter`
- Update documentation

---

## 7. Rules

1. **No widget imports visualization libraries directly**
   - ❌ `import { BarChart } from "recharts"` inside `widgets/`
   - ✅ Widgets use primitives or adapters

2. **No primitive knows about business domain**
   - ❌ `StackedBarChart` with hardcoded "Volume" label
   - ✅ `StackedBarChart` accepts `ChartData` with generic series

3. **No adapter knows about business domain**
   - ❌ `EChartsAdapter` with market-specific options
   - ✅ `EChartsAdapter` translates generic config to ECharts option object

4. **Existing code continues to work**
   - Keep `src/shared/charts/` functional
   - Mark as legacy with comments
   - Migrate page-by-page, not all-at-once

5. **One adapter per library**
   - Single ECharts adapter, not one per chart type
   - Adapter selects implementation based on primitive type

---

## 8. Examples

### Bad (Current — Coupled)

```tsx
// ❌ Widget knows about Recharts
export function VolumeProfileWidget({ data }) {
  return (
    <BarChart data={data} layout="horizontal">
      <Bar dataKey="volume" fill="#2563eb" stackId="1" />
      <Bar dataKey="avgVol1W" fill="#f97316" stackId="1" />
    </BarChart>
  );
}
```

### Good (New Architecture)

```tsx
// ✅ Widget knows only about business meaning
export function VolumeProfileWidget({ data }) {
  const visualization: VisualizationConfiguration = {
    primitive: "stacked-bar-chart",
    adapter: "echarts",
    data: transformToChartData(data),
    options: {
      xAxis: { type: "percent" },
      yAxis: { type: "category" },
      series: [
        { key: "volume", name: "Volume", color: "#2563eb" },
        { key: "avgVol1W", name: "AvgVol_1W", color: "#f97316" },
      ],
    },
  };

  return <VisualizationRenderer config={visualization} />;
}
```

---

## 9. Checklist for New Widgets

- [ ] Widget lives in `src/analytics/widgets/{domain}/`
- [ ] Widget does not import ECharts, TradingView, TanStack, or Recharts
- [ ] Widget uses `VisualizationConfiguration` to describe the chart
- [ ] Widget accepts canonical domain models as props
- [ ] Primitive exists or is created in `src/visualization/primitives/`
- [ ] Adapter supports the primitive
- [ ] Backend endpoint exists and returns canonical model
- [ ] Tests verify widget renders with mock data

---

## 10. Success Criteria

- [x] Business widgets are independent of visualization libraries
- [x] Visualization primitives are reusable across the application
- [x] Adapters isolate ECharts, TradingView, TanStack Table, React, and Recharts
- [x] Existing functionality continues to work without regression
- [x] Project is ready for scalable migration of Power BI tabs
