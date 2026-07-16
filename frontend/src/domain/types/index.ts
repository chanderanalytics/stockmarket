// Primitive input shapes consumed by the engines. These are NOT database rows
// and never expose column names — they are plain computational inputs.

export interface OHLC {
  time: string; // ISO date
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface PricePoint {
  time: string;
  value: number;
}

export interface SeriesPoint {
  time: string;
  value: number;
}

// Normalized result every indicator calculator returns.
export interface IndicatorResult {
  value: number;
  signal: "buy" | "sell" | "neutral";
  trend: "up" | "down" | "sideways";
  strength: number; // 0-100
  timestamp: string;
}

// Raw wide-row snapshot of the probability table for a single instrument.
// Column names are normalized here; the engine maps DB column names => this shape
// in the data service, so nothing downstream ever sees raw SQL column names.
export interface ProbabilityWideRow {
  symbol: string;
  // Return-bucket probabilities (0-100) for positive return ranges.
  returnBuckets: { from: number; to: number; probability: number }[];
  volatility21d: number; // annualized % proxy
  volatility63d: number;
  pvol21d: number;
  pvol252d: number;
  volumeTrend: number; // -1..1
}
