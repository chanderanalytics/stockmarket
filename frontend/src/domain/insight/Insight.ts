import type { BaseModel } from "../models/common";

export type InsightCategory =
  | "bullish"
  | "bearish"
  | "neutral"
  | "opportunity"
  | "warning"
  | "risk"
  | "momentum"
  | "breadth"
  | "sector"
  | "portfolio"
  | "research";

export type InsightPriority = "low" | "medium" | "high";

// Insight — a concise, independent, reusable observation. Consumed by
// dashboards, alerts and AI without any UI dependency.
export interface Insight extends BaseModel {
  title: string;
  description: string;
  category: InsightCategory;
  priority: InsightPriority;
  confidence: number; // 0-100
  relatedObjects: string[];
}
