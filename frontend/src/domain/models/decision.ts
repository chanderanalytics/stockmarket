import { BaseModel, RiskLevel } from "./common";
import type { SignalRating } from "./signals";

// DecisionSummary — converts signals into actionable intelligence.
export interface DecisionSummary extends BaseModel {
  deployNewMoney: boolean;
  recommendedExposure: number; // % of capital to deploy
  cashAllocation: number; // % to hold in cash
  preferredSectors: string[];
  watchlistActions: { symbol: string; action: SignalRating }[];
  overallRisk: RiskLevel;
  opportunityCount: number;
  marketQuality: number; // 0-100
  summary: string;
  thesis: string[];
}
