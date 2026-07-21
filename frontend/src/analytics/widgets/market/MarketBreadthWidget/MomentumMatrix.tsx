"use client";

import * as React from "react";
import { ScatterChart, Scatter, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ZAxis, Label, ReferenceLine, Cell } from "recharts";
import type { BreadthRow, BreadthSignalType } from "./types";
import { SIGNAL_TYPE_LABELS } from "./types";

interface MomentumMatrixProps {
  rows: BreadthRow[];
  isLoading: boolean;
  signalType?: BreadthSignalType;
  onEntityClick?: (name: string) => void;
}

const QUADRANT_COLORS: Record<string, string> = {
  topRight: "#10b981",
  topLeft: "#f59e0b",
  bottomRight: "#3b82f6",
  bottomLeft: "#ef4444",
};

function median(values: number[]): number {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

function quadrant(row: BreadthRow, breadthMid: number, returnMid: number) {
  const breadth = row.breadthScore ?? 0;
  const ret = row.weightedReturn ?? 0;
  if (breadth >= breadthMid && ret >= returnMid) return "topRight";
  if (breadth >= breadthMid && ret < returnMid) return "topLeft";
  if (breadth < breadthMid && ret >= returnMid) return "bottomRight";
  return "bottomLeft";
}

const QUADRANT_LABELS: Record<string, string> = {
  topRight: "Strong Leaders",
  topLeft: "Broad Participation",
  bottomRight: "Early Breakouts",
  bottomLeft: "Weak Market",
};

type SortColumn = "name" | "breadthScore" | "weightedReturn" | "marketCap" | "relativeVolume" | "quadrant" | "companyCount";
type SortDir = "asc" | "desc";

function formatMarketCap(v: number): string {
  if (v >= 100_000) return `₹${(v / 100_000).toFixed(1)}L cr`;
  if (v >= 1) return `₹${v.toFixed(1)} cr`;
  return `₹${(v * 100).toFixed(1)} L`;
}

const TOOLTIP_COPY: Record<string, string> = {
  breadthScore: "% of stocks above the selected signal DMA",
  weightedReturn: "Market-cap-weighted 252-day return (%) across the group",
  marketCap: "Total market capitalisation of the group (crores of rupees)",
  relativeVolume: "Today's volume vs 1-year average volume",
};

export function MomentumMatrix({ rows, isLoading, signalType, onEntityClick }: MomentumMatrixProps) {
  const signalLabel = signalType ? (SIGNAL_TYPE_LABELS[signalType] ?? "Signal") : "Signal";
  const [view, setView] = React.useState<"chart" | "table">("chart");
  const [sortColumn, setSortColumn] = React.useState<SortColumn>("breadthScore");
  const [sortDir, setSortDir] = React.useState<SortDir>("desc");

  const handleSort = React.useCallback((col: SortColumn) => {
    if (sortColumn === col) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortColumn(col);
      setSortDir("desc");
    }
  }, [sortColumn]);

  const breadthMid = React.useMemo(() => median(rows.map((r) => r.breadthScore ?? 0)), [rows]);
  const returnMid = React.useMemo(() => median(rows.map((r) => r.weightedReturn ?? 0)), [rows]);

  const data = React.useMemo(() => {
    const base = rows.map((r) => ({
      name: r.name,
      breadthScore: r.breadthScore ?? 0,
      weightedReturn: r.weightedReturn ?? 0,
      marketCap: r.marketCap ?? 0,
      relativeVolume: r.relativeVolume ?? 0,
      quadrant: quadrant(r, breadthMid, returnMid),
      sector: r.sector || "",
      industry: r.industry || "",
      industrySubGroup: r.industrySubGroup || "",
      companyCount: typeof r.companyCount === "number" ? r.companyCount : null,
    }));

    return base.sort((a, b) => {
      const aVal = a[sortColumn];
      const bVal = b[sortColumn];
      if (typeof aVal === "number" && typeof bVal === "number") {
        return sortDir === "asc" ? aVal - bVal : bVal - aVal;
      }
      const aStr = String(aVal).toLowerCase();
      const bStr = String(bVal).toLowerCase();
        return sortDir === "asc" ? aStr.localeCompare(bStr) : bStr.localeCompare(aStr);
    });
  }, [rows, sortColumn, sortDir]);

  const xMin = Math.min(...data.map((d) => d.weightedReturn));
  const xMax = Math.max(...data.map((d) => d.weightedReturn));
  const yMin = Math.min(...data.map((d) => d.breadthScore));
  const yMax = Math.max(...data.map((d) => d.breadthScore));
  const xPad = (xMax - xMin) * 0.15 || 10;
  const yPad = (yMax - yMin) * 0.15 || 5;

  const SortIndicator = ({ col }: { col: SortColumn }) => {
    if (sortColumn !== col) return <span className="ml-1 text-[10px] text-muted-foreground">⇅</span>;
    return <span className="ml-1 text-[10px]">{sortDir === "asc" ? "↑" : "↓"}</span>;
  };

  if (isLoading) {
    return (
      <div className="rounded-md border border-border p-4">
        <div className="h-6 w-40 animate-pulse rounded bg-muted" />
        <div className="mt-4 h-80 w-full animate-pulse rounded bg-muted" />
      </div>
    );
  }

  if (!rows.length) return null;

  return (
    <div className="rounded-md border border-border p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <div className="text-sm font-medium text-foreground">Momentum Matrix</div>
          <div className="text-[11px] text-muted-foreground">Weighted return = 252-day market-cap-weighted return</div>
        </div>
        <div className="flex rounded-md border border-border overflow-hidden">
          <button
            type="button"
            onClick={() => setView("chart")}
            className={`px-3 py-1 text-xs ${view === "chart" ? "bg-accent text-accent-foreground" : "hover:bg-accent/50"}`}
          >
            Chart
          </button>
          <button
            type="button"
            onClick={() => setView("table")}
            className={`px-3 py-1 text-xs ${view === "table" ? "bg-accent text-accent-foreground" : "hover:bg-accent/50"}`}
          >
            Table
          </button>
        </div>
      </div>

      {view === "chart" ? (
        <div className="mt-3 h-[420px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <ScatterChart margin={{ top: 10, right: 20, bottom: 50, left: 10 }}>
              <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
              <XAxis
                type="number"
                dataKey="weightedReturn"
                name="Weighted Return"
                unit="%"
                domain={[xMin - xPad, xMax + xPad]}
                tick={{ fontSize: 12 }}
                tickFormatter={(v: number) => v.toFixed(1)}
                label={{ value: "Weighted Return (%)", position: "insideBottom", offset: -35, fontSize: 12 }}
              >
                <Label value="Weighted Return (%)" offset={-35} position="insideBottom" fontSize={12} />
              </XAxis>
              <YAxis
                type="number"
                dataKey="breadthScore"
                name={signalLabel}
                domain={[Math.max(0, yMin - yPad), Math.min(100, yMax + yPad)]}
                tick={{ fontSize: 12 }}
                tickFormatter={(v: number) => v.toFixed(1)}
                label={{ value: signalLabel, angle: -90, position: "insideLeft", offset: -10, fontSize: 12 }}
              >
                <Label value={signalLabel} angle={-90} position="insideLeft" offset={-10} fontSize={12} />
              </YAxis>
              <ReferenceLine y={Number(breadthMid.toFixed(1))} stroke="var(--border)" strokeDasharray="4 4" />
              <ReferenceLine x={Number(returnMid.toFixed(1))} stroke="var(--border)" strokeDasharray="4 4" />
              <ZAxis type="number" dataKey="marketCap" range={[60, 600]} name="Market Cap" />
              <Tooltip
                formatter={(value: unknown, name: string) => {
                  if (name === "Weighted Return") return [`${Number(value).toFixed(2)}%`, name];
                  if (name === "Market Cap") return [formatMarketCap(Number(value)), name];
                  if (name === "Relative Volume") return [`${Number(value).toFixed(2)}x`, name];
                  return [Number(value).toFixed(1), name];
                }}
                labelFormatter={(label) => label as string}
              />
              <Scatter data={data}>
                {data.map((entry, idx) => (
                  <Cell key={idx} fill={QUADRANT_COLORS[entry.quadrant]} fillOpacity={0.8} stroke="white" strokeWidth={1} />
                ))}
              </Scatter>
            </ScatterChart>
          </ResponsiveContainer>
        </div>
      ) : (
        <div className="mt-3 overflow-auto rounded-md border border-border" style={{ maxHeight: "calc(100vh - 320px)" }}>
          <table className="w-full text-sm border-separate border-spacing-0">
            <thead className="sticky top-0 z-30 bg-muted text-left text-xs uppercase text-muted-foreground">
              <tr>
                <th rowSpan={2} className="sticky left-0 z-40 px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort("name")} className="hover:underline">
                    Entity <SortIndicator col="name" />
                  </button>
                </th>
                <th className="px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort("companyCount")} className="hover:underline">
                    Count <SortIndicator col="companyCount" />
                  </button>
                </th>
                <th className="px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort("quadrant")} className="hover:underline">
                    Quadrant <SortIndicator col="quadrant" />
                  </button>
                </th>
                <th className="px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort("breadthScore")} className="hover:underline" title={TOOLTIP_COPY.breadthScore}>
                    {signalLabel} <SortIndicator col="breadthScore" />
                  </button>
                </th>
                <th className="px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort("weightedReturn")} className="hover:underline" title={TOOLTIP_COPY.weightedReturn}>
                    Weighted Return <SortIndicator col="weightedReturn" />
                  </button>
                </th>
                <th className="px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort("marketCap")} className="hover:underline" title={TOOLTIP_COPY.marketCap}>
                    Market Cap <SortIndicator col="marketCap" />
                  </button>
                </th>
                <th className="px-3 py-2 text-left">
                  <button type="button" onClick={() => handleSort("relativeVolume")} className="hover:underline" title={TOOLTIP_COPY.relativeVolume}>
                    Relative Volume <SortIndicator col="relativeVolume" />
                  </button>
                </th>
              </tr>
            </thead>
            <tbody>
              {data.map((row) => (
                <tr key={row.name} className="border-t border-border hover:bg-accent/40">
                  <td className="sticky left-0 z-10 px-3 py-2">
                    <button
                      type="button"
                      onClick={() => onEntityClick?.(row.name)}
                      className="flex flex-col text-left hover:underline disabled:opacity-50"
                      disabled={!onEntityClick}
                    >
                      <span className="font-medium text-foreground">{row.name}</span>
                      <span className="text-xs text-muted-foreground">
                        {[row.sector, row.industry, row.industrySubGroup].filter(Boolean).join(" › ") || "—"}
                      </span>
                    </button>
                  </td>
                  <td className="px-3 py-2 text-left tabular-nums">{typeof row.companyCount === "number" ? row.companyCount.toLocaleString() : "—"}</td>
                  <td className="px-3 py-2 text-left">
                    <span className="flex items-center gap-1.5">
                      <span className="h-2 w-2 rounded-full" style={{ backgroundColor: QUADRANT_COLORS[row.quadrant] }} />
                      <span>{QUADRANT_LABELS[row.quadrant]}</span>
                    </span>
                  </td>
                  <td className="px-3 py-2 text-left tabular-nums">{row.breadthScore.toFixed(1)}</td>
                  <td className="px-3 py-2 text-left tabular-nums">{row.weightedReturn.toFixed(2)}%</td>
                  <td className="px-3 py-2 text-left tabular-nums">{formatMarketCap(row.marketCap)}</td>
                  <td className="px-3 py-2 text-left tabular-nums">{row.relativeVolume.toFixed(2)}x</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="mt-3 flex flex-wrap gap-3 text-xs">
        {Object.entries(QUADRANT_LABELS).map(([key, label]) => (
          <span key={key} className="flex items-center gap-1">
            <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: QUADRANT_COLORS[key] }} />
            <span className="text-muted-foreground">{label}</span>
          </span>
        ))}
      </div>
    </div>
  );
}
