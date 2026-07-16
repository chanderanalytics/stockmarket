import type { BaseModel } from "../models/common";

export type NarrativeKind = "market" | "sector" | "stock" | "portfolio" | "research";

// Narrative — a reusable, generated summary. Built from structured knowledge,
// never from raw indicators. Consumed by dashboards, AI summaries and reports.
export interface Narrative extends BaseModel {
  kind: NarrativeKind;
  title: string;
  body: string; // multi-paragraph prose
  relatedObjects: string[];
}
