import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp } from "./_utils";

// Momentum — percent change over a lookback, scaled to a -100..100 score.
export function momentum(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 20;
  const closes = ctx.closes;
  if (closes.length <= period) return { value: 0, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  const value = ((closes[closes.length - 1] - closes[closes.length - 1 - period]) / closes[closes.length - 1 - period]) * 100;
  const signal = value > 2 ? "buy" : value < -2 ? "sell" : "neutral";
  const trend = value > 0 ? "up" : "down";
  return { value, signal, trend, strength: clamp(Math.abs(value) * 3, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
