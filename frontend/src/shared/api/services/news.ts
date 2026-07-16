import { api } from "../api-client";
import type { NewsItem } from "../types";

export const newsService = {
  list: (params?: Record<string, unknown>) => api.get<NewsItem[]>("/news", { params }),
  bySymbol: (symbol: string) => api.get<NewsItem[]>(`/news/symbol/${symbol}`),
};
