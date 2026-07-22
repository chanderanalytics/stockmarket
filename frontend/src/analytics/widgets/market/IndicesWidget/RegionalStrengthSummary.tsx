import * as React from "react";
import type { RegionalRow } from "./types";

interface RegionalStrengthSummaryProps {
  rows: RegionalRow[];
  period: string;
  loading?: boolean;
}

function strengthColor(v: number | null) {
  if (v === null || v === undefined) return "bg-muted";
  if (v > 0) return "bg-emerald-500";
  if (v < 0) return "bg-red-500";
  return "bg-muted";
}

export function RegionalStrengthSummary({ rows, period, loading }: RegionalStrengthSummaryProps) {
  if (loading) {
    return (
      <div className="flex h-32 items-center justify-center text-sm text-muted-foreground">
        Loading regional strength...
      </div>
    );
  }

  const maxAbs = Math.max(...rows.map((r) => Math.abs(r.avg_return ?? 0)), 1);

  return (
    <div className="flex flex-col gap-3">
      <div className="text-xs text-muted-foreground">
        Average return by region ({period})
      </div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {rows.map((r) => (
          <div key={r.region} className="rounded-md border border-border p-3">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">{r.region}</span>
              <span className="text-xs text-muted-foreground">{r.index_count} indices</span>
            </div>
            <div className="mt-2 h-2 w-full rounded-full bg-muted">
              <div
                className={`h-2 rounded-full ${strengthColor(r.avg_return)}`}
                style={{
                  width: `${Math.max(4, (Math.abs(r.avg_return ?? 0) / maxAbs) * 100)}%`,
                  marginLeft: r.avg_return && r.avg_return < 0 ? "auto" : "0",
                }}
              />
            </div>
            <div className="mt-1 text-right text-sm font-mono">
              {r.avg_return !== null && r.avg_return !== undefined
                ? `${r.avg_return > 0 ? "+" : ""}${r.avg_return.toFixed(2)}%`
                : "—"}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
