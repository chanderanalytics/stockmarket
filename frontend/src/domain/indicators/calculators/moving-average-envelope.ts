import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp, lastValid, smaArray } from "./_utils";

// Moving Average Envelope — distance of price from SMA expressed as percent bands.
export function movingAverageEnvelope(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 20;
  const pct = params?.pct ?? 2.5;
  const arr = smaArray(ctx.closes, period);
  const mid = lastValid(arr);
  const close = ctx.closes[ctx.closes.length - 1];
  const dev = ((close - mid) / mid) * 100;
  const value = dev;
  const upper = mid * (1 + pct / 100);
  const lower = mid * (1 - pct / 100);
  const trend = dev > 0 ? "up" : "down";
  const signal = close > upper ? "sell" : close < lower ? "buy" : "neutral";
  return { value, signal, trend, strength: clamp(Math.abs(dev) * 8, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
