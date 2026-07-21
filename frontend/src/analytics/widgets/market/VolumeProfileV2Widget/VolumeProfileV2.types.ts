export type VolumeProfileV2Level = "sector" | "industry" | "industrySubGroup" | "company";

export interface CompanyOption {
  id: string;
  name: string;
  sector: string;
  industry: string;
  industrySubGroup: string;
  marketCapBucket: string;
}

export interface VolumeProfileV2Row {
  id: string;
  name: string;
  sector: string;
  industry: string;
  industrySubGroup: string;
  volume: number;
  avgVol1W: number;
  avgVol1M: number;
  avgVol1Y: number;
  relative1W: number | null;
  relative1M: number | null;
  relative1Y: number | null;
  marketCap: number;
  marketCapBucket: string;
  companyCount: number | null;
  rank: number;
  total: number;
}

export type VolumeProfileV2SortMetric =
  | "name"
  | "relative1W"
  | "relative1M"
  | "relative1Y";

export type VolumeProfileV2SortDir = "asc" | "desc";

export type VolumeProfileV2MarketCap = "large" | "mid" | "small" | "";

export type VolumeProfileV2MarketCapBucket =
  | "top 10perc by mcap"
  | "50-90% by mcap"
  | "bottom 50% by mcap"
  | "";

export interface VolumeProfileV2Response {
  level: VolumeProfileV2Level;
  total: number;
  rows: VolumeProfileV2Row[];
}

export interface VolumeProfileV2FilterState {
  sector: string;
  industry: string;
  industrySubGroup: string;
  marketCap: VolumeProfileV2MarketCap;
  marketCapBucket: VolumeProfileV2MarketCapBucket;
  limit: number;
  search: string;
}

export interface VolumeProfileV2DrillState {
  level: VolumeProfileV2Level;
  sector: string;
  industry: string;
  industrySubGroup: string;
}
