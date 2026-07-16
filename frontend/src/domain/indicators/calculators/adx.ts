import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp, emaArray, lastValid } from "./_utils";

// Average Directional Index — trend strength (0-100). >25 = strong trend.
export function adx(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 14;
  const { highs, lows, closes } = ctx;
  if (highs.length < period + 1) {
    return { value: 0, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  }
  const plusDM: number[] = [0];
  const minusDM: number[] = [0];
  const tr: number[] = [0];
  for (let i = 1; i < highs.length; i++) {
    const up = highs[i] - highs[i - 1];
    const down = lows[i - 1] - lows[i];
    plusDM.push(up > down && up > 0 ? up : 0);
    minusDM.push(down > up && down > 0 ? down : 0);
    tr.push(Math.max(highs[i] - lows[i], Math.abs(highs[i] - closes[i - 1]), Math.abs(lows[i] - closes[i - 1])));
  }
  const smooth = (arr: number[]) => emaArray(arr, period).slice(period);
  const atrS = smooth(tr);
  const pdi = smooth(plusDM).map((v, i) => (atrS[i] === 0 ? 0 : (v / atrS[i]) * 100));
  const mdi = smooth(minusDM).map((v, i) => (atrS[i] === 0 ? 0 : (v / atrS[i]) * 100));
  const dx = pdi.map((p, i) => (p + mdi[i] === 0 ? 0 : (Math.abs(p - mdi[i]) / (p + mdi[i])) * 100));
  // ADX = EMA of DX
  const adxArr = emaArray(dx, period);
  const value = lastValid(adxArr);
  const trend = pdi[pdi.length - 1] > mdi[mdi.length - 1] ? "up" : "down";
  const signal = value > 25 ? (trend === "up" ? "buy" : "sell") : "neutral";
  return { value, signal, trend, strength: clamp(value, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
