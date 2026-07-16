// Domain types shared across the frontend. Aligned with the FastAPI responses
// in `api_server/main.py` and the Postgres schema.

export interface CompanyBasic {
  id: number;
  name: string | null;
  nse_code: string | null;
  bse_code: string | null;
  industry: string | null;
  current_price: number | null;
  market_capitalization: number | null;
  sector: string | null;
}

export interface CompanyMetrics extends CompanyBasic {
  return_on_equity: number | null;
  return_on_assets: number | null;
  debt_to_equity: number | null;
  price_to_earning: number | null;
  promoter_holding: number | null;
  fii_holding: number | null;
  dii_holding: number | null;
}

export interface PricePoint {
  date: string;
  open: number | null;
  high: number | null;
  low: number | null;
  close: number | null;
  volume: number | null;
  adj_close: number | null;
}

export interface MarketOverview {
  total_companies: number;
  total_market_cap: number;
  avg_pe_ratio: number;
  sector_distribution: Record<string, number>;
}

export interface Mover {
  id: number;
  name: string;
  nse_code: string | null;
  current_price: number | null;
  return_1y: number | null;
  volume: number | null;
}

export interface SectorPerformance {
  sector: string;
  avg_return: number;
  total_market_cap: number;
  company_count: number;
}

export interface MarketIndex {
  id: number;
  name: string;
  ticker: string;
  region: string | null;
}

export interface IndexPricePoint {
  date: string;
  open: number | null;
  high: number | null;
  low: number | null;
  close: number | null;
  volume: number | null;
}

// Wide probability table row (subset of the 389 columns). Fully typed access
// is impractical, so we expose the known analytics columns plus an indexer.
export interface ProbabilityRow {
  company_id: string;
  bse_code: number | null;
  nse_code: string | null;
  name: string | null;
  industry: string | null;
  current_price: number | null;
  market_capitalization: number | null;
  [key: string]: unknown;
}

export interface Paginated<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
}

export interface ApiErrorShape {
  detail: string | { msg: string }[];
}
