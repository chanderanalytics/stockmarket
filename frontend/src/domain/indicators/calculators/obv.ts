import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp } from "./_utils";

// On-Balance Volume — cumulative volume flow.
export function obv(ctx: IndicatorContext): IndicatorResult {
  let obv = 0;
  const series: number[] = [];
  for (let i = 0; i < ctx.closes.length; i++) {
    if (i === 0) series.push(0);
    else {
      const diff = ctx.closes[i] - ctx.closes[i - 1];
      obv += diff > 0 ? ctx.volumes[i] : diff < 0 ? -ctx.volumes[i] : 0;
      series.push(obv);
    }
  }
  const value = obv;
  // Compare last OBV to its N-period average for trend.
  const lookback = Math.min(20, series.length);
  const avg = series.slice(-lookback).reduce((s, v) => s + v, 0) / lookback;
  const trend = value > avg ? "up" : value < avg ? "down" : "sideways";
  const signal = trend === "up" ? "buy" : trend === "down" ? "sell" : "neutral";
  const strength = clamp((Math.abs(value - avg) / (Math.abs(avg) || 1)) * 20, 0, 100);
  return { value, signal, trend, strength, timestamp: ctx.times[ctx.times.length - 1] };
}
