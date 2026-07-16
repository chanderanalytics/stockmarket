import type { KnowledgeCategory } from "../models/KnowledgeCategory";
import type { KnowledgeSeverity } from "../models/KnowledgeSeverity";
import type { SignalRating } from "../../models/signals";

// KnowledgeClassifier — derives metadata (severity, importance, category
// nuance) from structured inputs. Pure rules, no judgement calls.
export class KnowledgeClassifier {
  static severityFromImportance(importance: number): KnowledgeSeverity {
    if (importance >= 80) return "critical";
    if (importance >= 60) return "high";
    if (importance >= 40) return "medium";
    return "low";
  }

  static importanceFromRating(rating: SignalRating): number {
    const map: Record<SignalRating, number> = {
      strong_buy: 90,
      buy: 78,
      watch: 60,
      neutral: 45,
      weak: 35,
      sell: 25,
      avoid: 12,
    };
    return map[rating];
  }

  static importanceFromParticipation(participation: number): number {
    // Extremes (very strong or very weak breadth) are more important.
    return Math.round(Math.abs(participation - 50) * 1.4 + 35);
  }

  static categoryForSeverity(base: KnowledgeCategory, severity: KnowledgeSeverity): KnowledgeCategory {
    if (severity === "critical" || severity === "high") return base;
    return base;
  }
}
