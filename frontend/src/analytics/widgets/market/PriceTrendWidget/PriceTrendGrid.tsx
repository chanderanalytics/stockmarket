import * as React from "react";
import type { PriceTrendPeriod, PriceTrendSortMetric, PriceTrendSortDir } from "./PriceTrend.types";
import type { PriceTrendGridRow } from "./buildRows";
import type { PeriodScale } from "./calculatePeriodScales";
import { PriceTrendTable, COMPANY_COL_MIN, COUNT_COL_WIDTH, MIN_PERIOD_WIDTH } from "./PriceTrendTable";
import { useDebouncedResize } from "./useResize";

export interface PriceTrendGridProps {
  rows: PriceTrendGridRow[];
  periods: PriceTrendPeriod[];
  scales: Map<PriceTrendPeriod, PeriodScale>;
  sortMetric: PriceTrendSortMetric;
  sortDir: PriceTrendSortDir;
  onSortChange: (metric: PriceTrendSortMetric) => void;
  onSortDirToggle: () => void;
  onExport?: () => void;
  onFullscreenToggle?: () => void;
}

/**
 * Outer grid: measures available width, distributes it across period columns
 * (company column is fixed at 220px and sticky), and renders the virtualized
 * table. When the required width exceeds the viewport, horizontal scrolling
 * kicks in and the company column stays pinned — Bloomberg style.
 */
export function PriceTrendGrid({
  rows,
  periods,
  scales,
  sortMetric,
  sortDir,
  onSortChange,
  onSortDirToggle,
  onExport,
  onFullscreenToggle,
}: PriceTrendGridProps) {
  const containerRef = React.useRef<HTMLDivElement>(null);
  const width = useDebouncedResize(containerRef);

  const columnWidths = React.useMemo(() => {
    const viewport = width ?? 1200;
    const n = Math.max(1, periods.length);
    const minPeriodTotal = MIN_PERIOD_WIDTH * n;
    const availableForCompany = Math.max(COMPANY_COL_MIN, viewport - 16 - COUNT_COL_WIDTH - minPeriodTotal);
    const companyWidth = Math.min(400, availableForCompany);
    const widths = [companyWidth, COUNT_COL_WIDTH];
    for (let i = 0; i < n; i++) widths.push(MIN_PERIOD_WIDTH);
    return widths;
  }, [width, periods.length]);

  return (
    <div ref={containerRef} className="flex flex-col gap-2">
      <div className="flex items-center justify-end gap-2">
        <button
          type="button"
          onClick={onFullscreenToggle}
          className="flex h-8 w-8 items-center justify-center rounded-md border border-border hover:bg-accent"
          title="Fullscreen"
        >
          ⤢
        </button>
        <button
          type="button"
          onClick={onExport}
          className="flex h-8 items-center gap-1.5 rounded-md border border-border px-2 text-xs hover:bg-accent"
          title="Export CSV"
        >
          Export
        </button>
      </div>
      <PriceTrendTable
        rows={rows}
        periods={periods}
        scales={scales}
        columnWidths={columnWidths}
        sortMetric={sortMetric}
        sortDir={sortDir}
        onSortChange={onSortChange}
        onSortDirToggle={onSortDirToggle}
      />
    </div>
  );
}
