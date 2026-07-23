export type PriceTrendPeriod = "1d" | "2d" | "3d" | "4d" | "5d" | "21d" | "63d" | "126d" | "252d" | "504d" | "756d" | "1260d" | "2520d";
export type PriceTrendSortMetric = PriceTrendPeriod | "name" | "marketCap" | "count" | "sector";
export type PriceTrendSortDir = "asc" | "desc";
export type PriceTrendMarketCap = "" | "large" | "mid" | "small";
export type PriceTrendMarketCapBucket = "" | "top 10perc by mcap" | "50-90% by mcap" | "bottom 50% by mcap";

export interface PriceTrendResponse {
  level: "company";
  periods: string[];
  total: number;
  rows: Array<{
    id: string;
    name: string;
    sector: string;
    industry: string;
    industrySubGroup: string;
    marketCap: number;
    marketCapBucket: string;
    [period: string]: string | number | null;
  }>;
}
