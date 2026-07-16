import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp, mean } from "./_utils";

// Average Volume — trailing mean, returned as a ratio vs latest volume.
export function averageVolume(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 20;
  const vols = ctx.volumes;
  if (vols.length < 2) return { value: 0, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  const avg = mean(vols.slice(-period));
  const value = avg;
  const ratio = avg === 0 ? 1 : vols[vols.length - 1] / avg;
  const trend = ratio > 1 ? "up" : "down";
  return { value, signal: "neutral", trend, strength: clamp((ratio - 1) * 60, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
