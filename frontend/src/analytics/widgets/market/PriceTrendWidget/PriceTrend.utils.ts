import type { PriceTrendPeriod } from "./PriceTrend.types";

export function getPeriodColor(period: PriceTrendPeriod): string {
  const PERIOD_COLOR_MAP: Record<PriceTrendPeriod, string> = {
    "1d": "#5470c6",
    "2d": "#91cc75",
    "3d": "#fac858",
    "4d": "#ee6666",
    "5d": "#73c0de",
    "21d": "#3ba272",
    "63d": "#fc8452",
    "126d": "#9a60b4",
    "252d": "#ea7ccc",
    "504d": "#6b9080",
    "756d": "#c87e8a",
    "1260d": "#7fb3d5",
    "2520d": "#b8d4be",
  };
  return PERIOD_COLOR_MAP[period];
}

export function getDefaultPeriods(): PriceTrendPeriod[] {
  return ["1d"];
}

export function sortPeriodsChronologically(periods: PriceTrendPeriod[]): PriceTrendPeriod[] {
  const order: PriceTrendPeriod[] = ["1d", "2d", "3d", "4d", "5d", "21d", "63d", "126d", "252d", "504d", "756d", "1260d", "2520d"];
  return [...periods].sort((a, b) => order.indexOf(a) - order.indexOf(b));
}

export function formatPeriodLabel(period: PriceTrendPeriod): string {
  return period.replace("d", "D");
}
