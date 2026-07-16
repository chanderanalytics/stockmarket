import { BaseModel, ConfidenceLevel, RiskLevel, SignalStrength, TrendDirection } from './common';

export interface MarketPulse extends BaseModel {
  overallSentiment: 'bullish' | 'bearish' | 'neutral';
  marketRegime: string; // e.g., 'Strong Bull', 'Bull', 'Sideways', etc.
  regimeConfidence: ConfidenceLevel;
  keyDrivers: string[];
  risks: string[];
  outlook: string;
  timestamp: string;
}

export interface MarketBreadth extends BaseModel {
  advanceDeclineRatio: number;
  advanceDeclineLine: number;
  netAdvances: number;
  percentageAbove20DMA: number;
  percentageAbove50DMA: number;
  percentageAbove100DMA: number;
  percentageAbove200DMA: number;
  newHighs: number;
  newLows: number;
  highLowRatio: number;
  breadthMomentum: SignalStrength;
  breadthTrend: TrendDirection;
  breadthThrust: number; // e.g., percentage
  marketParticipationScore: number; // 0-100
  trendConfirmation: boolean;
}

export interface MarketHealth extends BaseModel {
  volatilityIndex: number; // e.g., VIX equivalent
  marketVolatility: 'low' | 'moderate' | 'high';
  liquidityCondition: 'tight' | 'normal' | 'abundant';
  creditSpreads: number; // bps
  yieldCurveSlope: number; // 10y-2y spread
  dollarStrength: 'weak' | 'neutral' | 'strong';
  commodityPrices: 'rising' | 'falling' | 'stable';
}

export interface MarketInternals extends BaseModel {
  putCallRatio: number;
  volatilityTermStructure: string; // e.g., 'contango', 'backwardation'
  marketDepth: number; // proxy
  orderFlowImbalance: number; // -1 to 1
  institutionalFlow: number; // net buying/selling
  retailSentiment: 'bullish' | 'bearish' | 'neutral';
}

export interface MarketRegime extends BaseModel {
  regime:
    | "Strong Bull"
    | "Bull"
    | "Recovering"
    | "Sideways"
    | "Weak"
    | "Bear"
    | "Correction"
    | "High Risk"
    | "Capitulation";
  confidence: ConfidenceLevel;
  confidenceScore: number; // 0-100
  supportingMetrics: { label: string; value: string }[];
  historicalComparison: string;
}

export interface MarketData extends MarketPulse, MarketBreadth, MarketHealth, MarketInternals, MarketRegime {}