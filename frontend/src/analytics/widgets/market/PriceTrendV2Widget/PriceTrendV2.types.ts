export type PriceTrendV2Period = "1d" | "2d" | "3d" | "4d" | "5d" | "21d" | "63d" | "126d" | "252d" | "504d" | "756d" | "1260d" | "2520d";
export type PriceTrendV2SortMetric = PriceTrendV2Period | "name" | "marketCap" | "weightedMarketCap" | "count";
export type PriceTrendV2SortDir = "asc" | "desc";
export type PriceTrendV2MarketCap = "" | "large" | "mid" | "small";
export type PriceTrendV2MarketCapBucket = "" | "top 10perc by mcap" | "50-90% by mcap" | "bottom 50% by mcap";
export type PriceTrendV2Level = "sector" | "industry" | "industrySubGroup" | "company";

export interface PriceTrendV2Response {
  level: PriceTrendV2Level;
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
