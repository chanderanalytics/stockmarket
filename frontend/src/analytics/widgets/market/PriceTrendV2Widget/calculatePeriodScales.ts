import type { PriceTrendV2Period } from "./PriceTrendV2.types";

export interface PeriodScale {
  period: PriceTrendV2Period;
  maxAbs: number;
  ranks: number[];
}

export function calculatePeriodScales(
  rows: Array<Record<string, unknown>>,
  periods: PriceTrendV2Period[],
): Map<PriceTrendV2Period, PeriodScale> {
  const scales = new Map<PriceTrendV2Period, PeriodScale>();

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
