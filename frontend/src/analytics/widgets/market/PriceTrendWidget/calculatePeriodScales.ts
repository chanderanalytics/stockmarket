import type { PriceTrendPeriod } from "./PriceTrend.types";

export interface PeriodScale {
  period: PriceTrendPeriod;
  /** Largest absolute return for this period across the dataset (independent scale). */
  maxAbs: number;
  /** Rank of each company (by row index) for this period: 1 = highest return. */
  ranks: number[];
}

/**
 * Compute an independent scale per selected period. Each column uses ONLY its
 * own maximum — a +6% 1D return and a +180% 252D return both fill the cell
 * completely. This keeps small returns clearly visible next to large ones.
 */
export function calculatePeriodScales(
  rows: Array<Record<string, unknown>>,
  periods: PriceTrendPeriod[],
): Map<PriceTrendPeriod, PeriodScale> {
  const scales = new Map<PriceTrendPeriod, PeriodScale>();

  for (const period of periods) {
    let maxAbs = 0;
    const values: number[] = [];
    for (const row of rows) {
      const raw = row[period];
      const v = toNumber(raw);
      values.push(Number.isFinite(v) ? v : NaN);
      if (Number.isFinite(v)) maxAbs = Math.max(maxAbs, Math.abs(v));
    }
    maxAbs = maxAbs || 1;

    const order = values
      .map((v, i) => ({ v, i }))
      .filter((d) => Number.isFinite(d.v))
      .sort((a, b) => b.v - a.v);

    const ranks = new Array<number>(rows.length).fill(NaN);
    order.forEach((d, rank) => {
      ranks[d.i] = rank + 1;
    });

    scales.set(period, { period, maxAbs, ranks });
  }

  return scales;
}

export function toNumber(value: unknown): number {
  if (value === null || value === undefined) return NaN;
  if (value === 9999 || value === "9999") return NaN;
  const n = typeof value === "number" ? value : Number(value);
  return Number.isNaN(n) ? NaN : n;
}
