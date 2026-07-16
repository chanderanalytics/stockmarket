import { BaseModel, SignalStrength, TrendDirection } from "./common";

export interface WatchlistSummary extends BaseModel {
  watchlistId: string;
  name: string;
  itemCount: number;
  overallTrend: TrendDirection;
  advancers: number;
  decliners: number;
  strongest: string; // symbol
  weakest: string; // symbol
  avgChangePercent: number;
  alerts: WatchlistAlert[];
}

export interface WatchlistAlert {
  symbol: string;
  type: "breakout" | "breakdown" | "volume_spike" | "news" | "target_hit";
  message: string;
  severity: SignalStrength;
  timestamp: string;
}
