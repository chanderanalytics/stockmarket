import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp, lastValid, smaArray, stddev } from "./_utils";

// Bollinger Bands — %B position of price within the bands.
export function bollingerBands(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 20;
  const mult = params?.mult ?? 2;
  const closes = ctx.closes;
  if (closes.length < period) return { value: 50, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  const midArr = smaArray(closes, period);
  const mid = lastValid(midArr);
  const slice = closes.slice(-period);
  const sd = stddev(slice);
  const upper = mid + mult * sd;
  const lower = mid - mult * sd;
  const close = closes[closes.length - 1];
  const pctB = upper === lower ? 0.5 : (close - lower) / (upper - lower);
  const value = pctB * 100;
  const signal = pctB > 1 ? "sell" : pctB < 0 ? "buy" : "neutral";
  const trend = close > mid ? "up" : "down";
  return { value: pctB * 100, signal, trend, strength: clamp(Math.abs(pctB - 0.5) * 200, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
