import * as React from "react";
import type { BreadthResponse, BreadthRow } from "./types";

interface SectorStrengthTableProps {
  data?: BreadthResponse;
  isLoading: boolean;
  dmaPeriods: number[];
}

export function SectorStrengthTable({ data, isLoading, dmaPeriods }: SectorStrengthTableProps) {
  if (isLoading) {
    return (
      <div className="rounded-md border border-border">
        <div className="border-b border-border px-4 py-3">
          <div className="h-4 w-40 animate-pulse rounded bg-muted" />
        </div>
        <div className="divide-y divide-border">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="flex items-center gap-4 px-4 py-3">
              <div className="h-4 w-32 animate-pulse rounded bg-muted" />
              <div className="h-4 w-16 animate-pulse rounded bg-muted" />
              <div className="h-4 w-24 animate-pulse rounded bg-muted" />
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (!data || !data.rows?.length) {
    return (
      <div className="rounded-md border border-border px-4 py-6 text-sm text-muted-foreground">
        No sector breadth data available.
      </div>
    );
  }

  return (
    <div className="rounded-md border border-border">
      <div className="border-b border-border px-4 py-3">
        <h3 className="text-sm font-semibold">Sector Strength</h3>
        <p className="text-xs text-muted-foreground">
          Breadth score and participation by sector
        </p>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-left text-xs">
          <thead>
            <tr className="border-b border-border">
              <th className="px-4 py-2 text-left font-medium text-muted-foreground">Name</th>
              <th className="px-4 py-2 text-left font-medium text-muted-foreground ">Companies</th>
              <th className="px-4 py-2 text-left font-medium text-muted-foreground ">Breadth</th>
              <th className="px-4 py-2 text-left font-medium text-muted-foreground ">Trend</th>
              <th className="px-4 py-2 text-left font-medium text-muted-foreground ">A/D</th>
              <th className="px-4 py-2 text-left font-medium text-muted-foreground ">New High %</th>
              <th className="px-4 py-2 text-left font-medium text-muted-foreground ">New Low %</th>
              <th className="px-4 py-2 text-left font-medium text-muted-foreground ">Relative Volume</th>
              <th className="px-4 py-2 text-left font-medium text-muted-foreground ">Weighted Return</th>
              {dmaPeriods.map((p) => (
                <th key={p} className="px-4 py-2 text-left font-medium text-muted-foreground ">{p} DMA</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {data.rows.map((row: BreadthRow) => (
              <tr key={row.id} className="hover:bg-accent">
                <td className="px-4 py-2 text-left font-medium">{row.name || "—"}</td>
                <td className="px-4 py-2 text-left ">{row.companyCount.toLocaleString()}</td>
                <td className="px-4 py-2 text-left ">
                  {(() => {
                    const v = row.breadthScore ?? 0;
                    const color = v < 20 ? "#991b1b" : v < 40 ? "#ef4444" : v < 60 ? "#f59e0b" : v < 80 ? "#4ade80" : "#15803d";
                    return (
                      <span className="font-medium" style={{ color }}>
                        {v.toFixed(1)}%
                      </span>
                    );
                  })()}
                </td>
                <td className="px-4 py-2 text-left ">{(row.trendStrength ?? 0).toFixed(1)}</td>
                <td className="px-4 py-2 text-left ">{(row.advanceDeclineRatio ?? 0).toFixed(2)}</td>
                <td className="px-4 py-2 text-left  text-emerald-600">{(row.newHighPct ?? 0).toFixed(1)}%</td>
                <td className="px-4 py-2 text-left  text-red-600">{(row.newLowPct ?? 0).toFixed(1)}%</td>
                <td className="px-4 py-2 text-left ">{(row.relativeVolume ?? 0).toFixed(2)}x</td>
                <td className="px-4 py-2 text-left ">{(row.weightedReturn ?? 0).toFixed(2)}%</td>
                {dmaPeriods.map((p) => {
                  const key = `aboveDMA${p}`;
                  const val = row[key] as { count?: number; percentage?: number } | undefined;
                  return (
                    <td key={p} className="px-4 py-2 text-left ">
                      {val ? `${val.percentage?.toFixed(1) ?? 0}%` : "—"}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="border-t border-border px-4 py-2 text-xs text-muted-foreground">
        Showing {data.rows.length} of {data.total.toLocaleString()} rows
      </div>
    </div>
  );
}
