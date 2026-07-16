/**
 * Visualization primitives barrel export.
 *
 * These are domain-agnostic building blocks.
 * Existing Recharts components remain in src/shared/charts/
 * and are treated as legacy implementations of these primitives.
 */

export type { ChartData, HierarchyData, TableData, PrimitiveType, AdapterLibrary } from "../types";
export type { StackedBarChartData } from "./charts/types";
export type {
  MetricCardData,
  StatusCardData,
  ValueComparisonData,
  SummaryStripData,
  SummaryStripItem,
  CardTrend,
  CardStatus,
  CardSeverity,
} from "./cards/types";

export type { PrimitiveProps } from "./common";
export { buildPrimitiveRef } from "./common";

export { MetricCardPrimitive } from "./cards/MetricCardPrimitive";
export { KPIGridPrimitive } from "./cards/KPIGridPrimitive";
export { SummaryStripPrimitive } from "./cards/SummaryStripPrimitive";
export { StatusCardPrimitive } from "./cards/StatusCardPrimitive";
export { ValueComparisonPrimitive } from "./cards/ValueComparisonPrimitive";

export { DataTablePrimitive } from "./tables/DataTablePrimitive";
export { HierarchyTablePrimitive } from "./tables/HierarchyTablePrimitive";
export { TreeTablePrimitive } from "./tables/TreeTablePrimitive";
export { MatrixTablePrimitive } from "./tables/MatrixTablePrimitive";
export { RankingTablePrimitive } from "./tables/RankingTablePrimitive";

export { LineChartPrimitive } from "./charts/LineChartPrimitive";
export { AreaChartPrimitive } from "./charts/AreaChartPrimitive";
export { BarChartPrimitive } from "./charts/BarChartPrimitive";
export { StackedBarPrimitive } from "./charts/StackedBarPrimitive";
export { GroupedBarPrimitive } from "./charts/GroupedBarPrimitive";
export { HeatmapPrimitive } from "./charts/HeatmapPrimitive";
export { TreemapPrimitive } from "./charts/TreemapPrimitive";
export { ScatterPrimitive } from "./charts/ScatterPrimitive";
export { DistributionPrimitive } from "./charts/DistributionPrimitive";
export { GaugePrimitive } from "./charts/GaugePrimitive";
export { TimelinePrimitive } from "./charts/TimelinePrimitive";
export { SparklinePrimitive } from "./charts/SparklinePrimitive";
export { CandlestickPrimitive } from "./charts/CandlestickPrimitive";
export { OHLCPrimitive } from "./charts/OHLCPrimitive";

export { VisualizationContainer } from "./layout/VisualizationContainer";
export { VisualizationToolbar } from "./layout/VisualizationToolbar";
export { VisualizationLegend } from "./layout/VisualizationLegend";
export { VisualizationTooltip } from "./layout/VisualizationTooltip";
export { VisualizationLoading } from "./layout/VisualizationLoading";
export { VisualizationEmpty } from "./layout/VisualizationEmpty";
export { VisualizationError } from "./layout/VisualizationError";
