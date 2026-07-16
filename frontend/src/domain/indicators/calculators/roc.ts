import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp } from "./_utils";

// Rate of Change (percent over N periods).
export function roc(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 10;
  const closes = ctx.closes;
  if (closes.length <= period) return { value: 0, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  const value = ((closes[closes.length - 1] - closes[closes.length - 1 - period]) / closes[closes.length - 1 - period]) * 100;
  const signal = value > 1 ? "buy" : value < -1 ? "sell" : "neutral";
  const trend = value > 0 ? "up" : "down";
  return { value, signal, trend, strength: clamp(Math.abs(value) * 4, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
