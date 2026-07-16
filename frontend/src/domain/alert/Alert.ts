import type { BaseModel } from "../models/common";

export type AlertType = "market" | "sector" | "stock" | "watchlist" | "portfolio" | "risk" | "opportunity";
export type AlertSeverity = "info" | "warning" | "critical";

// Alert — a generated notification object. Contains NO UI; consumers (push,
// email, in-app) render it. Produced deterministically from knowledge.
export interface Alert extends BaseModel {
  type: AlertType;
  title: string;
  message: string;
  importance: number; // 0-100
  severity: AlertSeverity;
  suggestedAction: string;
  relatedObjects: string[];
}
