// Inputs to the breadth engine. Produced by a data service from the database;
// the engine itself never touches SQL.
export interface BreadthMember {
  symbol: string;
  close: number;
  prevClose: number;
  ma20: number;
  ma50: number;
  ma100: number;
  ma200: number;
  isNewHigh: boolean;
  isNewLow: boolean;
}

export interface BreadthInput {
  members: BreadthMember[];
  priorNetAdvances?: number; // for momentum comparison
}
