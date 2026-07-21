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

export type BreadthMetricMode = "compositeBreadth" | "aboveDMA";

export type BreadthHistoryPeriod = "1m" | "3m" | "6m" | "1y";

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

export interface MergedBreadthRow {
  id: string;
  name: string;
  companyCount: number;
  marketCap: number;
  weightedReturn: number;
  relativeVolume: number;
  sector: string;
  industry: string;
  industrySubGroup: string;
  signalScores: Record<BreadthSignalType, Record<string, number>>;
}

export interface BreadthResponse {
  level: BreadthLevel;
  total: number;
  rows: BreadthRow[];
}

export interface BreadthHistoryResponse {
  period: string;
  dates: string[];
  series: Record<string, number[]>;
}

export type BreadthMarketCap = "" | "large" | "mid" | "small";
export type BreadthMarketCapBucket = "" | "top 10perc by mcap" | "50-90% by mcap" | "bottom 50% by mcap";

export interface BreadthFilterState {
  sector: string;
  industry: string;
  industrySubGroup: string;
  marketCap: BreadthMarketCap;
  marketCapBucket: BreadthMarketCapBucket;
  limit: number;
  companyName: string;
  sortMetric: BreadthSortMetric;
  sortDir: BreadthSortDir;
  signalType: BreadthSignalType;
}

export const HORIZON_ORDER: BreadthHorizon[] = [1, 5, 21, 63, 126, 256];

export const HORIZON_LABELS: Record<BreadthHorizon, string> = {
  1: "1d",
  5: "5d",
  21: "21d",
  63: "63d",
  126: "126d",
  256: "256d",
};

export const SIGNAL_TYPE_LABELS: Record<BreadthSignalType, string> = {
  above20dma: "Above 20 DMA",
  above50dma: "Above 50 DMA",
  above100dma: "Above 100 DMA",
  above200dma: "Above 200 DMA",
};

export const SIGNAL_TYPE_OPTIONS: { value: BreadthSignalType; label: string }[] = [
  { value: "above20dma", label: "Above 20 DMA" },
  { value: "above50dma", label: "Above 50 DMA" },
  { value: "above100dma", label: "Above 100 DMA" },
  { value: "above200dma", label: "Above 200 DMA" },
];
