import type { BaseModel } from "../models/common";
import type { Evidence } from "../evidence/Evidence";

// Explanation — answers "Why?" for any result. References the structured
// evidence so the conclusion is fully auditable. Never contains raw indicators.
export interface Explanation extends BaseModel {
  targetId: string; // id of the signal / knowledge / decision being explained
  targetType: string; // e.g. "TradingSignal"
  summary: string; // e.g. "BUY"
  detailedReason: string;
  supportingEvidence: Evidence[];
  confidence: number; // 0-100
  references: string[]; // ids of related domain objects
}
