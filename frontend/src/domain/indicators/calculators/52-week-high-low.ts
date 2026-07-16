import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp } from "./_utils";

// 52-week High/Low position — where price sits between the annual range.
export function week52HighLow(ctx: IndicatorContext): IndicatorResult {
  const highs = ctx.highs;
  const lows = ctx.lows;
  const closes = ctx.closes;
  if (highs.length === 0) return { value: 50, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  const high = Math.max(...highs);
  const low = Math.min(...lows);
  const close = closes[closes.length - 1];
  const value = high === low ? 50 : ((close - low) / (high - low)) * 100;
  const signal = value > 95 ? "sell" : value < 5 ? "buy" : "neutral";
  const trend = value >= 50 ? "up" : "down";
  return { value, signal, trend, strength: clamp(Math.abs(value - 50) * 2, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
