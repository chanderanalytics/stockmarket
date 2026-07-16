import { BaseModel, ConfidenceLevel, RiskLevel, SignalStrength, TrendDirection, SignalAction } from './common';

export interface StockSnapshot extends BaseModel {
  symbol: string;
  name: string;
  exchange: string;
  sector: string;
  industry: string;
  currentPrice: number;
  priceChange: number;
  priceChangePercent: number;
  marketCap: number;
  volume: number;
  avgVolume: number;
  peRatio?: number;
  pbRatio?: number;
  dividendYield?: number;
  dayHigh: number;
  dayLow: number;
  week52High: number;
  week52Low: number;
}

export interface StockTrend extends BaseModel {
  symbol: string;
  priceTrend: TrendDirection;
  trendStrength: SignalStrength;
  movingAverages: {
    ma20: number;
    ma50: number;
    ma100: number;
    ma200: number;
    priceVsMA20: number; // percentage
    priceVsMA50: number;
    priceVsMA100: number;
    priceVsMA200: number;
  };
  momentum: number; // e.g., RSI or similar
  volatility: number; // annualized %
  supportLevel: number;
  resistanceLevel: number;
}

export interface StockMomentum extends BaseModel {
  symbol: string;
  momentumScore: number; // 0-100
  relativeStrength: number; // vs sector or market
  earningsMomentum: number;
  priceMomentum: number; // e.g., 12-1 month return
  volumeTrend: 'increasing' | 'decreasing' | 'stable';
  institutionalInterest: 'accumulation' | 'distribution' | 'neutral';
}

export interface TradingOpportunity extends BaseModel {
  symbol: string;
  opportunityType: 'breakout' | 'breakdown' | 'pullback' | 'bounce';
  entryPrice: number;
  targetPrice: number;
  stopLoss: number;
  riskRewardRatio: number;
  probabilityOfSuccess: number; // 0-100
  horizon: 'short' | 'medium' | 'long'; // days/weeks/months
  catalyst: string;
}