import type { PriceTrendPeriod } from "./PriceTrend.types";

export interface PriceTrendGridRow {
  /** Original index in the source dataset (used for rank lookup). */
  index: number;
  id: string;
  name: string;
  companyCount: number | null;
  sector: string;
  industry: string;
  industrySubGroup: string;
  marketCap: number;
  /** Selected period key -> numeric return (NaN if missing / 9999). */
  values: Map<PriceTrendPeriod, number>;
  /** Selected period key -> formatted string (e.g. "+14.62%") or "—". */
  formatted: Map<PriceTrendPeriod, string>;
}

function fmt(value: number): string {
  if (!Number.isFinite(value)) return "—";
  const sign = value >= 0 ? "+" : "";
  return `${sign}${value.toFixed(2)}%`;
}

/**
 * Transform backend rows into the grid row model. Pure function: no React, no
 * side effects. Period values are normalized to numbers up front so the cell
 * renderer and scales never re-parse.
 */
export function buildRows(
  rows: Array<Record<string, unknown>>,
  periods: PriceTrendPeriod[],
): PriceTrendGridRow[] {
  return rows.map((row, idx) => {
    const values = new Map<PriceTrendPeriod, number>();
    const formatted = new Map<PriceTrendPeriod, string>();
    for (const period of periods) {
      const raw = row[period];
      const n = raw === null || raw === undefined || raw === 9999 || raw === "9999"
        ? NaN
        : typeof raw === "number"
          ? raw
          : Number(raw);
      const value = Number.isNaN(n) ? NaN : n;
      values.set(period, value);
      formatted.set(period, fmt(value));
    }

    return {
      index: idx,
      id: String(row.id ?? idx),
      name: String(row.name ?? ""),
      companyCount: typeof row.companyCount === "number" ? row.companyCount : null,
      sector: String(row.sector ?? ""),
      industry: String(row.industry ?? ""),
      industrySubGroup: String(row.industrySubGroup ?? ""),
      marketCap: typeof row.marketCap === "number" ? row.marketCap : Number(row.marketCap) || 0,
      values,
      formatted,
    };
  });
}
