export interface SectorMember {
  symbol: string;
  sector: string;
  return1D: number;
  return1W: number;
  return1M: number;
  return3M: number;
  returnYTD: number;
  relativeStrength: number; // vs market, 0-100
  advancing: boolean;
  volume: number;
}

export interface SectorEngineInput {
  members: SectorMember[];
  // Optional market-level return used to derive relative strength.
  marketReturn1M?: number;
}
