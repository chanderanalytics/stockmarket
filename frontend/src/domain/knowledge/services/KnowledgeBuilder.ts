import type { Knowledge, KnowledgeCategory, KnowledgeSeverity } from "../models";
import type { Evidence } from "../../evidence/Evidence";
import type { KnowledgeSource } from "../models/KnowledgeSource";
import { KnowledgeClassifier } from "./KnowledgeClassifier";

export interface KnowledgeDraft {
  id: string;
  title: string;
  summary: string;
  category: KnowledgeCategory;
  confidence: number; // 0-100
  importance: number; // 0-100
  evidence?: Evidence[];
  relatedObjects?: string[];
  source?: KnowledgeSource;
  timestamp?: string;
  severity?: KnowledgeSeverity;
}

// KnowledgeBuilder — assembles a Knowledge object with sensible defaults
// (severity derived from importance, timestamp filled).
export class KnowledgeBuilder {
  static build(draft: KnowledgeDraft): Knowledge {
    return {
      id: draft.id,
      timestamp: draft.timestamp ?? new Date().toISOString(),
      title: draft.title,
      summary: draft.summary,
      category: draft.category,
      confidence: Math.max(0, Math.min(100, Math.round(draft.confidence))),
      importance: Math.max(0, Math.min(100, Math.round(draft.importance))),
      severity: draft.severity ?? KnowledgeClassifier.severityFromImportance(draft.importance),
      supportingEvidence: draft.evidence ?? [],
      relatedObjects: draft.relatedObjects ?? [],
      source: draft.source,
    };
  }
}
