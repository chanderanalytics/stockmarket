import * as React from "react";
import type { PriceTrendPeriod, PriceTrendSortMetric, PriceTrendSortDir } from "./PriceTrend.types";
import { formatPeriodLabel, sortPeriodsChronologically } from "./PriceTrend.utils";

interface PriceTrendTextTableProps {
  rows: Array<Record<string, unknown>>;
  periods: PriceTrendPeriod[];
  loading?: boolean;
  sortMetric?: PriceTrendSortMetric;
  sortDir?: PriceTrendSortDir;
  onSortChange?: (metric: PriceTrendSortMetric) => void;
  onSortDirToggle?: () => void;
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
export function PriceTrendTextTable({ rows, periods, loading, sortMetric, sortDir, onSortChange, onSortDirToggle }: PriceTrendTextTableProps) {
  const sortedPeriods = sortPeriodsChronologically(periods);

  const [localSortMetric, setLocalSortMetric] = React.useState<PriceTrendSortMetric>(sortMetric ?? "name");
  const [localSortDir, setLocalSortDir] = React.useState<PriceTrendSortDir>(sortDir ?? "asc");

  const metric = sortMetric ?? localSortMetric;
  const dir = sortDir ?? localSortDir;

  const handleSort = (col: PriceTrendSortMetric) => {
    if (metric === col) {
      if (onSortDirToggle) onSortDirToggle();
      else setLocalSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      if (onSortChange) onSortChange(col);
      else setLocalSortMetric(col);
    }
  };

  const sortedRows = React.useMemo(() => {
    const data = [...rows];
    data.sort((a, b) => {
      let aVal: number | string;
      let bVal: number | string;
      if (metric === "name") {
        aVal = String(a.name ?? "");
        bVal = String(b.name ?? "");
      } else if (metric === "marketCap") {
        aVal = (a.marketCap as number) ?? 0;
        bVal = (b.marketCap as number) ?? 0;
      } else if (metric === "count") {
        aVal = (a.companyCount as number) ?? 0;
        bVal = (b.companyCount as number) ?? 0;
      } else {
        const period = metric as PriceTrendPeriod;
        const aV = a[period];
        const bV = b[period];
        aVal = typeof aV === "number" ? aV : 0;
        bVal = typeof bV === "number" ? bV : 0;
      }
      if (typeof aVal === "number" && typeof bVal === "number") {
        return dir === "asc" ? aVal - bVal : bVal - aVal;
      }
      const aStr = String(aVal).toLowerCase();
      const bStr = String(bVal).toLowerCase();
      return dir === "asc" ? aStr.localeCompare(bStr) : bStr.localeCompare(aStr);
    });
    return data;
  }, [rows, metric, dir]);

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
            <th className="border-b border-border px-3 py-2 font-medium">
              <button type="button" onClick={() => handleSort("name")} className="hover:underline">
                Company {metric === "name" ? (dir === "asc" ? "▲" : "▼") : "⇅"}
              </button>
            </th>
            <th className="border-b border-border px-3 py-2 font-medium">
              <button type="button" onClick={() => handleSort("count")} className="hover:underline">
                Count {metric === "count" ? (dir === "asc" ? "▲" : "▼") : "⇅"}
              </button>
            </th>
            <th className="border-b border-border px-3 py-2 font-medium">
              <button type="button" onClick={() => handleSort("sector")} className="hover:underline">
                Sector {metric === "sector" ? (dir === "asc" ? "▲" : "▼") : "⇅"}
              </button>
            </th>
            <th className="border-b border-border px-3 py-2 font-medium">
              <button type="button" onClick={() => handleSort("marketCap")} className="hover:underline">
                Mkt Cap {metric === "marketCap" ? (dir === "asc" ? "▲" : "▼") : "⇅"}
              </button>
            </th>
            {sortedPeriods.map((p) => (
              <th key={p} className="border-b border-border px-3 py-2 font-medium">
                <button type="button" onClick={() => handleSort(p)} className="hover:underline">
                  {formatPeriodLabel(p)} {metric === p ? (dir === "asc" ? "▲" : "▼") : "⇅"}
                </button>
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
