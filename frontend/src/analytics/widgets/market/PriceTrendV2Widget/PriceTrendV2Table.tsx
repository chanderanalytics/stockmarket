"use client";

import * as React from "react";
import { useVirtualizer } from "@tanstack/react-virtual";
import type { PriceTrendV2Period, PriceTrendV2SortMetric, PriceTrendV2SortDir } from "./PriceTrendV2.types";
import type { PriceTrendV2GridRow } from "./buildRows";
import type { PeriodScale } from "./calculatePeriodScales";
import { ReturnBarCell, type TooltipPayload } from "./ReturnBarCell";
import { Tooltip } from "./Tooltip";
import { PERIOD_LABELS } from "./PriceTrendV2.columns";

export const COMPANY_COL_MIN = 240;
export const COUNT_COL_WIDTH = 64;
export const MIN_PERIOD_WIDTH = 130;
export const ROW_HEIGHT = 44;

export interface PriceTrendV2TableProps {
  rows: PriceTrendV2GridRow[];
  periods: PriceTrendV2Period[];
  scales: Map<PriceTrendV2Period, PeriodScale>;
  columnWidths: number[];
  sortMetric: PriceTrendV2SortMetric;
  sortDir: PriceTrendV2SortDir;
  onSortChange: (metric: PriceTrendV2SortMetric) => void;
  onSortDirToggle: () => void;
  onExport?: () => void;
  onFullscreenToggle?: () => void;
  onEntityClick?: (name: string) => void;
}

type SortColumn = "name" | "marketCap" | "weightedMarketCap" | "count" | PriceTrendV2Period;
type SortDir = "asc" | "desc";

function SortIndicator({ col, sortColumn, sortDir }: { col: SortColumn; sortColumn: SortColumn; sortDir: SortDir }) {
  if (sortColumn !== col) return <span className="ml-1 text-[10px] text-muted-foreground">⇅</span>;
  return <span className="ml-1 text-[10px]">{sortDir === "asc" ? "↑" : "↓"}</span>;
}

export function PriceTrendV2Table({
  rows,
  periods,
  scales,
  columnWidths,
  sortMetric,
  sortDir,
  onSortChange,
  onSortDirToggle,
  onExport,
  onFullscreenToggle,
  onEntityClick,
}: PriceTrendV2TableProps) {
  const [tooltip, setTooltip] = React.useState<TooltipPayload | null>(null);
  const scrollRef = React.useRef<HTMLDivElement>(null);

  const sortedRows = React.useMemo(() => {
    const data = [...rows];
    data.sort((a, b) => {
      let aVal: number | string;
      let bVal: number | string;
      if (sortMetric === "name") {
        aVal = a.name;
        bVal = b.name;
      } else if (sortMetric === "marketCap" || sortMetric === "weightedMarketCap") {
        aVal = a.marketCap ?? 0;
        bVal = b.marketCap ?? 0;
      } else if (sortMetric === "count") {
        aVal = a.companyCount ?? 0;
        bVal = b.companyCount ?? 0;
      } else {
        const period = sortMetric as PriceTrendV2Period;
        const aV = a.values.get(period);
        const bV = b.values.get(period);
        aVal = Number.isFinite(aV) ? (aV as number) : 0;
        bVal = Number.isFinite(bV) ? (bV as number) : 0;
      }
      if (typeof aVal === "number" && typeof bVal === "number") {
        return sortDir === "asc" ? aVal - bVal : bVal - aVal;
      }
      const aStr = String(aVal).toLowerCase();
      const bStr = String(bVal).toLowerCase();
      return sortDir === "asc" ? aStr.localeCompare(bStr) : bStr.localeCompare(aStr);
    });
    return data;
  }, [rows, sortMetric, sortDir]);

  const companyWidth = columnWidths[0] ?? COMPANY_COL_MIN;
  const countWidth = columnWidths[1] ?? COUNT_COL_WIDTH;
  const periodWidths = columnWidths.slice(2);

  const handleSort = (col: PriceTrendV2SortMetric) => {
    if (sortMetric === col) {
      onSortDirToggle();
    } else {
      onSortChange(col);
    }
  };

  const virtualizer = useVirtualizer({
    count: sortedRows.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => ROW_HEIGHT,
    overscan: 12,
  });

  const items = virtualizer.getVirtualItems();

  return (
    <div className="relative">
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
      <div ref={scrollRef} className="overflow-auto rounded-md border border-border" style={{ maxHeight: "calc(100vh - 320px)" }}>
        <table className="w-full text-sm border-separate border-spacing-0">
          <thead className="sticky top-0 z-30 bg-muted text-left text-xs uppercase text-muted-foreground">
            <tr>
              <th rowSpan={2} className="sticky left-0 z-40 bg-muted px-3 py-2 text-left">
                <button type="button" onClick={() => handleSort("name")} className="hover:underline">
                  Entity <SortIndicator col="name" sortColumn={sortMetric} sortDir={sortDir} />
                </button>
              </th>
              <th rowSpan={2} className="px-3 py-2 text-left tabular-nums">
                <button type="button" onClick={() => handleSort("count")} className="hover:underline">
                  Count <SortIndicator col="count" sortColumn={sortMetric} sortDir={sortDir} />
                </button>
              </th>
              {periods.map((p) => (
                <th key={p} className="px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort(p)} className="hover:underline">
                    {PERIOD_LABELS[p] || p} <SortIndicator col={p} sortColumn={sortMetric} sortDir={sortDir} />
                  </button>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {items.map((vItem) => {
              const row = sortedRows[vItem.index];
              return (
                <tr
                  key={row.id}
                  className="border-t border-border hover:bg-accent/40"
                  style={{ height: ROW_HEIGHT }}
                >
                  <td className="sticky left-0 z-10 bg-background px-3 py-2 text-left font-medium hover:bg-accent/40" style={{ minWidth: companyWidth }}>
                    <button
                      type="button"
                      onClick={() => onEntityClick?.(row.name)}
                      className="flex flex-col text-left hover:underline disabled:opacity-50"
                      disabled={!onEntityClick}
                    >
                      <span className="text-foreground">{row.name}</span>
                      <span className="text-xs text-muted-foreground">
                        {[row.sector, row.industry, row.industrySubGroup].filter(Boolean).join(" › ")}
                      </span>
                    </button>
                  </td>
                  <td className="px-3 py-2 text-left tabular-nums text-muted-foreground" style={{ minWidth: countWidth }}>
                    {typeof row.companyCount === "number" ? row.companyCount.toLocaleString() : "—"}
                  </td>
                  {periods.map((p, i) => {
                    const scale = scales.get(p);
                    const width = periodWidths[i] ?? MIN_PERIOD_WIDTH;
                    return (
                      <td key={p} className="px-2 py-2 text-left" style={{ minWidth: width }}>
                        {scale && (
                          <ReturnBarCell
                            row={row}
                            period={p}
                            scale={scale}
                            onHover={setTooltip}
                          />
                        )}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
        <div style={{ height: virtualizer.getTotalSize(), position: "relative" }} />
      </div>
      <Tooltip payload={tooltip} />
    </div>
  );
}
