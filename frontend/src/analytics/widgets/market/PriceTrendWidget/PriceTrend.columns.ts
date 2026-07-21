import type { PriceTrendPeriod } from "./PriceTrend.types";

export const PERIOD_LABELS: Record<PriceTrendPeriod, string> = {
  "1d": "1D", "2d": "2D", "3d": "3D", "4d": "4D", "5d": "5D",
  "21d": "21D", "63d": "63D", "126d": "126D", "252d": "252D",
  "504d": "504D", "756d": "756D", "1260d": "1260D", "2520d": "2520D",
};
