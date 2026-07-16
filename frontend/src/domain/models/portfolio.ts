import { BaseModel, RiskLevel, TrendDirection } from "./common";

export interface PortfolioSummary extends BaseModel {
  portfolioId: string;
  name: string;
  totalValue: number;
  dayChange: number;
  dayChangePercent: number;
  totalPnl: number;
  totalPnlPercent: number;
  cash: number;
  invested: number;
  exposure: number; // percent of capital deployed
  holdingsCount: number;
  beta: number;
  sharpeRatio: number;
  maxDrawdown: number;
  diversificationScore: number; // 0-100
  topSectors: string[];
  worstSectors: string[];
}

export interface PortfolioRisk extends BaseModel {
  portfolioId: string;
  overallRisk: RiskLevel;
  riskScore: number; // 0-100
  volatility: number; // annualized %
  valueAtRisk: number; // currency, 95% 1-day
  concentrationRisk: number; // 0-100
  sectorExposure: Record<string, number>; // sector -> percent
  correlationRisk: number; // 0-100
  liquidityRisk: number; // 0-100
  stressScenario: {
    marketDrop10: number; // projected portfolio impact
    marketDrop20: number;
    rateUp100bps: number;
  };
  hedgeRecommendation: string;
}
