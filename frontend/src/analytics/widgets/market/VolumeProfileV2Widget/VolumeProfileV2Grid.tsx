"use client";

import * as React from "react";
import { useVirtualizer } from "@tanstack/react-virtual";
import type { VolumeProfileV2Row, VolumeProfileV2SortMetric, VolumeProfileV2SortDir } from "./VolumeProfileV2.types";
import { RelativeBarCell } from "./RelativeBarCell";
import { Tooltip } from "./Tooltip";
import { formatVolume, formatRelative } from "./VolumeProfileV2.utils";

export const COMPANY_COL_MIN = 240;
export const COUNT_COL_WIDTH = 64;
export const MIN_PERIOD_WIDTH = 130;
export const ROW_HEIGHT = 44;

const METRIC_KEYS = ["relative1W", "relative1M", "relative1Y"] as const;

export interface VolumeProfileV2GridProps {
  rows: VolumeProfileV2Row[];
  columnWidths?: number[];
  scales: Map<string, { metric: string; maxAbs: number }>;
  sortMetric: VolumeProfileV2SortMetric;
  sortDir: VolumeProfileV2SortDir;
  onSortChange: (metric: VolumeProfileV2SortMetric) => void;
  onSortDirToggle: () => void;
  onExport?: () => void;
  onFullscreenToggle?: () => void;
  onEntityClick?: (name: string) => void;
}

type SortColumn = VolumeProfileV2SortMetric;
type SortDir = "asc" | "desc";

function SortIndicator({ col, sortColumn, sortDir }: { col: SortColumn; sortColumn: SortColumn; sortDir: SortDir }) {
  if (sortColumn !== col) return <span className="ml-1 text-[10px] text-muted-foreground">⇅</span>;
  return <span className="ml-1 text-[10px]">{sortDir === "asc" ? "↑" : "↓"}</span>;
}

export function VolumeProfileV2Grid({
  rows,
  columnWidths,
  scales,
  sortMetric,
  sortDir,
  onSortChange,
  onSortDirToggle,
  onExport,
  onFullscreenToggle,
  onEntityClick,
}: VolumeProfileV2GridProps) {
  const scrollRef = React.useRef<HTMLDivElement>(null);
  const [tooltip, setTooltip] = React.useState<{ x: number; y: number; content: React.ReactNode } | null>(null);

  const [width, setWidth] = React.useState<number | undefined>(undefined);
  React.useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    const update = () => setWidth(el.clientWidth);
    update();
    const ro = new ResizeObserver(() => update());
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const computedWidths = React.useMemo(() => {
    if (!width) return columnWidths ?? [COMPANY_COL_MIN, COUNT_COL_WIDTH, MIN_PERIOD_WIDTH, MIN_PERIOD_WIDTH, MIN_PERIOD_WIDTH];
    const fixed = COUNT_COL_WIDTH + MIN_PERIOD_WIDTH * 3 + 16;
    const companyWidth = Math.max(COMPANY_COL_MIN, Math.min(400, width - fixed));
    return [companyWidth, COUNT_COL_WIDTH, MIN_PERIOD_WIDTH, MIN_PERIOD_WIDTH, MIN_PERIOD_WIDTH];
  }, [width, columnWidths]);

  const sortedRows = React.useMemo(() => {
    const data = [...rows];
    data.sort((a, b) => {
      let aVal: number | string;
      let bVal: number | string;
      aVal = a.name;
      bVal = b.name;
      if (sortMetric !== "name") {
        const field = sortMetric === "count" ? "companyCount" : sortMetric;
        const aV = a[field];
        const bV = b[field];
        aVal = typeof aV === "number" ? aV : 0;
        bVal = typeof bV === "number" ? bV : 0;
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

  const companyWidth = computedWidths[0] ?? COMPANY_COL_MIN;
  const countWidth = computedWidths[1] ?? COUNT_COL_WIDTH;
  const periodWidths = computedWidths.slice(2);

  const handleSort = (col: VolumeProfileV2SortMetric) => {
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
              {METRIC_KEYS.map((key) => (
                <th key={key} className="px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort(key)} className="hover:underline">
                    {key === "relative1W" ? "Rel (1W)" : key === "relative1M" ? "Rel (1M)" : "Rel (1Y)"}
                    <SortIndicator col={key} sortColumn={sortMetric} sortDir={sortDir} />
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
                  {METRIC_KEYS.map((key, i) => {
                    const scale = scales.get(key) ?? { metric: key, maxAbs: 1 };
                    const value = row[key];
                    const label = typeof value === "number" ? formatRelative(value) : "—";
                    const width = periodWidths[i] ?? MIN_PERIOD_WIDTH;
                    return (
                      <td key={key} className="px-2 py-2 text-left" style={{ minWidth: width }}>
                        <RelativeBarCell
                          value={value}
                          label={label}
                          maxAbs={scale.maxAbs}
                          row={row}
                          metric={key}
                          onHover={setTooltip}
                        />
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
