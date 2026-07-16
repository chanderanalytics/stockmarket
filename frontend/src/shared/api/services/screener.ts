import { api } from "../api-client";
import type { ScreenerFilters, Stock } from "../types";

export const screenerService = {
  run: (filters: ScreenerFilters) => api.get<Stock[]>("/screener", { params: filters as Record<string, unknown> }),
  saved: () => api.get<{ id: string; name: string; filters: ScreenerFilters }[]>("/screener/saved"),
  save: (name: string, filters: ScreenerFilters) =>
    api.post<{ id: string }>("/screener/saved", { name, filters }),
};
