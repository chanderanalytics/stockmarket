import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp } from "./_utils";

// Average True Range — volatility measure.
export function atr(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 14;
  const { highs, lows, closes } = ctx;
  if (highs.length < 2) return { value: 0, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  const tr: number[] = [];
  for (let i = 1; i < highs.length; i++) {
    const a = highs[i] - lows[i];
    const b = Math.abs(highs[i] - closes[i - 1]);
    const c = Math.abs(lows[i] - closes[i - 1]);
    tr.push(Math.max(a, b, c));
  }
  const slice = tr.slice(-period);
  const value = slice.reduce((s, v) => s + v, 0) / slice.length;
  const close = closes[closes.length - 1];
  const pct = (value / close) * 100;
  return { value, signal: "neutral", trend: "sideways", strength: clamp(pct * 8, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
