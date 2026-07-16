import type * as React from "react";

export type CardTrend = "up" | "down" | "flat" | "none";
export type CardStatus = "ok" | "warning" | "error" | "info" | "neutral";
export type CardSeverity = "low" | "medium" | "high" | "critical" | "none";

export interface MetricCardData {
  label?: string;
  value: string | number | null;
  change?: string | null;
  trend?: CardTrend;
  status?: CardStatus;
  icon?: React.ReactNode;
  tooltip?: string;
}

export interface StatusCardData {
  status: CardStatus;
  label?: string;
  detail?: string;
  severity?: CardSeverity;
}

export interface ValueComparisonData {
  current: string | number | null;
  previous: string | number | null;
  change?: string | null;
  changePercent?: string | null;
  trend?: CardTrend;
}

export interface SummaryStripItem {
  label: string;
  value: string | number | null;
  status?: CardStatus;
  trend?: CardTrend;
}

export interface SummaryStripData {
  items: SummaryStripItem[];
}
