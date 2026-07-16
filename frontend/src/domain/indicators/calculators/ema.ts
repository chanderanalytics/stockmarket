import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp, emaArray, lastValid } from "./_utils";

export function ema(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 20;
  const arr = emaArray(ctx.closes, period);
  const value = lastValid(arr);
  const close = ctx.closes[ctx.closes.length - 1];
  const diffPct = ((close - value) / value) * 100;
  const trend = diffPct > 0.15 ? "up" : diffPct < -0.15 ? "down" : "sideways";
  const signal = trend === "up" ? "buy" : trend === "down" ? "sell" : "neutral";
  return {
    value,
    signal,
    trend,
    strength: clamp(Math.abs(diffPct) * 6, 0, 100),
    timestamp: ctx.times[ctx.times.length - 1],
  };
}
