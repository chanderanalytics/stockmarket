import type { Explanation } from "./Explanation";
import type { TradingSignal } from "../models/signals";
import type { DecisionSummary } from "../models/decision";
import type { Knowledge } from "../knowledge/models/Knowledge";
import { EvidenceBuilder } from "../evidence/EvidenceBuilder";

// ExplanationEngine — converts a decision/signal/knowledge into a human
// "Why?" explanation backed by evidence. Deterministic.
export class ExplanationEngine {
  static explainSignal(signal: TradingSignal): Explanation {
    const evidence = signal.evidence.map((se) => EvidenceBuilder.fromSignalEvidence(se, signal.symbol));
    const bullets = evidence
      .slice(0, 4)
      .map((e) => `• ${e.observation} (${e.weight >= 0 ? "+" : ""}${e.weight.toFixed(2)})`)
      .join("\n");
    return {
      id: `explanation-${signal.id}`,
      timestamp: new Date().toISOString(),
      targetId: signal.id,
      targetType: "TradingSignal",
      summary: signal.rating.replace("_", " ").toUpperCase(),
      detailedReason: `Rating ${signal.rating.replace("_", " ")} because: ${signal.reason}\n\n${bullets}`,
      supportingEvidence: evidence,
      confidence: Math.round(signal.confidenceScore),
      references: [signal.id],
    };
  }

  static explainDecision(decision: DecisionSummary): Explanation {
    const bullets = decision.thesis.map((t) => `• ${t}`).join("\n");
    return {
      id: `explanation-${decision.id}`,
      timestamp: new Date().toISOString(),
      targetId: decision.id,
      targetType: "DecisionSummary",
      summary: decision.deployNewMoney ? "DEPLOY SELECTIVELY" : "STAY DEFENSIVE",
      detailedReason: `${decision.summary}\n\nReasoning:\n${bullets}`,
      supportingEvidence: [],
      confidence: Math.round(decision.marketQuality),
      references: [decision.id],
    };
  }

  static explainKnowledge(k: Knowledge): Explanation {
    return {
      id: `explanation-${k.id}`,
      timestamp: new Date().toISOString(),
      targetId: k.id,
      targetType: "Knowledge",
      summary: k.title,
      detailedReason: k.summary,
      supportingEvidence: k.supportingEvidence,
      confidence: Math.round(k.confidence),
      references: [k.id, ...k.relatedObjects],
    };
  }

  // Resolve an explanation by id from a supplied lookup map (built by the
  // KnowledgeRuntime service). Keeps the API endpoint pure.
  static byId(id: string, lookup: Map<string, Explanation>): Explanation | null {
    return lookup.get(id) ?? null;
  }
}
