import * as React from "react";
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  flexRender,
  type SortingState,
  type ColumnSizingState,
} from "@tanstack/react-table";
import { useVirtualizer } from "@tanstack/react-virtual";
import type { PriceTrendPeriod, PriceTrendSortMetric, PriceTrendSortDir } from "./PriceTrend.types";
import type { PriceTrendGridRow } from "./buildRows";
import type { PeriodScale } from "./calculatePeriodScales";
import { buildColumns } from "./buildColumns";
import { ReturnBarCell, type TooltipPayload } from "./ReturnBarCell";
import { Tooltip } from "./Tooltip";

export const COMPANY_COL_MIN = 240;
export const COUNT_COL_WIDTH = 64;
export const MIN_PERIOD_WIDTH = 130;
export const ROW_HEIGHT = 44;

export interface PriceTrendTableProps {
  rows: PriceTrendGridRow[];
  periods: PriceTrendPeriod[];
  scales: Map<PriceTrendPeriod, PeriodScale>;
  columnWidths: number[]; // [company, period0, period1, ...]
  sortMetric: PriceTrendSortMetric;
  sortDir: PriceTrendSortDir;
  onSortChange: (metric: PriceTrendSortMetric) => void;
  onSortDirToggle: () => void;
  onColumnResize?: (widths: number[]) => void;
}

function sortToState(metric: PriceTrendSortMetric, dir: PriceTrendSortDir): SortingState {
  return [{ id: metric, desc: dir === "desc" }];
}

export function PriceTrendTable({
  rows,
  periods,
  scales,
  columnWidths,
  sortMetric,
  sortDir,
  onSortChange,
  onSortDirToggle,
}: PriceTrendTableProps) {
  const [tooltip, setTooltip] = React.useState<TooltipPayload | null>(null);
  const scrollRef = React.useRef<HTMLDivElement>(null);

  const columns = React.useMemo(() => buildColumns(periods), [periods]);

  const sorting = React.useMemo(() => sortToState(sortMetric, sortDir), [sortMetric, sortDir]);

  const table = useReactTable({
    data: rows,
    columns,
    state: { sorting },
    onSortingChange: () => {
      // Header click toggles direction if same metric, else switches metric.
      // We drive the backend sort, so just toggle dir for the active metric.
      onSortDirToggle();
    },
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getRowId: (row) => row.id,
  });

  const tableRows = table.getRowModel().rows;

  const virtualizer = useVirtualizer({
    count: tableRows.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => ROW_HEIGHT,
    overscan: 12,
  });

  const items = virtualizer.getVirtualItems();
  const companyWidth = columnWidths[0] ?? COMPANY_COL_MIN;
  const countWidth = columnWidths[1] ?? COUNT_COL_WIDTH;
  const periodWidths = columnWidths.slice(2);

  const handleHeaderClick = (columnId: string) => {
    if (columnId === "company") {
      onSortChange("name");
      return;
    }
    if (columnId === "count") {
      onSortChange("name");
      return;
    }
    if (columnId === "marketCap") {
      onSortChange("marketCap");
      return;
    }
    onSortChange(columnId as PriceTrendSortMetric);
  };

  const gridTemplate = columnWidths.map((w) => `${w}px`).join(" ");

  return (
    <div className="relative">
      <Tooltip payload={tooltip} />
      <div
        ref={scrollRef}
        className="overflow-auto rounded-md border border-border"
        style={{ maxHeight: "calc(100vh - 280px)" }}
      >
        <div
          className="sticky top-0 z-20 grid bg-muted/95 backdrop-blur"
          style={{ gridTemplateColumns: gridTemplate }}
        >
          {table.getHeaderGroups().map((hg) =>
            hg.headers.map((header, i) => {
              const isCompany = header.column.id === "company";
              const sorted = header.column.getIsSorted();
              return (
                <div
                  key={header.id}
                  onClick={() => handleHeaderClick(header.column.id)}
                  className={`cursor-pointer select-none border-b border-r border-border ${
                    isCompany ? "sticky left-0 z-30 bg-muted/95" : ""
                  }`}
                  style={{ padding: "8px 12px" }}
                >
                  <div className="flex items-center gap-1">
                    <span className="text-left font-semibold text-foreground">
                      {flexRender(header.column.columnDef.header, header.getContext())}
                    </span>
                    {sorted === "asc" && <span className="text-[10px]">▲</span>}
                    {sorted === "desc" && <span className="text-[10px]">▼</span>}
                  </div>
                </div>
              );
            })
          )}
        </div>

        <div style={{ height: virtualizer.getTotalSize(), position: "relative" }}>
          {items.map((vItem) => {
            const row = tableRows[vItem.index];
            const original = row.original;
            return (
              <div
                key={row.id}
                className="group absolute grid hover:bg-accent/40"
                style={{
                  top: 0,
                  left: 0,
                  width: "100%",
                  height: ROW_HEIGHT,
                  transform: `translateY(${vItem.start}px)`,
                  gridTemplateColumns: gridTemplate,
                }}
              >
                {row.getVisibleCells().map((cell, i) => {
                  const isCompany = cell.column.id === "company";
                  const isCount = cell.column.id === "count";
                  const meta = cell.column.columnDef.meta as
                    | { kind: "company" }
                    | { kind: "period"; period: PriceTrendPeriod }
                    | undefined;

                  if (isCompany) {
                    return (
                      <div
                        key={cell.id}
                        className="sticky left-0 z-10 flex h-full items-center border-b border-r border-border bg-background px-3 group-hover:bg-accent/40"
                        style={{ minWidth: companyWidth }}
                      >
                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                      </div>
                    );
                  }

                  if (isCount) {
                    return (
                      <div
                        key={cell.id}
                        className="flex h-full items-center border-b border-r border-border px-3"
                        style={{ minWidth: countWidth }}
                      >
                        <span className="text-xs tabular-nums text-muted-foreground">
                          {typeof original.companyCount === "number" ? original.companyCount.toLocaleString() : "—"}
                        </span>
                      </div>
                    );
                  }

                  const period = (meta as { kind: "period"; period: PriceTrendPeriod }).period;
                  const scale = scales.get(period);
                  return (
                    <div
                      key={cell.id}
                      className="flex h-full items-center border-b border-r border-border px-3"
                      style={{ minWidth: periodWidths[i - 2] }}
                    >
                      {scale && (
                        <ReturnBarCell row={original} period={period} scale={scale} onHover={setTooltip} />
                      )}
                    </div>
                  );
                })}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
