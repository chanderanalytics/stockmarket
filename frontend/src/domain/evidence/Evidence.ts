// Evidence — the atomic, explainable fact behind every conclusion in the
// platform. Every Signal, Decision, Knowledge item, Investment Thesis and
// Explanation must be backed by Evidence. Generated deterministically.

export type EvidenceStatus = "confirmed" | "pending" | "contradicted";

export interface Evidence {
  id: string;
  metric: string; // e.g. "Breadth", "RSI", "Probability"
  observation: string; // human-readable, e.g. "Participation improving"
  weight: number; // -1..1 contribution to the bull/bear case
  confidence: number; // 0-100
  reason: string; // why this matters
  importance: number; // 0-100
  supportingData?: Record<string, number | string>;
  status: EvidenceStatus;
}
