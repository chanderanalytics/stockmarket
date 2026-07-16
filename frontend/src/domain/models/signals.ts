import { BaseModel, ConfidenceLevel, RiskLevel } from "./common";

export type SignalRating =
  | "strong_buy"
  | "buy"
  | "watch"
  | "neutral"
  | "weak"
  | "sell"
  | "avoid";

export interface SignalEvidence {
  label: string;
  detail: string;
  weight: number; // contribution to confidence, -1..1
}

// TradingSignal — the engine's recommendation for a single instrument.
export interface TradingSignal extends BaseModel {
  symbol: string;
  rating: SignalRating;
  confidence: ConfidenceLevel;
  confidenceScore: number; // 0-100
  risk: RiskLevel;
  riskScore: number; // 0-100
  reason: string;
  evidence: SignalEvidence[];
  targetPrice?: number;
  stopLoss?: number;
  horizonDays?: number;
}
