import { api } from "../api-client";
import type { Candle, Quote, Stock } from "../types";

export const stocksService = {
  list: (params?: Record<string, unknown>) => api.get<Stock[]>("/stocks", { params }),
  search: (q: string) => api.get<Stock[]>("/stocks/search", { params: { q } }),
  get: (symbol: string) => api.get<Stock>(`/stocks/${symbol}`),
  quote: (symbol: string) => api.get<Quote>(`/stocks/${symbol}/quote`),
  candles: (symbol: string, range = "1D") =>
    api.get<Candle[]>(`/stocks/${symbol}/candles`, { params: { range } }),
  snapshot: (symbol: string) => api.get<Stock & { prices: Candle[] }>(`/stocks/${symbol}/snapshot`),
};
