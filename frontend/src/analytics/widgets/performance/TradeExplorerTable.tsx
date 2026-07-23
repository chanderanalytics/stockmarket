"use client";

import * as React from "react";
import { ArrowUpDown, ArrowUp, ArrowDown } from "lucide-react";
import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { performanceService } from "@/shared/api/services/performance";
import type { TradePerformance } from "./types";

const TH_CLASS = "px-3 py-2 text-left text-[11px] font-medium uppercase tracking-wide text-muted-foreground";

interface TradeExplorerTableProps {
  rows: TradePerformance[];
  loading: boolean;
  total: number;
  page: number;
  pageSize: number;
  sort: { key: string; dir: "asc" | "desc" };
  selectedCompanyId: number | null;
  onSortChange: (key: string, dir: "asc" | "desc") => void;
  onPageChange: (page: number) => void;
  onRowSelect: (tradeId: string) => void;
}

const formatDate = (d: string | null | undefined) => {
  if (!d) return "—";
  try {
    return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
  } catch {
    return d;
  }
};

const formatPrice = (v: number | null | undefined) => {
  if (v === undefined || v === null || Number.isNaN(v)) return "—";
  return v.toFixed(2);
};

const formatPercent = (v: number | undefined | null) => {
  if (v === undefined || v === null || Number.isNaN(v)) return "—";
  const sign = v > 0 ? "+" : "";
  return `${sign}${v.toFixed(2)}%`;
};

const STATUS_COLORS: Record<string, string> = {
  WIN: "text-emerald-600 dark:text-emerald-400",
  LOSS: "text-red-600 dark:text-red-400",
  OPEN: "text-amber-600 dark:text-amber-400",
};

export function TradeExplorerTable({
  rows,
  loading,
  total,
  page,
  pageSize,
  sort,
  selectedCompanyId,
  onSortChange,
  onPageChange,
  onRowSelect,
}: TradeExplorerTableProps) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  const handleHeaderClick = (key: string) => {
    if (sort.key === key) {
      onSortChange(key, sort.dir === "asc" ? "desc" : "asc");
    } else {
      onSortChange(key, "desc");
    }
  };

  const SortIcon = ({ colKey }: { colKey: string }) => {
    if (colKey !== sort.key) {
      return <ArrowUpDown className="ml-1 h-3 w-3 opacity-40" />;
    }
    return sort.dir === "asc" ? (
      <ArrowUp className="ml-1 h-3 w-3" />
    ) : (
      <ArrowDown className="ml-1 h-3 w-3" />
    );
  };

  const tradeId = (row: TradePerformance) =>
    `${row.company_id}-${row.entry_date}-${row.entry_price}`;

  return (
    <div className="flex h-full flex-col rounded-md border border-border">
      <div className="flex items-center justify-between border-b border-border px-4 py-3">
        <div>
          <div className="text-sm font-semibold">Trade Explorer</div>
          <div className="text-xs text-muted-foreground">
            {selectedCompanyId
              ? `Showing trades for selected company · ${total} trades`
              : "Select a company from the table above to view its trades"}
          </div>
        </div>
      </div>
      <div className="flex-1 overflow-auto">
        <table className="w-full min-w-[1000px] table-auto border-collapse border border-border text-sm">
          <thead>
            <tr className="border-b border-border bg-muted/50">
              <th className={`${TH_CLASS} cursor-pointer select-none`} onClick={() => handleHeaderClick("entry_date")}>
                Entry Date <SortIcon colKey="entry_date" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("entry_price")}>
                Entry Price <SortIcon colKey="entry_price" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("exit_date")}>
                Exit Date <SortIcon colKey="exit_date" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("exit_price")}>
                Exit Price <SortIcon colKey="exit_price" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("pnl_pct")}>
                P&L % <SortIcon colKey="pnl_pct" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("days_held")}>
                Days Held <SortIcon colKey="days_held" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-center`} onClick={() => handleHeaderClick("status")}>
                Status <SortIcon colKey="status" />
              </th>
              <th className={`${TH_CLASS} text-right`}>Entry Summary</th>
              <th className={`${TH_CLASS} text-right`}>Exit Summary</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => {
              const id = tradeId(row);
              const statusColor = STATUS_COLORS[row.status] ?? "text-muted-foreground";
              return (
                <tr
                  key={id}
                  className="border-b border-border last:border-b-0 hover:bg-accent/30"
                  onClick={() => onRowSelect(id)}
                >
                  <td className="px-3 py-2 whitespace-nowrap">{formatDate(row.entry_date)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatPrice(row.entry_price)}</td>
                  <td className="px-3 py-2 text-right tabular-nums whitespace-nowrap">{formatDate(row.exit_date)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatPrice(row.exit_price)}</td>
                  <td className={`px-3 py-2 text-right tabular-nums ${row.pnl_pct >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-red-600 dark:text-red-400"}`}>
                    {formatPercent(row.pnl_pct)}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">{row.days_held ?? "—"}</td>
                  <td className={`px-3 py-2 text-center text-xs font-medium ${statusColor}`}>
                    {row.status}
                  </td>
                  <td className="px-3 py-2 text-xs text-muted-foreground">
                    {row.entry_status ? (
                      <span className="block max-w-[200px] truncate" title={row.entry_status}>
                        {row.entry_status}
                      </span>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="px-3 py-2 text-xs text-muted-foreground">
                    {row.exit_status ? (
                      <span className="block max-w-[200px] truncate" title={row.exit_status}>
                        {row.exit_status}
                      </span>
                    ) : (
                      "—"
                    )}
                  </td>
                </tr>
              );
            })}
            {!loading && rows.length === 0 && (
              <tr>
                <td colSpan={9} className="px-3 py-8 text-center text-sm text-muted-foreground">
                  {selectedCompanyId ? "No trades found for this company" : "Select a company to view trades"}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      {selectedCompanyId && (
        <div className="flex items-center justify-between border-t border-border px-4 py-2">
          <div className="text-xs text-muted-foreground">
            Page {page + 1} of {totalPages}
          </div>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => onPageChange(Math.max(0, page - 1))}
              disabled={page === 0}
              className="rounded-md border border-border px-2 py-1 text-xs disabled:opacity-50 hover:bg-accent"
            >
              Previous
            </button>
            <button
              type="button"
              onClick={() => onPageChange(Math.min(totalPages - 1, page + 1))}
              disabled={page >= totalPages - 1}
              className="rounded-md border border-border px-2 py-1 text-xs disabled:opacity-50 hover:bg-accent"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
