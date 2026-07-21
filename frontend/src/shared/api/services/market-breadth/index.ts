import { api } from "../../api-client";

export type BreadthLevel = "market" | "sector" | "industry" | "industrySubGroup" | "company";
export type BreadthHorizon = 1 | 5 | 21 | 63 | 126 | 256;
export type BreadthSortMetric =
  | "breadthScore"
  | "trendStrength"
  | "advanceDeclineRatio"
  | "marketCap"
  | "weightedReturn"
  | "relativeVolume"
  | "name";
export type BreadthSortDir = "asc" | "desc";
export type BreadthDMAPeriod = 20 | 50 | 100 | 200;

export type BreadthViewMode = "metrics" | "marketState";
export type BreadthSignalType = "above20dma" | "above50dma" | "above100dma" | "above200dma";

export interface BreadthHorizonMetrics {
  breadthScore: number;
  compositeBreadth: number;
  dmaDistance: Record<string, { distance: number | null }>;
  trendStrength: number;
  advanceDeclineRatio: number;
  aboveDMA: Record<string, { count: number; percentage: number }>;
  signalType?: BreadthSignalType;
}

export interface BreadthSummary {
  totalCompanies: number;
  aboveDMA: Record<string, { count: number; percentage: number }>;
  compositeBreadth: number;
  trendStrength: number;
  trendScore: number;
  trendClassification: string;
  trendScoreByDMA?: Record<string, { score: number; classification: string }>;
  advanceDeclineRatio: number;
  newHighPct: number;
  newLowPct: number;
  relativeVolume: number;
  weightedReturn: number;
  signalType?: BreadthSignalType;
  breadthByHorizon: Record<string, BreadthHorizonMetrics>;
}

export interface BreadthDistribution {
  total: number;
  distribution: Record<string, { above: { count: number; percentage: number }; below: { count: number; percentage: number } }>;
}

export interface BreadthRow {
  id: string;
  name: string;
  companyCount: number;
  marketCap: number;
  breadthScore: number;
  trendStrength: number;
  trendScore: number;
  trendClassification: string;
  trendScoreByDMA?: Record<string, { score: number; classification: string }>;
  weightedReturn: number;
  relativeVolume: number;
  advanceDeclineRatio: number;
  newHighPct: number;
  newLowPct: number;
  sector: string;
  industry: string;
  industrySubGroup: string;
  aboveDMA: Record<string, { count?: number; percentage: number }>;
  dmaDistance: Record<string, { distance: number | null }>;
  horizons: Record<string, BreadthHorizonMetrics>;
  signalType?: BreadthSignalType;
  [key: string]: unknown;
}

export interface BreadthResponse {
  level: BreadthLevel;
  total: number;
  rows: BreadthRow[];
}

export const marketBreadthService = {
  summary: (params?: Record<string, unknown>) =>
    api.get<BreadthSummary>("/api/market-breadth/summary", { params }),

  distribution: (params?: Record<string, unknown>) =>
    api.get<BreadthDistribution>("/api/market-breadth/distribution", { params }),

  sectors: (params?: Record<string, unknown>) =>
    api.get<BreadthResponse>("/api/market-breadth/sectors", { params }),

  industries: (params?: Record<string, unknown>) =>
    api.get<BreadthResponse>("/api/market-breadth/industries", { params }),

  companies: (params?: Record<string, unknown>) =>
    api.get<BreadthResponse>("/api/market-breadth/companies", { params }),

  subgroups: (params?: Record<string, unknown>) =>
    api.get<BreadthResponse>("/api/market-breadth/subgroups", { params }),

  history: (params?: Record<string, unknown>) =>
    api.get<{ period: string; dates: string[]; series: Record<string, number[]> }>(
      "/api/market-breadth/history",
      { params }
    ),
};
