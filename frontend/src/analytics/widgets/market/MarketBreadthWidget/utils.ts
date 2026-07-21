import type { BreadthLevel, BreadthSortMetric, BreadthSignalType } from "./types";

export const LEVEL_ORDER: readonly BreadthLevel[] = [
  "market",
  "sector",
  "industry",
  "industrySubGroup",
  "company",
];

export function levelLabel(level: BreadthLevel): string {
  switch (level) {
    case "market":
      return "Market";
    case "sector":
      return "Sector";
    case "industry":
      return "Industry";
    case "industrySubGroup":
      return "Industry Sub-Group";
    case "company":
      return "Company";
    default:
      return level;
  }
}

export function nextDrillLevel(level: BreadthLevel): BreadthLevel | null {
  const idx = LEVEL_ORDER.indexOf(level);
  return idx >= 0 && idx < LEVEL_ORDER.length - 1 ? LEVEL_ORDER[idx + 1] : null;
}

export const SORT_METRIC_LABELS: Record<BreadthSortMetric, string> = {
  breadthScore: "Signal",
  trendStrength: "Trend Strength",
  advanceDeclineRatio: "Advance/Decline",
  marketCap: "Market Cap",
  weightedReturn: "Weighted Return",
  relativeVolume: "Relative Volume",
  name: "Name",
};

export const SORT_METRIC_MEANING: Record<BreadthSortMetric, string> = {
  breadthScore: "% of stocks above the selected signal DMA",
  trendStrength: "Weighted DMA trend strength",
  advanceDeclineRatio: "Advancing / declining ratio",
  marketCap: "Total market capitalisation (₹ cr)",
  weightedReturn: "Cap-weighted 252d return",
  relativeVolume: "Volume vs 1y average",
  name: "Entity name",
};

export const SIGNAL_TYPE_LABELS: Record<BreadthSignalType, string> = {
  above20dma: "Above 20 DMA",
  above50dma: "Above 50 DMA",
  above100dma: "Above 100 DMA",
  above200dma: "Above 200 DMA",
};
