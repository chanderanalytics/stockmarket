"use client";

import * as React from "react";
import type { BreadthHorizon, BreadthSummary } from "./types";
import { HORIZON_LABELS, HORIZON_ORDER } from "./types";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { Info } from "lucide-react";

interface DMADistanceTableProps {
  summary?: BreadthSummary;
  isLoading: boolean;
  period: BreadthHorizon;
  viewMode: "metrics" | "marketState";
  level: "market" | "sector" | "industry" | "industrySubGroup" | "company";
  rows: any[];
  onPeriodChange: (period: BreadthHorizon) => void;
  onViewModeChange: (mode: "metrics" | "marketState") => void;
  onExport?: () => void;
  onDrillDown?: (name: string) => void;
}

const DMA_PERIODS = [20, 50, 100, 200] as const;

function heatmapColor(_value: number, period: number): string {
  const bands = THRESHOLDS[period] || THRESHOLDS[50];
  const colorMap: Record<string, string> = {
    "Capitulation": "#991b1b",
    "Weak": "#ef4444",
    "Pullback": "#fca5a5",
    "Neutral": "#fff1f2",
    "Healthy": "#bbf7d0",
    "Strong": "#22c55e",
    "Overextended": "#14532d",
  };
  const band = bands.find((b) => _value >= b.min && _value < b.max) || bands[bands.length - 1];
  return colorMap[band.label] || "#fff1f2";
}

const THRESHOLDS: Record<number, { label: string; emoji: string; min: number; max: number }[]> = {
  20: [
    { label: "Capitulation", emoji: "🟣", min: -Infinity, max: -12 },
    { label: "Weak", emoji: "🔴", min: -12, max: -6 },
    { label: "Pullback", emoji: "🟠", min: -6, max: -2 },
    { label: "Neutral", emoji: "⚪", min: -2, max: 2 },
    { label: "Healthy", emoji: "🟢", min: 2, max: 6 },
    { label: "Strong", emoji: "🔵", min: 6, max: 10 },
    { label: "Overextended", emoji: "🟣", min: 10, max: Infinity },
  ],
  50: [
    { label: "Capitulation", emoji: "🟣", min: -Infinity, max: -18 },
    { label: "Weak", emoji: "🔴", min: -18, max: -10 },
    { label: "Pullback", emoji: "🟠", min: -10, max: -3 },
    { label: "Neutral", emoji: "⚪", min: -3, max: 3 },
    { label: "Healthy", emoji: "🟢", min: 3, max: 8 },
    { label: "Strong", emoji: "🔵", min: 8, max: 15 },
    { label: "Overextended", emoji: "🟣", min: 15, max: Infinity },
  ],
  100: [
    { label: "Capitulation", emoji: "🟣", min: -Infinity, max: -25 },
    { label: "Weak", emoji: "🔴", min: -25, max: -15 },
    { label: "Pullback", emoji: "🟠", min: -15, max: -5 },
    { label: "Neutral", emoji: "⚪", min: -5, max: 5 },
    { label: "Healthy", emoji: "🟢", min: 5, max: 12 },
    { label: "Strong", emoji: "🔵", min: 12, max: 20 },
    { label: "Overextended", emoji: "🟣", min: 20, max: Infinity },
  ],
  200: [
    { label: "Capitulation", emoji: "🟣", min: -Infinity, max: -35 },
    { label: "Weak", emoji: "🔴", min: -35, max: -20 },
    { label: "Pullback", emoji: "🟠", min: -20, max: -8 },
    { label: "Neutral", emoji: "⚪", min: -8, max: 8 },
    { label: "Healthy", emoji: "🟢", min: 8, max: 18 },
    { label: "Strong", emoji: "🔵", min: 18, max: 28 },
    { label: "Overextended", emoji: "🟣", min: 28, max: Infinity },
  ],
};

function stateFor(value: number, period: number): { label: string; min: number; max: number } {
  const bands = THRESHOLDS[period] || THRESHOLDS[50];
  const band = bands.find((b) => value >= b.min && value < b.max) || bands[bands.length - 1];
  return { label: band.label, min: band.min, max: band.max };
}

function trendArrow(classification?: string): string {
  switch (classification) {
    case "Accelerating": return "↗↗";
    case "Improving":
    case "Recovering": return "↗";
    case "Stable": return "→";
    case "Cooling": return "↘";
    case "Weakening":
    case "Breaking Down": return "↘↘";
    default: return "→";
  }
}

function MarketStateCell({ value, period, trend }: { value: number; period: number; trend?: { score: number; classification: string } }) {
  const band = stateFor(value, period);
  const colorMap: Record<string, string> = {
    "Capitulation": "#991b1b",
    "Weak": "#ef4444",
    "Pullback": "#fca5a5",
    "Neutral": "#fff1f2",
    "Healthy": "#bbf7d0",
    "Strong": "#22c55e",
    "Overextended": "#14532d",
  };
  const bg = colorMap[band.label] || "#fff1f2";
  const darkBg = ["#991b1b", "#14532d"].includes(bg);
  const arrow = trendArrow(trend?.classification);
  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <div className="flex cursor-help flex-col items-center gap-1">
            <span className="text-[11px] font-medium text-foreground">{band.label}</span>
            <span className="inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-xs font-medium" style={{ backgroundColor: bg, color: darkBg ? "#fff" : "#000" }}>
              <span className="text-[10px]">{arrow}</span>
            </span>
          </div>
        </TooltipTrigger>
        <TooltipContent>
          <p className="text-xs">{band.label}</p>
          <p className="text-[11px] text-muted-foreground">
            {band.min === -Infinity ? `< ${band.max}%` : band.max === Infinity ? `> ${band.min}%` : `${band.min}% – ${band.max}%`}
          </p>
          <p className="text-[11px] text-muted-foreground">{trend?.classification || "Stable"}</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}

function CellContent({ value, period, viewMode }: { value: number; period: number; viewMode: "metrics" | "marketState" }) {
  const band = stateFor(value, period);
  const colorMap: Record<string, string> = {
    "Capitulation": "#991b1b",
    "Weak": "#ef4444",
    "Pullback": "#fca5a5",
    "Neutral": "#fff1f2",
    "Healthy": "#bbf7d0",
    "Strong": "#22c55e",
    "Overextended": "#14532d",
  };
  const bg = colorMap[band.label] || "#fff1f2";
  const darkBg = ["#991b1b", "#14532d"].includes(bg);
  const tooltipContent = (
    <div className="text-xs">
      <p className="font-medium">{band.label}</p>
      <p className="text-muted-foreground">
        {band.min === -Infinity ? `< ${band.max}%` : band.max === Infinity ? `> ${band.min}%` : `${band.min}% – ${band.max}%`}
      </p>
    </div>
  );

  if (viewMode === "marketState") {
    const arrow = trendArrow(undefined);
    return (
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <div className="flex cursor-help flex-col items-center gap-1">
              <span className="text-[11px] font-medium text-foreground">{band.label}</span>
              <span className="inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-xs font-medium" style={{ backgroundColor: bg, color: darkBg ? "#fff" : "#000" }}>
                <span className="text-[10px]">{arrow}</span>
              </span>
            </div>
          </TooltipTrigger>
          <TooltipContent>
            {tooltipContent}
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
    );
  }

  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger asChild>
          <span
            className="inline-flex cursor-help items-center rounded px-1.5 py-0.5 text-xs font-medium"
            style={{ backgroundColor: bg, color: darkBg ? "#fff" : "#000" }}
          >
            <span className="tabular-nums">{value.toFixed(1)}%</span>
          </span>
        </TooltipTrigger>
        <TooltipContent>
          {tooltipContent}
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}

interface EntityRow {
  id: string;
  name: string;
  sector: string;
  industry: string;
  industrySubGroup: string;
}

interface DistanceRow {
  entity: EntityRow;
  values: Record<number, number>;
  trendByDMA?: Record<string, { score: number; classification: string }>;
}

export function DMADistanceTable({ summary, isLoading, period, viewMode, level, rows, onPeriodChange, onViewModeChange, onExport, onDrillDown }: DMADistanceTableProps) {
  if (isLoading || !summary) {
    return (
      <div className="rounded-md border border-border p-4">
        <div className="mb-3 h-5 w-48 animate-pulse rounded bg-muted" />
        <div className="h-48 w-full animate-pulse rounded bg-muted" />
      </div>
    );
  }

  const horizonData = summary?.breadthByHorizon?.[String(period)];

  let entities: EntityRow[] = [];
  if (level === "market") {
    entities = [{ id: "market", name: "Market", sector: "", industry: "", industrySubGroup: "" }];
  } else {
    entities = (rows ?? []).map((r: any) => ({
      id: String(r.id ?? r.name),
      name: r.name,
      sector: r.sector || "",
      industry: r.industry || "",
      industrySubGroup: r.industrySubGroup || "",
    }));
  }

  const rowsDist: DistanceRow[] = entities.map((entity, idx) => {
    const values: Record<number, number> = {};
    const trendByDMA: Record<string, { score: number; classification: string }> = {};
    for (const p of DMA_PERIODS) {
      const key = `dma${p}`;
      if (level === "market") {
        const entry = horizonData?.dmaDistance?.[key];
        values[p] = typeof entry?.distance === "number" ? entry.distance : 0;
      } else {
        const row = (rows ?? []).find((r: any) => r.name === entity.name);
        if (row) {
          const entry = row.horizons?.[String(period)]?.dmaDistance?.[key];
          values[p] = typeof entry?.distance === "number" ? entry.distance : 0;
          if (row.trendScoreByDMA && row.trendScoreByDMA[key]) {
            trendByDMA[key] = row.trendScoreByDMA[key];
          }
        } else {
          values[p] = 0;
        }
      }
    }
    return { entity, values, trendByDMA };
  });

  const viewLabel = "Median DMA Distance";

  const viewDescription =
    viewMode === "metrics" ? "Median price distance from DMA across selected entities." :
    "Current market state per DMA. Shows condition (label) and direction (arrow).";

  const handleExport = React.useCallback(() => {
    const header = ["Entity", ...DMA_PERIODS.map((p) => `${p} DMA`)];
    const lines = [header.join(",")];
    for (const row of rowsDist) {
      const cells = [
        `"${String(row.entity.name).replace(/"/g, '""')}"`,
        ...DMA_PERIODS.map((p) => (typeof row.values[p] === "number" ? row.values[p].toFixed(2) : "")),
      ];
      lines.push(cells.join(","));
    }
    const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `dma-distance-${period}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }, [rowsDist, period]);

  return (
    <div className="rounded-md border border-border p-4">
      <div className="mb-3 flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <div>
            <div className="text-sm font-medium text-foreground">{viewLabel}</div>
            <div className="text-[11px] text-muted-foreground">
              {viewMode === "metrics" && `Median price distance from DMA · ${HORIZON_LABELS[period]} snapshot`}
              {viewMode === "marketState" && `Current state + trend direction · ${HORIZON_LABELS[period]} snapshot`}
            </div>
          </div>
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="cursor-help text-muted-foreground">
                  <Info className="h-3.5 w-3.5" />
                </span>
              </TooltipTrigger>
              <TooltipContent className="max-w-xs">
                <p className="text-xs">{viewDescription}</p>
                <p className="mt-1 text-[11px] text-muted-foreground">
                  {viewMode === "metrics" && "Exact median distance percentages."}
                  {viewMode === "marketState" && "Arrow ↗ = improving, → = stable, ↘ = weakening."}
                </p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap items-center gap-2">
          {(["metrics", "marketState"] as const).map((mode) => (
            <button
              key={mode}
              type="button"
              onClick={() => onViewModeChange(mode)}
              className={`h-8 rounded-md border px-2.5 text-xs font-medium transition-colors select-none capitalize bg-transparent ${
                viewMode === mode ? "border-foreground text-foreground" : "border-border text-muted-foreground hover:bg-muted"
              }`}
            >
              {mode === "marketState" ? "Market State" : mode}
            </button>
          ))}
          {HORIZON_ORDER.map((h) => (
            <button
              key={h}
              type="button"
              onClick={() => onPeriodChange(h)}
              className={`h-8 rounded-md border px-2.5 text-xs font-medium transition-colors select-none bg-transparent ${
                period === h ? "border-foreground text-foreground" : "border-border text-muted-foreground hover:bg-muted"
              }`}
            >
              {HORIZON_LABELS[h]}
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={handleExport}
          className="rounded-md border border-border px-2 py-1 text-xs hover:bg-accent"
        >
          Export CSV
        </button>
      </div>
      </div>

      <div className="overflow-auto rounded-md border border-border" style={{ maxHeight: "calc(100vh - 320px)" }}>
        <table className="w-full text-sm border-separate border-spacing-0">
          <thead className="sticky top-0 z-30 bg-muted text-left text-xs uppercase text-muted-foreground">
            <tr>
              <th rowSpan={2} className="sticky left-0 z-40 bg-muted px-3 py-2 text-left">
                Entity
              </th>
              {DMA_PERIODS.map((p) => (
                <th key={p} className="px-3 py-2 text-center">
                  <TooltipProvider>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <span className="cursor-help border-b border-dashed border-muted-foreground/50">{p} DMA</span>
                      </TooltipTrigger>
                      <TooltipContent>
                        <p className="text-xs">{p}-day moving average distance</p>
                        <p className="text-[11px] text-muted-foreground">{(THRESHOLDS[p] || THRESHOLDS[50]).map(b => `${b.min === -Infinity ? '<' : b.max === Infinity ? '>' : b.min}% ${b.min === -Infinity ? '' : b.max === Infinity ? '' : '– ' + b.max + '%'} = ${b.label}`).join('<br/>')}</p>
                      </TooltipContent>
                    </Tooltip>
                  </TooltipProvider>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {viewMode === "marketState" && level === "market" ? (
              <tr className="border-t border-border">
                <td className="sticky left-0 z-10 bg-background px-3 py-2 text-left font-medium">Market State</td>
                {DMA_PERIODS.map((p) => {
                  const entry = horizonData?.dmaDistance?.[`dma${p}`];
                  const raw = typeof entry?.distance === "number" ? entry.distance : 0;
                  const trend = summary?.trendScoreByDMA?.[`dma${p}`];
                  return (
                    <td key={p} className="px-2 py-2 text-center">
                      <MarketStateCell value={raw} period={p} trend={trend} />
                    </td>
                  );
                })}
              </tr>
            ) : (
              rowsDist.map((row) => (
                <tr
                  key={row.entity.id}
                  className="border-t border-border hover:bg-accent/40"
                >
                  <td className="sticky left-0 z-10 bg-background px-3 py-2 text-left font-medium hover:bg-accent/40">
                    {level !== "market" && onDrillDown && level !== "company" ? (
                      <button type="button" onClick={() => onDrillDown(row.entity.name)} className="flex flex-col text-left hover:underline">
                        <span className="text-foreground">{row.entity.name}</span>
                        <span className="text-xs text-muted-foreground">
                          {[row.entity.sector, row.entity.industry, row.entity.industrySubGroup].filter(Boolean).join(" › ")}
                        </span>
                      </button>
                    ) : (
                      <span className="text-foreground">{row.entity.name}</span>
                    )}
                  </td>
                  {DMA_PERIODS.map((p) => {
                    const key = `dma${p}`;
                    if (viewMode === "marketState") {
                      const trend = row.trendByDMA?.[key];
                      return (
                        <td key={p} className="px-2 py-2 text-center">
                          <MarketStateCell value={row.values[p]} period={p} trend={trend} />
                        </td>
                      );
                    }
                    return (
                      <td key={p} className="px-2 py-2 text-center">
                        <CellContent value={row.values[p]} period={p} viewMode={viewMode} />
                      </td>
                    );
                  })}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
