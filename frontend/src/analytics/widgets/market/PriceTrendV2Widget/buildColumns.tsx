import type { ColumnDef } from "@tanstack/react-table";
import type { PriceTrendV2GridRow } from "./buildRows";
import type { PriceTrendV2Period } from "./PriceTrendV2.types";
import { formatPeriodLabel, sortPeriodsChronologically } from "./PriceTrendV2.utils";

export interface CompanyColumnMeta {
  kind: "company";
}
export interface PeriodColumnMeta {
  kind: "period";
  period: PriceTrendV2Period;
}

export function buildColumns(periods: PriceTrendV2Period[]): ColumnDef<PriceTrendV2GridRow>[] {
  const sorted = sortPeriodsChronologically(periods);

  const companyColumn: ColumnDef<PriceTrendV2GridRow> = {
    id: "company",
    accessorFn: (row) => row.name,
    header: "Entity",
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

  const countColumn: ColumnDef<PriceTrendV2GridRow> = {
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

  const periodColumns: ColumnDef<PriceTrendV2GridRow>[] = sorted.map((period) => ({
    id: period,
    accessorFn: (row) => row.values.get(period) ?? NaN,
    header: formatPeriodLabel(period),
    enableSorting: true,
    cell: (ctx) => ctx.getValue(),
    meta: { kind: "period", period } as PeriodColumnMeta,
  }));

  return [companyColumn, countColumn, ...periodColumns];
}
