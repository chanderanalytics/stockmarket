/**
 * React Components adapter.
 *
 * Renders non-chart UI primitives (cards, KPIs, status, comparisons,
 * summary strips) using plain React + the application theme tokens.
 * No external visualization library (ECharts / TradingView / Recharts)
 * is referenced here.
 */

import * as React from "react";
import type {
  PrimitiveType,
  AdapterLibrary,
  VisualizationPrimitive,
  ChartData,
  HierarchyData,
  TableData,
} from "../../types";
import type {
  MetricCardData,
  StatusCardData,
  ValueComparisonData,
  SummaryStripData,
  CardStatus,
  CardTrend,
} from "../../primitives/cards/types";

export const REACT_PRIMITIVES: readonly PrimitiveType[] = [
  "metric-card",
  "summary-strip",
  "kpi-grid",
  "status-card",
  "value-comparison",
  "toolbar",
  "legend",
  "tooltip",
  "filter-panel",
];

function statusTextClass(status?: CardStatus): string {
  switch (status) {
    case "ok":
      return "text-success";
    case "warning":
      return "text-warning";
    case "error":
      return "text-destructive";
    case "info":
      return "text-primary";
    default:
      return "text-muted-foreground";
  }
}

function trendTextClass(trend?: CardTrend): string {
  switch (trend) {
    case "up":
      return "text-success";
    case "down":
      return "text-destructive";
    case "flat":
      return "text-muted-foreground";
    default:
      return "text-muted-foreground";
  }
}

function trendArrow(trend?: CardTrend): string {
  switch (trend) {
    case "up":
      return "▲";
    case "down":
      return "▼";
    case "flat":
      return "■";
    default:
      return "";
  }
}

function isMetricCardData(data: unknown): data is MetricCardData {
  return typeof data === "object" && data !== null && "value" in data;
}
function isStatusCardData(data: unknown): data is StatusCardData {
  return typeof data === "object" && data !== null && "status" in data;
}
function isValueComparisonData(data: unknown): data is ValueComparisonData {
  return typeof data === "object" && data !== null && "current" in data;
}
function isSummaryStripData(data: unknown): data is SummaryStripData {
  return typeof data === "object" && data !== null && "items" in data;
}

function MetricCardView({ data }: { data: MetricCardData }) {
  const trend = data.trend ?? "none";
  return (
    <div className="rounded-lg border border-border bg-card p-4 text-card-foreground">
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="truncate text-sm font-medium text-muted-foreground">{data.label}</div>
          <div className="mt-1 text-2xl font-semibold text-foreground">{data.value ?? "—"}</div>
        </div>
        {data.icon ? <div className="shrink-0 text-muted-foreground">{data.icon}</div> : null}
      </div>
      {data.change != null && data.change !== "" ? (
        <div className={`mt-2 text-sm font-medium ${trendTextClass(trend)}`}>
          {trendArrow(trend)} {data.change}
        </div>
      ) : null}
    </div>
  );
}

function StatusCardView({ data }: { data: StatusCardData }) {
  return (
    <div className="flex items-center gap-3 rounded-lg border border-border bg-card p-4 text-card-foreground">
      <span className={`h-2.5 w-2.5 shrink-0 rounded-full bg-current ${statusTextClass(data.status)}`} />
      <div className="min-w-0">
        <div className="truncate text-sm font-medium text-muted-foreground">{data.label}</div>
        <div className={`text-sm font-semibold capitalize ${statusTextClass(data.status)}`}>{data.status}</div>
        {data.detail ? <div className="truncate text-xs text-muted-foreground">{data.detail}</div> : null}
      </div>
    </div>
  );
}

function ValueComparisonView({ data }: { data: ValueComparisonData }) {
  const trend = data.trend ?? "none";
  return (
    <div className="rounded-lg border border-border bg-card p-4 text-card-foreground">
      <div className="text-sm font-medium text-muted-foreground">{data.current}</div>
      <div className="mt-1 flex items-center gap-3 text-xs text-muted-foreground">
        <span>Prev: {data.previous}</span>
        {data.changePercent ? (
          <span className={trendTextClass(trend)}>
            {trendArrow(trend)} {data.changePercent}
          </span>
        ) : null}
        {data.change && !data.changePercent ? <span className={trendTextClass(trend)}>{data.change}</span> : null}
      </div>
    </div>
  );
}

function SummaryStripView({ data }: { data: SummaryStripData }) {
  return (
    <div className="flex flex-wrap items-center gap-x-6 gap-y-2">
      {data.items.map((item, index) => (
        <div key={`${item.label}-${index}`} className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">{item.label}</span>
          <span className={`text-sm font-semibold ${trendTextClass(item.trend)}`}>{item.value ?? "—"}</span>
        </div>
      ))}
    </div>
  );
}

function Placeholder({ primitive, library }: { primitive: PrimitiveType; library: AdapterLibrary }) {
  return (
    <div data-primitive={primitive} data-adapter={library} className="viz-adapter-placeholder">
      {primitive} · {library}
    </div>
  );
}

export class ReactComponentsAdapter {
  readonly library: AdapterLibrary = "react";
  readonly supportedPrimitives: readonly PrimitiveType[] = REACT_PRIMITIVES;

  canHandle(primitive: PrimitiveType): boolean {
    return this.supportedPrimitives.includes(primitive);
  }

  render(
    primitive: VisualizationPrimitive,
    data: ChartData | HierarchyData | TableData | Record<string, unknown>,
    _config: Record<string, unknown>,
  ): React.ReactNode {
    switch (primitive.type) {
      case "metric-card":
        return isMetricCardData(data) ? <MetricCardView data={data} /> : <Placeholder primitive={primitive.type} library={this.library} />;
      case "status-card":
        return isStatusCardData(data) ? <StatusCardView data={data} /> : <Placeholder primitive={primitive.type} library={this.library} />;
      case "value-comparison":
        return isValueComparisonData(data) ? <ValueComparisonView data={data} /> : <Placeholder primitive={primitive.type} library={this.library} />;
      case "summary-strip":
        return isSummaryStripData(data) ? <SummaryStripView data={data} /> : <Placeholder primitive={primitive.type} library={this.library} />;
      default:
        return <Placeholder primitive={primitive.type} library={this.library} />;
    }
  }
}
