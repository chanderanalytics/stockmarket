import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp } from "./_utils";

// Volume Weighted Average Price (cumulative intraday-style VWAP).
export function vwap(ctx: IndicatorContext): IndicatorResult {
  let pv = 0;
  let vol = 0;
  for (let i = 0; i < ctx.closes.length; i++) {
    const typical = (ctx.highs[i] + ctx.lows[i] + ctx.closes[i]) / 3;
    pv += typical * ctx.volumes[i];
    vol += ctx.volumes[i];
  }
  const value = vol === 0 ? ctx.closes[ctx.closes.length - 1] : pv / vol;
  const close = ctx.closes[ctx.closes.length - 1];
  const diffPct = ((close - value) / value) * 100;
  const trend = diffPct > 0 ? "up" : "down";
  const signal = diffPct > 0.1 ? "buy" : diffPct < -0.1 ? "sell" : "neutral";
  return { value, signal, trend, strength: clamp(Math.abs(diffPct) * 10, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
