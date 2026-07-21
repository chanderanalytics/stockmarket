import type { PriceTrendV2Period } from "./PriceTrendV2.types";

export interface PriceTrendV2GridRow {
  index: number;
  id: string;
  name: string;
  companyCount: number | null;
  sector: string;
  industry: string;
  industrySubGroup: string;
  marketCap: number;
  values: Map<PriceTrendV2Period, number>;
  formatted: Map<PriceTrendV2Period, string>;
}

function fmt(value: number): string {
  if (!Number.isFinite(value)) return "—";
  const sign = value >= 0 ? "+" : "";
  return `${sign}${value.toFixed(2)}%`;
}

export function buildRows(
  rows: Array<Record<string, unknown>>,
  periods: PriceTrendV2Period[],
): PriceTrendV2GridRow[] {
  return rows.map((row, idx) => {
    const values = new Map<PriceTrendV2Period, number>();
    const formatted = new Map<PriceTrendV2Period, string>();
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
