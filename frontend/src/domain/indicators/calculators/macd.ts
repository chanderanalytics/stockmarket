import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp, emaArray, lastValid } from "./_utils";

// Moving Average Convergence Divergence.
export function macd(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const fast = params?.fast ?? 12;
  const slow = params?.slow ?? 26;
  const signalPeriod = params?.signal ?? 9;
  const closes = ctx.closes;
  if (closes.length < slow + signalPeriod) {
    return { value: 0, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  }
  const emaFast = emaArray(closes, fast);
  const emaSlow = emaArray(closes, slow);
  const macdLine = closes.map((_, i) => emaFast[i] - emaSlow[i]);
  const signalLine = emaArray(macdLine.slice(slow - 1), signalPeriod);
  const macdVal = lastValid(macdLine);
  const sigVal = lastValid(signalLine);
  const hist = macdVal - sigVal;
  const signal = hist > 0 ? "buy" : hist < 0 ? "sell" : "neutral";
  const trend = macdVal > 0 ? "up" : "down";
  return { value: macdVal, signal, trend, strength: clamp(Math.abs(hist) * 4, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
