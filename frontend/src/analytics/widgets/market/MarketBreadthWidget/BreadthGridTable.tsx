"use client";

import * as React from "react";
import type { BreadthRow, BreadthHorizon, BreadthSignalType } from "./types";
import { HORIZON_ORDER, HORIZON_LABELS, SIGNAL_TYPE_LABELS } from "./types";

export type BreadthMetricMode = "compositeBreadth" | "aboveDMA";

interface BreadthGridTableProps {
  rows: BreadthRow[];
  selectedHorizons: BreadthHorizon[];
  signalType?: BreadthSignalType;
  metricMode?: BreadthMetricMode;
  onMetricModeChange?: (mode: BreadthMetricMode) => void;
  onSignalTypeChange?: (type: BreadthSignalType) => void;
  onHorizonsChange?: (horizons: BreadthHorizon[]) => void;
  onExport?: () => void;
  onFullscreenToggle?: () => void;
  onEntityClick?: (name: string) => void;
}

const DMA_WEIGHTS: Record<number, number> = { 20: 0.15, 50: 0.25, 100: 0.25, 200: 0.35 };

function breadthFor(row: BreadthRow, key: string): number | null {
  const m = row.horizons?.[key];
  return m && typeof m.breadthScore === "number" ? m.breadthScore : null;
}

function computeCompositeBreadth(aboveDMA: Record<string, { count?: number; percentage: number }>): number {
  let weightedSum = 0;
  let totalWeight = 0;
  for (const [dma, data] of Object.entries(aboveDMA)) {
    const period = parseInt(dma.replace("dma", ""), 10);
    const weight = DMA_WEIGHTS[period];
    if (weight && typeof data.percentage === "number") {
      weightedSum += data.percentage * weight;
      totalWeight += weight;
    }
  }
  return totalWeight > 0 ? weightedSum / totalWeight : 0;
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
      <span className="text-xs font-medium tabular-nums">{value == null ? "—" : Math.round(v)}</span>
      <div className="h-3 w-full overflow-hidden rounded-full bg-muted">
        <div className="h-full rounded-full" style={{ width: `${pct}%`, backgroundColor: color }} />
      </div>
    </div>
  );
}

type SortColumn = "name" | "count" | string;
type SortDir = "asc" | "desc";

function SortIndicator({ col, sortColumn, sortDir }: { col: SortColumn; sortColumn: SortColumn; sortDir: SortDir }) {
  if (sortColumn !== col) return <span className="ml-1 text-[10px] text-muted-foreground">⇅</span>;
  return <span className="ml-1 text-[10px]">{sortDir === "asc" ? "↑" : "↓"}</span>;
}

export function BreadthGridTable({
  rows,
  selectedHorizons,
  signalType,
  metricMode = "compositeBreadth",
  onMetricModeChange,
  onSignalTypeChange,
  onHorizonsChange,
  onExport,
  onFullscreenToggle,
  onEntityClick,
}: BreadthGridTableProps) {
  const signalLabel = signalType ? (SIGNAL_TYPE_LABELS[signalType] ?? "Signal") : "Signal";
  const [sortColumn, setSortColumn] = React.useState<SortColumn>("name");
  const [sortDir, setSortDir] = React.useState<SortDir>("desc");

  const handleSort = React.useCallback((col: SortColumn) => {
    if (sortColumn === col) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortColumn(col);
      setSortDir("desc");
    }
  }, [sortColumn]);

  const sortedRows = React.useMemo(() => {
    const data = [...rows];
    data.sort((a, b) => {
      let aVal: number | string;
      let bVal: number | string;
      if (sortColumn === "name") {
        aVal = a.name;
        bVal = b.name;
      } else if (sortColumn === "count") {
        aVal = a.companyCount ?? 0;
        bVal = b.companyCount ?? 0;
      } else if (sortColumn.startsWith("composite-")) {
        const h = sortColumn.slice("composite-".length);
        aVal = (a.horizons?.[h]?.compositeBreadth) ?? 0;
        bVal = (b.horizons?.[h]?.compositeBreadth) ?? 0;
      } else {
        aVal = breadthFor(a, sortColumn) ?? 0;
        bVal = breadthFor(b, sortColumn) ?? 0;
      }
      if (typeof aVal === "number" && typeof bVal === "number") {
        return sortDir === "asc" ? aVal - bVal : bVal - aVal;
      }
      const aStr = String(aVal).toLowerCase();
      const bStr = String(bVal).toLowerCase();
      return sortDir === "asc" ? aStr.localeCompare(bStr) : bStr.localeCompare(aStr);
    });
    return data;
  }, [rows, sortColumn, sortDir]);

  const showComposite = metricMode === "compositeBreadth";

  return (
    <div className="relative">
      <div className="mb-2 text-sm font-medium text-foreground">Market Breadth by DMA</div>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          {(["compositeBreadth", "aboveDMA"] as const).map((mode) => (
            <button
              key={mode}
              type="button"
              onClick={() => onMetricModeChange?.(mode)}
              className={`h-8 rounded-md border px-2.5 text-xs font-medium transition-colors select-none capitalize bg-transparent ${
                metricMode === mode ? "border-foreground text-foreground" : "border-border text-muted-foreground hover:bg-muted"
              }`}
            >
              {mode === "compositeBreadth" ? "Composite Breadth" : signalLabel}
            </button>
          ))}
        </div>
        <div className="flex flex-col items-end gap-2">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-[11px] text-muted-foreground">Signals:</span>
            {(Object.keys(SIGNAL_TYPE_LABELS) as BreadthSignalType[]).map((type) => (
              <button
                key={type}
                type="button"
                onClick={() => onSignalTypeChange?.(type)}
                className={`h-8 rounded-md border px-2.5 text-xs font-medium transition-colors select-none capitalize bg-transparent ${
                  signalType === type ? "border-foreground text-foreground" : "border-border text-muted-foreground hover:bg-muted"
                }`}
              >
                {SIGNAL_TYPE_LABELS[type]}
              </button>
            ))}
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-[11px] text-muted-foreground">Periods:</span>
            {HORIZON_ORDER.map((h) => (
              <button
                key={h}
                type="button"
                onClick={() => {
                  if (selectedHorizons.includes(h)) {
                    if (selectedHorizons.length > 1) {
                      onHorizonsChange?.(selectedHorizons.filter((x) => x !== h));
                    }
                  } else {
                    onHorizonsChange?.([...selectedHorizons, h].sort((a, b) => a - b));
                  }
                }}
                className={`h-8 rounded-md border px-2.5 text-xs font-medium transition-colors select-none bg-transparent ${
                  selectedHorizons.includes(h) ? "border-foreground text-foreground" : "border-border text-muted-foreground hover:bg-muted"
                }`}
              >
                {HORIZON_LABELS[h]}
              </button>
            ))}
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
        </div>
      </div>
      <div className="mt-3 overflow-auto rounded-md border border-border" style={{ maxHeight: "calc(100vh - 320px)" }}>
        <table className="w-full text-sm border-separate border-spacing-0">
          <thead className="sticky top-0 z-30 bg-muted text-left text-xs uppercase text-muted-foreground">
            <tr>
              <th rowSpan={2} className="sticky left-0 z-40 px-3 py-2 text-left">
                <button type="button" onClick={() => handleSort("name")} className="hover:underline">
                  Entity <SortIndicator col="name" sortColumn={sortColumn} sortDir={sortDir} />
                </button>
              </th>
              <th rowSpan={2} className="sticky left-[240px] z-40 px-3 py-2 text-left">
                <button type="button" onClick={() => handleSort("count")} className="hover:underline">
                  Count <SortIndicator col="count" sortColumn={sortColumn} sortDir={sortDir} />
                </button>
              </th>
              {showComposite ? (
                <th colSpan={selectedHorizons.length} className="px-3 py-2 text-left">
                  Composite Breadth
                </th>
              ) : (
                <th colSpan={selectedHorizons.length} className="px-3 py-2 text-left">
                  {signalLabel} (%)
                </th>
              )}
            </tr>
            <tr>
              {selectedHorizons.map((h) => (
                <th key={`${metricMode}-${h}`} className="px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort(`${metricMode === "compositeBreadth" ? "composite" : String(h)}-${h}`)} className="hover:underline">
                    {HORIZON_LABELS[h]} <SortIndicator col={`${metricMode === "compositeBreadth" ? "composite" : String(h)}-${h}`} sortColumn={sortColumn} sortDir={sortDir} />
                  </button>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {sortedRows.map((row) => {
              const crumb = [row.sector, row.industry, row.industrySubGroup].filter(Boolean).join(" › ");
              const rowKey = `${row.name}-${row.industrySubGroup || row.industry || row.sector || "root"}`;
              return (
                <tr key={rowKey} className="border-t border-border hover:bg-accent/40">
                  <td className="sticky left-0 z-10 px-3 py-2 text-left">
                    <button
                      type="button"
                      onClick={() => onEntityClick?.(row.name)}
                      className="flex flex-col text-left hover:underline disabled:opacity-50"
                      disabled={!onEntityClick}
                    >
                      <span className="font-medium text-foreground">{row.name}</span>
                      {crumb && <span className="text-xs text-muted-foreground">{crumb}</span>}
                    </button>
                  </td>
                  <td className="sticky left-[240px] z-10 px-3 py-2 text-left tabular-nums text-muted-foreground">
                    {typeof row.companyCount === "number" ? row.companyCount.toLocaleString() : "—"}
                  </td>
                  {selectedHorizons.map((h) => {
                    if (showComposite) {
                      const composite = row.horizons?.[String(h)]?.compositeBreadth;
                      return (
                        <td key={`composite-${h}`} className="px-2 py-2 text-left">
                          <BreadthBar value={typeof composite === "number" ? composite : null} />
                        </td>
                      );
                    }
                    return (
                      <td key={`signal-${h}`} className="px-2 py-2 text-left">
                        <BreadthBar value={breadthFor(row, String(h))} />
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
