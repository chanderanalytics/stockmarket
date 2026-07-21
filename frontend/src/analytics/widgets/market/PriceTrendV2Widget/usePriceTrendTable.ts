import * as React from "react";
import type { PriceTrendV2Period } from "./PriceTrendV2.types";
import { buildRows, type PriceTrendV2GridRow } from "./buildRows";
import { calculatePeriodScales, type PeriodScale } from "./calculatePeriodScales";

export interface UsePriceTrendTableResult {
  rows: PriceTrendV2GridRow[];
  scales: Map<PriceTrendV2Period, PeriodScale>;
}

export function usePriceTrendTable(
  rawRows: Array<Record<string, unknown>>,
  periods: PriceTrendV2Period[],
): UsePriceTrendTableResult {
  const rows = React.useMemo(() => buildRows(rawRows, periods), [rawRows, periods]);
  const scales = React.useMemo(() => calculatePeriodScales(rawRows, periods), [rawRows, periods]);
  return { rows, scales };
}
