"use client";

import * as React from "react";
import { ArrowUpDown, ArrowUp, ArrowDown } from "lucide-react";
import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { performanceService } from "@/shared/api/services/performance";
import type { CompanyPerformance } from "./types";

const TH_CLASS = "px-3 py-2 text-left text-[11px] font-medium uppercase tracking-wide text-muted-foreground";

interface CompanyPerformanceTableProps {
  rows: CompanyPerformance[];
  loading: boolean;
  total: number;
  page: number;
  pageSize: number;
  sort: { key: string; dir: "asc" | "desc" };
  selectedCompanyId: number | null;
  onSortChange: (key: string, dir: "asc" | "desc") => void;
  onPageChange: (page: number) => void;
  onRowSelect: (companyId: number | null) => void;
}

const formatPercent = (v: number | undefined | null) => {
  if (v === undefined || v === null || Number.isNaN(v)) return "—";
  const sign = v > 0 ? "+" : "";
  return `${sign}${v.toFixed(1)}%`;
};

const formatNumber = (v: number | undefined | null, decimals = 2) => {
  if (v === undefined || v === null || Number.isNaN(v)) return "—";
  return v.toFixed(decimals);
};

export function CompanyPerformanceTable({
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
}: CompanyPerformanceTableProps) {
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

  return (
    <div className="flex h-full flex-col rounded-md border border-border">
      <div className="flex items-center justify-between border-b border-border px-4 py-3">
        <div>
          <div className="text-sm font-semibold">Company Performance</div>
          <div className="text-xs text-muted-foreground">
            {total} companies · {loading ? "Loading..." : `${rows.length} shown`}
          </div>
        </div>
      </div>
      <div className="flex-1 overflow-auto">
        <table className="w-full min-w-[900px] table-auto border-collapse border border-border text-sm">
          <thead>
            <tr className="border-b border-border bg-muted/50">
              <th className={`${TH_CLASS} w-12`}>#</th>
              <th className={`${TH_CLASS} cursor-pointer select-none`} onClick={() => handleHeaderClick("company_name")}>
                Company <SortIcon colKey="company_name" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("total_trades")}>
                Trades <SortIcon colKey="total_trades" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("win_rate")}>
                Win Rate <SortIcon colKey="win_rate" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("avg_pnl")}>
                Avg P&L <SortIcon colKey="avg_pnl" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("profit_factor")}>
                Profit Factor <SortIcon colKey="profit_factor" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("sharpe_ratio")}>
                Sharpe <SortIcon colKey="sharpe_ratio" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("max_drawdown")}>
                Max DD <SortIcon colKey="max_drawdown" />
              </th>
              <th className={`${TH_CLASS} cursor-pointer select-none text-right`} onClick={() => handleHeaderClick("avg_days_held")}>
                Avg Days <SortIcon colKey="avg_days_held" />
              </th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, idx) => {
              const isSelected = row.company_id === selectedCompanyId;
              return (
                <tr
                  key={row.company_id}
                  className={`border-b border-border last:border-b-0 cursor-pointer ${
                    isSelected ? "bg-accent/50" : "hover:bg-accent/30"
                  }`}
                  onClick={() => onRowSelect(isSelected ? null : row.company_id)}
                >
                  <td className="px-3 py-2 text-xs text-muted-foreground">{page * pageSize + idx + 1}</td>
                  <td className="px-3 py-2 font-medium">{row.company_name}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(row.total_trades, 0)}</td>
                  <td className={`px-3 py-2 text-right tabular-nums ${row.win_rate >= 50 ? "text-emerald-600 dark:text-emerald-400" : "text-red-600 dark:text-red-400"}`}>
                    {formatPercent(row.win_rate)}
                  </td>
                  <td className={`px-3 py-2 text-right tabular-nums ${row.avg_pnl >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-red-600 dark:text-red-400"}`}>
                    {formatPercent(row.avg_pnl)}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(row.profit_factor)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(row.sharpe_ratio)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-red-600 dark:text-red-400">
                    {formatPercent(row.max_drawdown)}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(row.avg_days_held, 1)}</td>
                </tr>
              );
            })}
            {!loading && rows.length === 0 && (
              <tr>
                <td colSpan={9} className="px-3 py-8 text-center text-sm text-muted-foreground">
                  No companies found
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
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
    </div>
  );
}
