import type { ColumnDef } from "@tanstack/react-table";
import type { PriceTrendGridRow } from "./buildRows";
import type { PriceTrendPeriod } from "./PriceTrend.types";
import { formatPeriodLabel, sortPeriodsChronologically } from "./PriceTrend.utils";

export interface CompanyColumnMeta {
  kind: "company";
}
export interface PeriodColumnMeta {
  kind: "period";
  period: PriceTrendPeriod;
}

/**
 * Build TanStack columns: one sticky company column + one column per selected
 * period (ordered chronologically). Columns are fully dynamic — selecting
 * 1D/5D/252D yields exactly those three period columns in that order.
 */
export function buildColumns(periods: PriceTrendPeriod[]): ColumnDef<PriceTrendGridRow>[] {
  const sorted = sortPeriodsChronologically(periods);

  const companyColumn: ColumnDef<PriceTrendGridRow> = {
    id: "company",
    accessorFn: (row) => row.name,
    header: "Company",
    enableSorting: true,
    cell: (ctx) => {
      const row = ctx.row.original;
      const crumb = [row.sector, row.industry, row.industrySubGroup].filter(Boolean).join(" › ");
      return (
        <div className="flex min-w-0 flex-col justify-center">
          <span className="text-sm font-medium text-foreground">{row.name}</span>
          {crumb && <span className="text-xs text-muted-foreground">{crumb}</span>}
        </div>
      );
    },
    meta: { kind: "company" } as CompanyColumnMeta,
  };

  const countColumn: ColumnDef<PriceTrendGridRow> = {
    id: "count",
    accessorFn: (row) => row.companyCount ?? null,
    header: "Count",
    enableSorting: true,
    cell: (ctx) => {
      const value = ctx.getValue();
      return (
        <div className="flex h-full items-center justify-center">
          <span className="text-xs tabular-nums text-muted-foreground">{value == null ? "—" : Number(value).toLocaleString()}</span>
        </div>
      );
    },
  };

  const periodColumns: ColumnDef<PriceTrendGridRow>[] = sorted.map((period) => ({
    id: period,
    accessorFn: (row) => row.values.get(period) ?? NaN,
    header: formatPeriodLabel(period),
    enableSorting: true,
    cell: (ctx) => ctx.getValue(),
    meta: { kind: "period", period } as PeriodColumnMeta,
  }));

  return [companyColumn, countColumn, ...periodColumns];
}
