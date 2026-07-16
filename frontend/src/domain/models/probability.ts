import { BaseModel } from "./common";
import type { SignalRating } from "./signals";

export interface ExpectedReturn {
  horizon: string; // e.g. "21d"
  value: number; // percent
  scenario: "base" | "bull" | "bear";
}

// ProbabilityAnalysis — hides the hundreds-of-columns wide probability table.
export interface ProbabilityAnalysis extends BaseModel {
  symbol: string;
  expectedReturn: ExpectedReturn[];
  upsideProbability: number; // 0-100
  downsideProbability: number; // 0-100
  expectedHoldingPeriod: number; // days
  confidenceScore: number; // 0-100
  volatilityExpectation: number; // annualized %
  rewardRiskRatio: number;
  recommendation: SignalRating;
  normalizedScore: number; // 0-100 composite
}
