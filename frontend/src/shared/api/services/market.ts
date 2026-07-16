import { api } from "../api-client";
import type { MarketIndex, Mover, MarketPulse, MarketBreadth, SectorSnapshot } from "../types";

export const marketService = {
  indices: () => api.get<MarketIndex[]>("/market/indices"),
  movers: () => api.get<{ gainers: Mover[]; losers: Mover[] }>("/market/movers"),
  status: () => api.get<{ open: boolean; asOf: string }>("/market/status"),
  pulse: () => api.get<MarketPulse>("/market/pulse"),
  breadth: () => api.get<MarketBreadth>("/market/breadth"),
  sectors: () => api.get<SectorSnapshot[]>("/market/sectors"),
};
