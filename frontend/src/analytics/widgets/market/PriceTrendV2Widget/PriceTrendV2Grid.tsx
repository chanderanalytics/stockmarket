import * as React from "react";
import type { PriceTrendV2Period, PriceTrendV2SortMetric, PriceTrendV2SortDir } from "./PriceTrendV2.types";
import type { PriceTrendV2GridRow } from "./buildRows";
import type { PeriodScale } from "./calculatePeriodScales";
import { PriceTrendV2Table, COMPANY_COL_MIN, COUNT_COL_WIDTH, MIN_PERIOD_WIDTH } from "./PriceTrendV2Table";
import { useDebouncedResize } from "./useResize";

export interface PriceTrendV2GridProps {
  rows: PriceTrendV2GridRow[];
  periods: PriceTrendV2Period[];
  scales: Map<PriceTrendV2Period, PeriodScale>;
  sortMetric: PriceTrendV2SortMetric;
  sortDir: PriceTrendV2SortDir;
  onSortChange: (metric: PriceTrendV2SortMetric) => void;
  onSortDirToggle: () => void;
  onExport?: () => void;
  onFullscreenToggle?: () => void;
  onEntityClick?: (name: string) => void;
}

export function PriceTrendV2Grid({
  rows,
  periods,
  scales,
  sortMetric,
  sortDir,
  onSortChange,
  onSortDirToggle,
  onExport,
  onFullscreenToggle,
  onEntityClick,
}: PriceTrendV2GridProps) {
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
      <PriceTrendV2Table
        rows={rows}
        periods={periods}
        scales={scales}
        columnWidths={columnWidths}
        sortMetric={sortMetric}
        sortDir={sortDir}
        onSortChange={onSortChange}
        onSortDirToggle={onSortDirToggle}
        onExport={onExport}
        onFullscreenToggle={onFullscreenToggle}
        onEntityClick={onEntityClick}
      />
    </div>
  );
}
