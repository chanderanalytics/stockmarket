// Shared domain types used across API services and UI.

export type Symbol = string;

export interface Stock {
  symbol: string;
  name: string;
  exchange: string;
  sector?: string;
  industry?: string;
  marketCap?: number;
}

export interface Quote {
  symbol: string;
  lastPrice: number;
  change: number;
  changePct: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  updatedAt: string;
}

export interface Candle {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface MarketIndex {
  name: string;
  value: number;
  change: number;
  changePct: number;
}

export interface Mover {
  symbol: string;
  name: string;
  lastPrice: number;
  changePct: number;
}

export interface NewsItem {
  id: string;
  title: string;
  summary: string;
  source: string;
  url: string;
  publishedAt: string;
  symbols?: string[];
}

export interface WatchlistItem {
  symbol: string;
  addedAt: string;
}

export interface Watchlist {
  id: string;
  watchlistId?: string;
  name: string;
  itemCount: number;
  overallTrend: string;
  advancers: number;
  decliners: number;
  strongest: string;
  weakest: string;
  avgChangePercent: number;
  alerts: unknown[];
  items: WatchlistItem[];
}

export interface ScreenerFilters {
  minPrice?: number;
  maxPrice?: number;
  minMarketCap?: number;
  sector?: string;
  minChangePct?: number;
  maxChangePct?: number;
  minVolume?: number;
  [key: string]: unknown;
}

export interface Holding {
  symbol: string;
  quantity: number;
  avgPrice: number;
  lastPrice: number;
  pnl: number;
  pnlPct: number;
}

export interface Portfolio {
  id: string;
  portfolioId: string;
  name: string;
  totalValue: number;
  dayChange: number;
  dayChangePercent: number;
  totalPnl: number;
  totalPnlPercent: number;
  cash: number;
  invested: number;
  exposure: number;
  holdingsCount: number;
  beta: number;
  sharpeRatio: number;
  maxDrawdown: number;
  diversificationScore: number;
  topSectors: string[];
  worstSectors: string[];
}

export interface User {
  id: string;
  name: string;
  email: string;
}

export interface AuthResponse {
  user: User;
  token: string;
}

export interface MarketPulse {
  id: string;
  timestamp: string;
  overallSentiment: "bullish" | "bearish" | "neutral";
  marketRegime: string;
  regimeConfidence: string;
  keyDrivers: string[];
  risks: string[];
  outlook: string;
}

export interface MarketBreadth {
  marketParticipationScore: number;
  percentageAbove50DMA: number;
  percentageAbove200DMA: number;
  netAdvances: number;
  breadthTrend: string;
  breadthMomentum: string;
  newHighs: number;
  newLows: number;
  advanceDeclineRatio: number;
}

export interface SectorSnapshot {
  sector: string;
  companyCount: number;
  totalMarketCap: number;
  avgReturn: number;
  participation: number;
  leadership: boolean;
  weakening: boolean;
  rank: number;
}
