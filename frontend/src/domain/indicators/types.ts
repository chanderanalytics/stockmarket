import type { IndicatorResult } from "../types";

export type IndicatorName =
  | "sma"
  | "ema"
  | "rsi"
  | "adx"
  | "atr"
  | "macd"
  | "vwap"
  | "roc"
  | "obv"
  | "volume"
  | "momentum"
  | "relative_strength"
  | "moving_average_envelope"
  | "bollinger_bands"
  | "super_trend"
  | "average_volume"
  | "week52_high_low";

// Series supplied to calculators. Plain numbers — never raw SQL rows.
export interface IndicatorContext {
  closes: number[];
  highs: number[];
  lows: number[];
  volumes: number[];
  times: string[];
}

export type Calculator = (ctx: IndicatorContext, params?: Record<string, number>) => IndicatorResult;

export interface IndicatorMeta {
  name: IndicatorName;
  params?: Record<string, number>;
}

// A computed indicator with its provenance metadata.
export interface IndicatorOutput extends IndicatorResult {
  name: IndicatorName;
  params?: Record<string, number>;
}
