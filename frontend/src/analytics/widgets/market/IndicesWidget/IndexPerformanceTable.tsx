"use client";
import * as React from "react";
import { ArrowUpDown, ArrowUp, ArrowDown } from "lucide-react";
import type { IndexFeatureRow } from "./types";
import { RETURN_PERIODS, type ReturnSortKey, type SortKey, type SortDir } from "./types";

const TH_CLASS = "px-3 py-2 text-left text-[11px] font-medium uppercase tracking-wide text-muted-foreground";

interface IndexPerformanceTableProps {
  rows: IndexFeatureRow[];
  sortKey: SortKey;
  sortDir: SortDir;
  onSortChange: (key: SortKey) => void;
  onSortDirToggle: () => void;
  periods?: ReturnSortKey[];
  onRowClick?: (name: string, ticker: string) => void;
}

const formatReturn = (v: number | null) => {
  if (v === null || v === undefined) return "—";
  const sign = v > 0 ? "+" : "";
  return `${sign}${v.toFixed(1)}%`;
};

const getReturnColor = (v: number | null) => {
  if (v === null || v === undefined) return "text-muted-foreground";
  if (v > 0) return "text-emerald-600 dark:text-emerald-400";
  if (v < 0) return "text-red-600 dark:text-red-400";
  return "text-muted-foreground";
};

export function IndexPerformanceTable({
  rows,
  sortKey,
  sortDir,
  onSortChange,
  onSortDirToggle,
  periods = RETURN_PERIODS.map((p) => p.key),
  onRowClick,
}: IndexPerformanceTableProps) {
  const handleHeaderClick = (key: SortKey) => {
    if (key === sortKey) {
      onSortDirToggle();
    } else {
      onSortChange(key);
    }
  };

  const SortIcon = ({ colKey }: { colKey: SortKey }) => {
    if (colKey !== sortKey) {
      return <ArrowUpDown className="ml-1 h-3 w-3 opacity-40" />;
    }
    return sortDir === "asc" ? (
      <ArrowUp className="ml-1 h-3 w-3" />
    ) : (
      <ArrowDown className="ml-1 h-3 w-3" />
    );
  };

  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[900px] table-auto border-collapse border border-border text-sm">
        <thead>
          <tr className="border-b border-border bg-muted/50">
            <th className={`${TH_CLASS} w-12`}>#</th>
            <th className={`${TH_CLASS} cursor-pointer select-none`} onClick={() => handleHeaderClick("name")}>
              Name <SortIcon colKey="name" />
            </th>
            <th className={`${TH_CLASS} cursor-pointer select-none`} onClick={() => handleHeaderClick("ticker")}>
              Ticker <SortIcon colKey="ticker" />
            </th>
            <th className={`${TH_CLASS} cursor-pointer select-none`} onClick={() => handleHeaderClick("region")}>
              Region <SortIcon colKey="region" />
            </th>
            <th className={`${TH_CLASS} cursor-pointer select-none`} onClick={() => handleHeaderClick("close")}>
              Price <SortIcon colKey="close" />
            </th>
            {periods.map((p) => (
              <th
                key={p}
                className={`${TH_CLASS} cursor-pointer select-none`}
                onClick={() => handleHeaderClick(p)}
              >
                {RETURN_PERIODS.find((x) => x.key === p)?.label ?? p} <SortIcon colKey={p} />
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, idx) => (
            <tr
              key={row.ticker}
              className="border-b border-border last:border-b-0 hover:bg-accent/50"
              onClick={() => onRowClick?.(row.name, row.ticker)}
            >
              <td className="px-3 py-2 text-xs text-muted-foreground">{idx + 1}</td>
              <td className="px-3 py-2 font-medium">{row.name}</td>
              <td className="px-3 py-2 text-xs text-muted-foreground">{row.ticker}</td>
              <td className="px-3 py-2 text-xs">{row.region}</td>
              <td className="px-3 py-2 font-mono">{row.close != null ? row.close.toFixed(1) : "—"}</td>
              {periods.map((p) => (
                <td
                  key={p}
                  className={`px-3 py-2 font-mono ${getReturnColor(row[p])}`}
                >
                  {formatReturn(row[p])}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
