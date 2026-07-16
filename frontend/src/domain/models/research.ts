import { BaseModel, ConfidenceLevel } from "./common";

// ResearchSnapshot — curated research view for a single instrument.
export interface ResearchSnapshot extends BaseModel {
  symbol: string;
  name: string;
  thesis: string;
  bullCase: string[];
  bearCase: string[];
  keyMetrics: { label: string; value: string; benchmark?: string }[];
  analystConsensus: "strong_buy" | "buy" | "hold" | "sell" | "strong_sell";
  targetPrice: number;
  upsidePercent: number;
  confidence: ConfidenceLevel;
  lastUpdated: string;
  sources: { title: string; url: string; publishedAt: string }[];
}
