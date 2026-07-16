import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp, emaArray, lastValid } from "./_utils";

// SuperTrend — ATR-based trend filter.
export function superTrend(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 10;
  const mult = params?.mult ?? 3;
  const { highs, lows, closes } = ctx;
  if (highs.length < period + 1) return { value: closes[closes.length - 1], signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  const tr: number[] = [];
  for (let i = 1; i < highs.length; i++) {
    tr.push(Math.max(highs[i] - lows[i], Math.abs(highs[i] - closes[i - 1]), Math.abs(lows[i] - closes[i - 1])));
  }
  const atrArr = emaArray(tr, period);
  let upperBand = 0;
  let lowerBand = 0;
  let prevUpper = highs[0] + mult * (atrArr[0] || 0);
  let prevLower = lows[0] - mult * (atrArr[0] || 0);
  let trendUp = true;
  for (let i = 1; i < highs.length; i++) {
    const atr = atrArr[i] || 0;
    upperBand = (highs[i] + lows[i]) / 2 + mult * atr;
    lowerBand = (highs[i] + lows[i]) / 2 - mult * atr;
    upperBand = Math.min(upperBand, prevUpper);
    lowerBand = Math.max(lowerBand, prevLower);
    if (closes[i - 1] > prevUpper) trendUp = true;
    else if (closes[i - 1] < prevLower) trendUp = false;
    prevUpper = upperBand;
    prevLower = lowerBand;
  }
  const value = trendUp ? lowerBand : upperBand;
  const close = closes[closes.length - 1];
  const trend = trendUp ? "up" : "down";
  const signal = trendUp ? "buy" : "sell";
  const strength = clamp(Math.abs(close - value) / (close || 1) * 100 * 5, 0, 100);
  return { value, signal, trend, strength, timestamp: ctx.times[ctx.times.length - 1] };
}
