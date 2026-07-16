import type { BaseModel } from "../models/common";
import type { Evidence } from "../evidence/Evidence";

export type SuggestedAction = "accumulate" | "hold" | "watch" | "reduce" | "avoid";

// InvestmentThesis — a complete, evidence-backed thesis for one opportunity.
// Generated deterministically from the same engines every consumer uses.
export interface InvestmentThesis extends BaseModel {
  symbol: string;
  marketContext: string;
  sectorContext: string;
  trend: string;
  momentum: string;
  probability: string;
  risk: string;
  holdingPeriod: string;
  catalysts: string[];
  warnings: string[];
  supportingEvidence: Evidence[];
  confidence: number; // 0-100
  suggestedAction: SuggestedAction;
  entryBias: string;
  exitConsiderations: string;
}
