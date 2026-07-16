export type VolumeProfileLevel = "sector" | "industry" | "industrySubGroup" | "company";

export interface CompanyOption {
  id: string;
  name: string;
  sector: string;
  industry: string;
  industrySubGroup: string;
  marketCapBucket: string;
}

export interface VolumeProfileRow {
  id: string;
  name: string;
  sector: string;
  industry: string;
  industrySubGroup: string;
  volume: number;
  avgVol1W: number;
  avgVol1M: number;
  avgVol1Y: number;
  volSortPct: number;
  marketCap: number;
  marketCapBucket: string;
  companyCount: number | null;
  rank: number;
  total: number;
}

export type VolumeProfileSortMetric =
  | "volume"
  | "avgVol1W"
  | "avgVol1M"
  | "avgVol1Y";

export type VolumeProfileSortDir = "asc" | "desc";

export type VolumeProfileMarketCap = "large" | "mid" | "small" | "";

export type VolumeProfileMarketCapBucket =
  | "top 10perc by mcap"
  | "50-90% by mcap"
  | "bottom 50% by mcap"
  | "";

export interface VolumeProfileResponse {
  level: VolumeProfileLevel;
  total: number;
  rows: VolumeProfileRow[];
}

export interface VolumeProfileFilterState {
  sector: string;
  industry: string;
  industrySubGroup: string;
  marketCap: VolumeProfileMarketCap;
  marketCapBucket: VolumeProfileMarketCapBucket;
  limit: number;
  search: string;
}

export interface VolumeProfileDrillState {
  level: VolumeProfileLevel;
  sector: string;
  industry: string;
  industrySubGroup: string;
}
