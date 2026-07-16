import { BaseModel, SignalStrength, TrendDirection } from "./common";

export interface SectorStrength extends BaseModel {
  sector: string;
  relativeStrength: number; // 0-100 vs market
  momentum: number; // -100..100
  leadership: boolean;
  improving: boolean;
  weakening: boolean;
  rank: number; // 1 = strongest
}

export interface SectorRotation extends BaseModel {
  leaders: string[]; // sector names
  laggards: string[];
  rotatingTo: string[]; // sectors gaining leadership
  rotatingFrom: string[]; // sectors losing leadership
  rotationSignal: "risk_on" | "risk_off" | "neutral";
}

export interface SectorSnapshot extends BaseModel {
  sector: string;
  performance1D: number;
  performance1W: number;
  performance1M: number;
  performance3M: number;
  performanceYTD: number;
  relativeStrength: number; // 0-100
  momentum: number; // -100..100
  participation: number; // 0-100 % of constituents advancing
  volume: number; // sector turnover
  leadership: boolean;
  improving: boolean;
  weakening: boolean;
  rank: number;
  trend: TrendDirection;
  strength: SignalStrength;
  topStocks: string[]; // symbols
  bottomStocks: string[]; // symbols
}
