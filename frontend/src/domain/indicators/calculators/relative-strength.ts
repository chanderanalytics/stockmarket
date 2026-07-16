import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp } from "./_utils";

// Relative Strength vs a benchmark series (e.g. index or sector).
// ctx2-style: we pass benchmark via params.series.
export function relativeStrength(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const benchmark = params?.benchmark ? [params.benchmark] : [];
  const benchSeries = (params?.series as number[] | undefined) ?? benchmark;
  const closes = ctx.closes;
  const period = params?.period ?? 20;
  if (closes.length <= period || benchSeries.length <= period) {
    return { value: 50, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  }
  const stockRet = (closes[closes.length - 1] - closes[closes.length - 1 - period]) / closes[closes.length - 1 - period];
  const benchRet = (benchSeries[benchSeries.length - 1] - benchSeries[benchSeries.length - 1 - period]) / benchSeries[benchSeries.length - 1 - period];
  const rs = benchRet === 0 ? 1 : stockRet / benchRet;
  // Map rs to 0-100: rs=1 => 50, rs>=2 => 100, rs<=0 => 0.
  const value = clamp(50 + (rs - 1) * 50, 0, 100);
  const trend = value >= 50 ? "up" : "down";
  const signal = value > 60 ? "buy" : value < 40 ? "sell" : "neutral";
  return { value, signal, trend, strength: clamp(Math.abs(value - 50) * 2, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
