import * as React from "react";
import type { PriceTrendV2Period } from "./PriceTrendV2.types";
import { formatPeriodLabel, sortPeriodsChronologically } from "./PriceTrendV2.utils";

interface PriceTrendV2TextTableProps {
  rows: Array<Record<string, unknown>>;
  periods: PriceTrendV2Period[];
  loading?: boolean;
}

function formatValue(value: unknown): string {
  if (value === null || value === undefined) return "—";
  if (value === 9999 || value === "9999") return "—";
  const num = typeof value === "number" ? value : Number(value);
  if (Number.isNaN(num)) return "—";
  const sign = num >= 0 ? "+" : "";
  return `${sign}${num.toFixed(2)}%`;
}

function valueColor(value: unknown): string {
  if (value === null || value === undefined) return "text-muted-foreground";
  if (value === 9999 || value === "9999") return "text-muted-foreground";
  const num = typeof value === "number" ? value : Number(value);
  if (Number.isNaN(num)) return "text-muted-foreground";
  return num >= 0 ? "text-emerald-600" : "text-red-500";
}

/** Plain textual table (legacy "table" view). The canonical grid view uses PriceTrendTable. */
export function PriceTrendV2TextTable({ rows, periods, loading }: PriceTrendV2TextTableProps) {
  const sortedPeriods = sortPeriodsChronologically(periods);

  if (loading) {
    return (
      <div className="flex h-40 items-center justify-center text-sm text-muted-foreground">
        Loading…
      </div>
    );
  }

  if (!rows.length) {
    return (
      <div className="flex h-40 items-center justify-center text-sm text-muted-foreground">
        No companies found. Try adjusting filters.
      </div>
    );
  }

  return (
    <div className="overflow-auto rounded-md border border-border" style={{ maxHeight: "calc(100vh - 280px)" }}>
      <table className="w-full border-collapse text-xs">
        <thead className="sticky top-0 bg-muted/50">
          <tr className="text-left">
            <th className="border-b border-border px-3 py-2 font-medium">Company</th>
            <th className="border-b border-border px-3 py-2 font-medium">Count</th>
            <th className="border-b border-border px-3 py-2 font-medium">Sector</th>
            <th className="border-b border-border px-3 py-2 font-medium">Mkt Cap</th>
            {sortedPeriods.map((p) => (
              <th key={p} className="border-b border-border px-3 py-2 font-medium">
                {formatPeriodLabel(p)}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, idx) => (
            <tr key={String(row.id ?? idx)} className="hover:bg-accent/40">
              <td className="border-b border-border px-3 py-1.5 font-medium">{String(row.name ?? "")}</td>
              <td className="border-b border-border px-3 py-1.5 tabular-nums text-muted-foreground">
                {typeof row.companyCount === "number" ? row.companyCount.toLocaleString() : "—"}
              </td>
              <td className="border-b border-border px-3 py-1.5 text-muted-foreground">{String(row.sector ?? "")}</td>
              <td className="border-b border-border px-3 py-1.5  tabular-nums">
                {typeof row.marketCap === "number" ? row.marketCap.toFixed(0) : "—"}
              </td>
              {sortedPeriods.map((p) => (
                <td
                  key={p}
                  className={`border-b border-border px-3 py-1.5  tabular-nums ${valueColor(row[p])}`}
                >
                  {formatValue(row[p])}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
