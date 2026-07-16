import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp, mean } from "./_utils";

// Volume — current volume vs its trailing average, normalized to a z-score-ish score.
export function volume(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 20;
  const vols = ctx.volumes;
  if (vols.length < 2) return { value: 0, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  const recent = vols.slice(-period);
  const avg = mean(recent);
  const last = vols[vols.length - 1];
  const ratio = avg === 0 ? 1 : last / avg;
  const value = ratio;
  const trend = ratio > 1.1 ? "up" : ratio < 0.9 ? "down" : "sideways";
  const signal = ratio > 2 ? "buy" : ratio < 0.5 ? "sell" : "neutral";
  return { value, signal, trend, strength: clamp((ratio - 1) * 60, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
