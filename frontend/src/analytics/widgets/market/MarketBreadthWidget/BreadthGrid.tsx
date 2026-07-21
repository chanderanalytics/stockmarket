"use client";

import * as React from "react";
import { useReactTable, getCoreRowModel, flexRender, type ColumnDef } from "@tanstack/react-table";
import { useVirtualizer } from "@tanstack/react-virtual";
import type { BreadthRow, BreadthHorizon } from "./types";
import { HORIZON_ORDER, HORIZON_LABELS } from "./types";

export const COMPANY_COL_MIN = 200;
export const COUNT_COL_WIDTH = 64;
export const MIN_PERIOD_WIDTH = 120;
export const ROW_HEIGHT = 44;

interface BreadthGridProps {
  rows: BreadthRow[];
  selectedHorizons: BreadthHorizon[];
  onExport?: () => void;
  onFullscreenToggle?: () => void;
  onEntityClick?: (name: string) => void;
}

function breadthFor(row: BreadthRow, key: string): number | null {
  const m = row.horizons?.[key];
  return m && typeof m.breadthScore === "number" ? m.breadthScore : null;
}

function breadthColor(value: number): string {
  if (value < 20) return "#991b1b";
  if (value < 40) return "#ef4444";
  if (value < 60) return "#f59e0b";
  if (value < 80) return "#4ade80";
  return "#15803d";
}

function BreadthBar({ value }: { value: number | null }) {
  const v = value ?? 0;
  const pct = Math.max(0, Math.min(100, v));
  const color = breadthColor(pct);
  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-xs font-medium tabular-nums">{value == null ? "—" : v.toFixed(1)}</span>
      <div className="h-3 w-full overflow-hidden rounded-full bg-muted">
        <div className="h-full rounded-full" style={{ width: `${pct}%`, backgroundColor: color }} />
      </div>
    </div>
  );
}

export function BreadthGrid({
  rows,
  selectedHorizons,
  onExport,
  onFullscreenToggle,
  onEntityClick,
}: BreadthGridProps) {
  const scrollRef = React.useRef<HTMLDivElement>(null);
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

  const horizonCols = selectedHorizons.map((h) => String(h));

  const computedWidths = React.useMemo(() => {
    if (!width) return [COMPANY_COL_MIN, COUNT_COL_WIDTH, ...horizonCols.map(() => MIN_PERIOD_WIDTH)];
    const fixed = COUNT_COL_WIDTH + MIN_PERIOD_WIDTH * horizonCols.length + 16;
    const companyWidth = Math.max(COMPANY_COL_MIN, Math.min(400, width - fixed));
    return [companyWidth, COUNT_COL_WIDTH, ...horizonCols.map(() => MIN_PERIOD_WIDTH)];
  }, [width, horizonCols.length]);

  const gridTemplate = computedWidths.map((w) => `${w}px`).join(" ");

  const columns = React.useMemo<ColumnDef<BreadthRow>[]>(
    () => [
      {
        id: "entity",
        header: "Entity",
        cell: (ctx) => {
          const row = ctx.row.original;
          const crumb = [row.sector, row.industry, row.industrySubGroup].filter(Boolean).join(" › ");
          return (
            <div className="flex min-w-0 flex-col justify-center">
              <span className="text-sm font-medium text-foreground">{row.name}</span>
              {crumb && <span className="text-xs text-muted-foreground">{crumb}</span>}
            </div>
          );
        },
      },
      {
        id: "count",
        header: "Count",
        cell: (ctx) => {
          const row = ctx.row.original;
          const count = typeof row.companyCount === "number" ? row.companyCount : null;
          return (
            <div className="flex h-full items-center justify-center">
              <span className="text-xs tabular-nums text-muted-foreground">{count == null ? "—" : count.toLocaleString()}</span>
            </div>
          );
        },
      },
      ...selectedHorizons.map((h) => ({
        id: String(h),
        header: HORIZON_LABELS[h],
        cell: (ctx: { row: { original: BreadthRow } }) => (
          <BreadthBar value={breadthFor(ctx.row.original, String(h))} />
        ),
      })),
    ],
    [selectedHorizons],
  );

  const table = useReactTable({
    data: rows,
    columns,
    getCoreRowModel: getCoreRowModel(),
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
  const columnOrder = ["entity", ...selectedHorizons.map(String)];

  return (
    <div className="relative">
      <div className="flex items-center justify-end gap-2">
        <button type="button" onClick={onFullscreenToggle} className="flex h-8 w-8 items-center justify-center rounded-md border border-border hover:bg-accent" title="Fullscreen">⤢</button>
        <button type="button" onClick={onExport} className="flex h-8 items-center gap-1.5 rounded-md border border-border px-2 text-xs hover:bg-accent" title="Export CSV">Export</button>
      </div>
      <div ref={scrollRef} className="overflow-auto rounded-md border border-border" style={{ maxHeight: "calc(100vh - 320px)" }}>
        <div className="sticky top-0 z-20 grid bg-muted/95 backdrop-blur" style={{ gridTemplateColumns: gridTemplate }}>
          {table.getHeaderGroups().map((hg) =>
            hg.headers.map((header) => {
              const isCompany = header.column.id === "entity";
              return (
                <div
                  key={header.id}
                  className={`cursor-pointer select-none border-b border-r border-border ${isCompany ? "sticky left-0 z-30 bg-muted/95" : ""}`}
                  style={{ padding: "8px 12px" }}
                >
                  <span className="text-left font-semibold text-foreground">{flexRender(header.column.columnDef.header, header.getContext())}</span>
                </div>
              );
            }),
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
                style={{ top: 0, left: 0, width: "100%", height: ROW_HEIGHT, transform: `translateY(${vItem.start}px)`, gridTemplateColumns: gridTemplate }}
              >
                {row.getVisibleCells().map((cell) => {
                  const isCompany = cell.column.id === "entity";
                  const idx = columnOrder.indexOf(cell.column.id);
                  const w = computedWidths[idx] ?? MIN_PERIOD_WIDTH;
                  if (isCompany) {
                    return (
                      <div
                        key={cell.id}
                        className="sticky left-0 z-10 flex h-full cursor-pointer items-center border-b border-r border-border bg-background px-3 group-hover:bg-accent/40"
                        style={{ minWidth: w }}
                        onClick={() => onEntityClick?.(original.name)}
                      >
                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                      </div>
                    );
                  }
                  return (
                    <div key={cell.id} className="flex h-full items-center border-b border-r border-border px-3" style={{ minWidth: w }}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
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
