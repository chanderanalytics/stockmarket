# KPI Widget Framework

The first **Analytics Widget** built on the Visualization Architecture. It replaces the KPI cards used
throughout the legacy Power BI dashboards with one reusable, configurable, theme-aware component family.

```
Analytics Widget (KPI)
      ↓  composes
Visualization Primitive (MetricCard / StatusCard / ValueComparison / SummaryStrip)
      ↓  delegates to
Visualization Adapter (ReactComponentsAdapter)
      ↓  renders with
React + theme tokens (no external visualization library)
```

The widget never imports a charting library (ECharts / TradingView / Recharts). It only composes
visualization **primitives** and supplies an **adapter**. This keeps the widget domain-agnostic and
reusable for *any* business metric.

---

## Location

```
src/analytics/widgets/common/KPIWidget/
    KPIWidget.tsx            # single KPI (metric | status display)
    KPIGridWidget.tsx        # responsive grid of KPIs
    KPIStripWidget.tsx       # horizontal strip (cards | summary)
    KPIComparisonWidget.tsx  # comparison KPI (current vs previous)
    KPIWidget.types.ts       # config + state + format models
    KPIWidget.utils.ts       # formatters + config -> payload mappers
    KPIWidget.mocks.ts       # dev-only example KPI configs
    index.ts                 # barrel
```

Re-exported from `src/analytics/widgets` (the analytics barrel).

---

## Configuration

```ts
interface KPIWidgetConfig {
  id: string;
  title: string;
  subtitle?: string;
  icon?: React.ReactNode;
  value: number | string | null;
  formattedValue?: string;          // pre-formatted override
  previousValue?: number | null;    // for comparison
  change?: number | null;           // absolute change
  changePercent?: number | null;    // percentage change
  trend?: "up" | "down" | "flat" | "none";
  status?: "ok" | "warning" | "error" | "info" | "neutral";
  severity?: "low" | "medium" | "high" | "critical" | "none";
  tooltip?: string;
  colorScheme?: "auto" | "primary" | "success" | "warning" | "destructive" | "muted";
  clickAction?: () => void;
  format?: "currency" | "percent" | "integer" | "decimal" | "ratio" | "largeNumber" | "indianNumber" | "custom";
  formatOptions?: { currency?: string; locale?: string; decimals?: number; prefix?: string; suffix?: string; custom?: (v) => string };
  ariaLabel?: string;
}
```

### States (passed via `state` prop)

| State        | Effect                                                        |
|--------------|---------------------------------------------------------------|
| `loading`    | Primitive renders its skeleton (delegated to primitive).      |
| `error`      | Primitive renders its error panel.                            |
| `empty`      | Widget renders the `VisualizationEmpty` primitive.            |
| `refreshing` | Subtle pulse + busy spinner on the refresh control.           |
| `disabled`   | `pointer-events-none`, reduced opacity, `aria-disabled`.      |

### Interactions (passed as props)

| Prop            | Purpose                                  |
|-----------------|------------------------------------------|
| `clickAction`   | Primary click handler (on the config).   |
| `onNavigate`    | Navigation callback (widget-level).       |
| `onRefresh`     | Renders a refresh button + refresh handler. |
| `onContextMenu` | Context-menu hook.                        |
| `adapter`       | Optional adapter override (defaults to ReactComponentsAdapter). |

---

## Layouts

| Component            | Layout                          | Composes                              |
|----------------------|---------------------------------|---------------------------------------|
| `KPIWidget`          | Single KPI (`display="metric"`) | `MetricCardPrimitive`                 |
| `KPIWidget`          | Single KPI (`display="status"`) | `StatusCardPrimitive`                 |
| `KPIComparisonWidget`| Comparison KPI                  | `ValueComparisonPrimitive`            |
| `KPIGridWidget`      | Responsive KPI Grid             | `KPIWidget` × N (responsive columns)  |
| `KPIStripWidget`     | Horizontal strip (`cards`)      | `KPIWidget` × N in a flex row         |
| `KPIStripWidget`     | Dashboard Summary Strip (`summary`) | `SummaryStripPrimitive`           |

---

## Formatting (single source of truth)

All formatting lives in `KPIWidget.utils.ts` — **never duplicated** in a page or widget.

| Format         | Example (locale `en-IN`)            |
|----------------|-------------------------------------|
| `currency`     | `₹1,28,45,000`                      |
| `percent`      | `2.84%`                             |
| `integer`      | `1,284`                             |
| `decimal`      | `1.42`                              |
| `ratio`        | `1.5x`                              |
| `largeNumber`  | `12.8M` (compact notation)          |
| `indianNumber` | `1,28,45,000` (Indian grouping)     |
| `custom`       | user-provided `(value) => string`   |

---

## Examples

```tsx
import { KPIWidget, KPIGridWidget, KPIStripWidget, KPIComparisonWidget } from "@/analytics/widgets";

// Single KPI (auto-formats value + change)
<KPIWidget config={portfolioValueKPI} onNavigate={() => router.push("/portfolio")} onRefresh={refetch} />

// Status display
<KPIWidget config={riskScoreKPI} display="status" />

// Responsive grid for a dashboard row
<KPIGridWidget items={mockKPIs} columns={{ base: 1, sm: 2, md: 3, lg: 4 }} />

// Dashboard summary strip (compact)
<KPIStripWidget items={mockKPIs} variant="summary" />

// Comparison KPI
<KPIComparisonWidget config={portfolioValueKPI} />
```

### Migrating the Market Overview row

```tsx
<KPIStripWidget
  variant="cards"
  items={[marketStatus, breadth, opportunities, risk, watchlist, portfolio]}
/>
```

The same widget family is reused on Dashboard, Portfolio, Watchlist, Signals, Probability, Research,
and Stock Detail pages — no new visualization logic required.

---

## Composition

`KPIWidget` does **not** implement a metric card. It translates `KPIWidgetConfig` into the primitive's
data payload and renders the matching primitive:

```
KPIWidgetConfig
   ↓ KPIWidget.utils.toMetricCardData / toStatusCardData / toValueComparisonData
primitive data payload (MetricCardData | StatusCardData | ValueComparisonData | SummaryStripData)
   ↓ MetricCardPrimitive / StatusCardPrimitive / ValueComparisonPrimitive / SummaryStripPrimitive
   ↓ adapter.render(...)
ReactComponentsAdapter → themed card view
```

The card payload contract (`src/visualization/primitives/cards/types.ts`) is owned by the
**visualization** layer so the adapter and the widget share one definition without a layering
violation (visualization must not import from analytics).

---

## Extension Guide

1. **New metric type** — just add a `KPIWidgetConfig`. No component changes needed.
2. **New rendering backend** — implement an adapter (e.g. swap `ReactComponentsAdapter` for a
   design-system card) and pass it via the `adapter` prop. The widget code is unchanged.
3. **New layout** — compose existing widgets/primitives. Do not re-implement card markup.
4. **New formatting** — add a branch in `formatValue` in `KPIWidget.utils.ts`.

---

## Best Practices

- Compose primitives; never import a visualization library in a widget or page.
- Keep all formatting in `KPIWidget.utils.ts`.
- Prefer `formattedValue` only for truly custom display; otherwise let the formatter do the work.
- Use `status`/`severity`/`trend` for color, never hardcode colors — the adapter maps them to theme
  tokens (`text-success`, `text-destructive`, `text-warning`, `text-primary`, `text-muted-foreground`)
  which adapt automatically to light/dark/high-contrast.
- Provide `ariaLabel` for screen-reader friendly, keyboard-navigable cards (`Enter`/`Space` activate).
- Pages consume the widget; they must not import primitives directly.

---

## Success criteria (this task)

- No page imports primitives directly (pages use `KPIWidget` etc.).
- KPI Widget composes primitives only.
- No visualization library imported by the widget.
- Completely reusable across every KPI in the app.
- Existing application unchanged (only `src/analytics/widgets` + showcase added).
- Ready to replace every KPI card in Power BI.
