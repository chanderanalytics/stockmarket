"use client";

import * as React from "react";
import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { performanceService } from "@/shared/api/services/performance";
import type { PerformanceSummary } from "./types";

const SUMMARY_ITEMS: { label: string; key: keyof PerformanceSummary; format?: (v: number) => string }[] = [
  { label: "Companies", key: "total_companies", format: (v) => String(Math.round(v)) },
  { label: "Trades", key: "total_trades", format: (v) => String(Math.round(v)) },
  { label: "Win Rate", key: "win_rate", format: (v) => `${v.toFixed(1)}%` },
  { label: "Profit Factor", key: "profit_factor", format: (v) => v.toFixed(2) },
  { label: "Avg Return", key: "avg_pnl", format: (v) => `${v.toFixed(2)}%` },
  { label: "Sharpe Ratio", key: "avg_sharpe", format: (v) => v.toFixed(2) },
  { label: "Max Drawdown", key: "avg_max_drawdown", format: (v) => `${v.toFixed(2)}%` },
];

export function PerformanceSummary() {
  const summaryQuery = useApiQuery(
    queryKeys.performance.summary(),
    () => performanceService.summary(),
  );

  if (summaryQuery.isLoading) {
    return (
      <div className="rounded-md border border-border p-4">
        <div className="mb-3 text-sm font-medium text-foreground">Strategy Summary</div>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="h-16 animate-pulse rounded-md border border-border bg-muted/50" />
          ))}
        </div>
      </div>
    );
  }

  if (!summaryQuery.data) {
    return (
      <div className="rounded-md border border-border p-4">
        <div className="mb-3 text-sm font-medium text-foreground">Strategy Summary</div>
        <div className="text-sm text-muted-foreground">No summary data available.</div>
      </div>
    );
  }

  const data = summaryQuery.data;

  return (
    <div className="rounded-md border border-border p-4">
      <div className="mb-3 text-sm font-medium text-foreground">Strategy Summary</div>
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-8">
        {SUMMARY_ITEMS.map((item) => {
          const raw = data[item.key];
          const value = typeof raw === "number" ? item.format?.(raw) ?? String(raw) : "—";
          return (
            <div key={item.key} className="rounded-md border border-border p-2">
              <div className="text-[11px] text-muted-foreground">{item.label}</div>
              <div className="text-sm font-medium tabular-nums">{value}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
