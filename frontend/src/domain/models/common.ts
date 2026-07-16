export type SignalStrength = 'weak' | 'moderate' | 'strong';
export type TrendDirection = 'up' | 'down' | 'sideways';
export type SignalAction = 'buy' | 'sell' | 'hold' | 'strong_buy' | 'strong_sell';
export type ConfidenceLevel = 'low' | 'medium' | 'high';
export type RiskLevel = 'low' | 'medium' | 'high';
export type TimeFrame = 'intraday' | 'daily' | 'weekly' | 'monthly';

export interface Timestamped {
  timestamp: string; // ISO string
}

export interface BaseModel extends Timestamped {
  id: string;
}