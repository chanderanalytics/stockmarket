import type { BaseModel } from "../../models/common";
import type { KnowledgeCategory } from "./KnowledgeCategory";
import type { KnowledgeSeverity } from "./KnowledgeSeverity";
import type { KnowledgeSource } from "./KnowledgeSource";
import type { Evidence } from "../../evidence/Evidence";

// Knowledge — a human-readable, reusable interpretation of business objects.
// Consumed by frontend, AI, alerts, reports and notifications. Never raw
// indicator values.
export interface Knowledge extends BaseModel {
  title: string;
  summary: string;
  category: KnowledgeCategory;
  importance: number; // 0-100
  confidence: number; // 0-100
  severity: KnowledgeSeverity;
  supportingEvidence: Evidence[];
  relatedObjects: string[]; // ids of related domain objects (signals, sectors…)
  source?: KnowledgeSource;
}
