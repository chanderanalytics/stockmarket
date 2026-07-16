import type {
  MarketPulse,
  MarketBreadth,
  MarketRegime,
  SectorSnapshot,
  StockSnapshot,
  TradingSignal,
  DecisionSummary,
  PortfolioSummary,
  WatchlistSummary,
  TradingOpportunity,
} from "../../models";

// The assembled bundle the Knowledge Engine interprets. Built by the
// KnowledgeRuntime service from Market Intelligence Runtime outputs.
export interface KnowledgeContext {
  pulse: MarketPulse;
  breadth: MarketBreadth;
  regime: MarketRegime;
  sectors: SectorSnapshot[];
  stocks: StockSnapshot[];
  signals: TradingSignal[];
  decision: DecisionSummary;
  opportunities: TradingOpportunity[];
  portfolio?: PortfolioSummary;
  watchlist?: WatchlistSummary;
}
