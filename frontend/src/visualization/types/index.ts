/**
 * Core types for the visualization architecture.
 */

export type PrimitiveType =
  | "metric-card"
  | "summary-strip"
  | "kpi-grid"
  | "status-card"
  | "value-comparison"
  | "data-table"
  | "ranked-table"
  | "hierarchy-table"
  | "tree-table"
  | "matrix-table"
  | "line-chart"
  | "area-chart"
  | "bar-chart"
  | "stacked-bar-chart"
  | "grouped-bar-chart"
  | "heatmap"
  | "treemap"
  | "scatter-plot"
  | "distribution-chart"
  | "gauge"
  | "timeline"
  | "sparkline"
  | "candlestick-chart"
  | "ohlc-chart"
  | "toolbar"
  | "legend"
  | "tooltip"
  | "filter-panel";

export type AdapterLibrary =
  | "echarts"
  | "tradingview"
  | "tanstack"
  | "react"
  | "recharts-legacy";

export interface ChartData {
  series: Array<{
    key: string;
    name?: string;
    data: unknown[];
    color?: string;
  }>;
  categories?: string[];
}

export interface HierarchyData {
  id: string;
  name: string;
  level: string;
  parentId?: string;
  children?: HierarchyData[];
  metrics?: Record<string, number | string | null>;
}

export interface TableData {
  columns: Array<{
    key: string;
    header: string;
    sortable?: boolean;
    width?: number | string;
    align?: "left" | "right" | "center";
  }>;
  rows: Record<string, unknown>[];
  total?: number;
}

export interface WidgetConfiguration {
  id: string;
  type: string;
  title?: string;
  description?: string;
  height?: number;
  width?: number | string;
  responsive?: boolean;
  exportable?: boolean;
  initialState?: Record<string, unknown>;
  filters?: Record<string, unknown>;
}

export interface VisualizationConfiguration {
  primitive: PrimitiveType;
  adapter: AdapterLibrary;
  data: ChartData | HierarchyData | TableData | Record<string, unknown>;
  options?: Record<string, unknown>;
  theme?: Record<string, unknown>;
  accessibility?: {
    ariaLabel?: string;
    ariaDescription?: string;
    role?: string;
  };
}

export interface VisualizationPrimitive {
  readonly type: PrimitiveType;
  readonly config: VisualizationConfiguration;
  render(data?: unknown): React.ReactNode;
  update(config: Partial<VisualizationConfiguration>): void;
  destroy(): void;
}

export interface VisualizationAdapter {
  readonly library: AdapterLibrary;
  readonly supportedPrimitives: readonly PrimitiveType[];
  canHandle(primitive: PrimitiveType): boolean;
  render(
    primitive: VisualizationPrimitive,
    data: unknown,
    config: Record<string, unknown>,
  ): React.ReactNode;
}
