import type { ChartData } from "../../types";

export interface StackedBarChartData extends ChartData {
  meta?: Array<Record<string, unknown>>;
}
