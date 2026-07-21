import * as React from "react";
import type { PriceTrendPeriod } from "./PriceTrend.types";
import { buildRows, type PriceTrendGridRow } from "./buildRows";
import { calculatePeriodScales, type PeriodScale } from "./calculatePeriodScales";

export interface UsePriceTrendTableResult {
  rows: PriceTrendGridRow[];
  scales: Map<PriceTrendPeriod, PeriodScale>;
}

/**
 * Memoized transformation of backend rows into the grid row model plus the
 * independent per-period scales. Recomputes only when rows or selected periods
 * change, so cell renderers and scales are stable references for React.memo.
 */
export function usePriceTrendTable(
  rawRows: Array<Record<string, unknown>>,
  periods: PriceTrendPeriod[],
): UsePriceTrendTableResult {
  const rows = React.useMemo(() => buildRows(rawRows, periods), [rawRows, periods]);
  const scales = React.useMemo(() => calculatePeriodScales(rawRows, periods), [rawRows, periods]);
  return { rows, scales };
}
