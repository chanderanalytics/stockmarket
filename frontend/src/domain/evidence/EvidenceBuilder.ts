import type { Evidence, EvidenceStatus } from "./Evidence";
import type { SignalEvidence } from "../models/signals";

// Helpers to construct Evidence objects from heterogeneous inputs.
export class EvidenceBuilder {
  static fromMetric(input: {
    id: string;
    metric: string;
    observation: string;
    weight: number; // -1..1
    confidence: number; // 0-100
    reason: string;
    importance: number; // 0-100
    supportingData?: Record<string, number | string>;
    status?: EvidenceStatus;
  }): Evidence {
    return {
      id: input.id,
      metric: input.metric,
      observation: input.observation,
      weight: Math.max(-1, Math.min(1, input.weight)),
      confidence: Math.max(0, Math.min(100, input.confidence)),
      reason: input.reason,
      importance: Math.max(0, Math.min(100, input.importance)),
      supportingData: input.supportingData,
      status: input.status ?? "confirmed",
    };
  }

  // Convert a SignalEngine evidence entry into a first-class Evidence object.
  static fromSignalEvidence(se: SignalEvidence, symbol: string): Evidence {
    const weight = Math.max(-1, Math.min(1, se.weight));
    return {
      id: `ev-${symbol}-${se.label.toLowerCase().replace(/[^a-z0-9]/g, "_")}`,
      metric: se.label,
      observation: se.detail,
      weight,
      confidence: Math.round(Math.abs(weight) * 100),
      reason: `${se.label} contributes ${weight >= 0 ? "bullish" : "bearish"} weight (${weight.toFixed(2)}).`,
      importance: Math.round(Math.abs(weight) * 100),
      status: weight === 0 ? "pending" : "confirmed",
    };
  }
}
