import type { IndicatorResult } from "../../types";
import type { IndicatorContext } from "../types";
import { clamp } from "./_utils";

export function rsi(ctx: IndicatorContext, params?: Record<string, number>): IndicatorResult {
  const period = params?.period ?? 14;
  const closes = ctx.closes;
  if (closes.length < period + 1) {
    return { value: 50, signal: "neutral", trend: "sideways", strength: 0, timestamp: ctx.times[ctx.times.length - 1] };
  }
  let gains = 0;
  let losses = 0;
  for (let i = closes.length - period; i < closes.length; i++) {
    const diff = closes[i] - closes[i - 1];
    if (diff >= 0) gains += diff;
    else losses -= diff;
  }
  const avgGain = gains / period;
  const avgLoss = losses / period;
  const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
  const value = 100 - 100 / (1 + rs);
  const signal = value < 30 ? "buy" : value > 70 ? "sell" : "neutral";
  const trend = value > 50 ? "up" : "down";
  return { value, signal, trend, strength: clamp(Math.abs(value - 50) * 2, 0, 100), timestamp: ctx.times[ctx.times.length - 1] };
}
