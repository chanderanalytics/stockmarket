import { api } from "../api-client";

export const indicesService = {
  features: (params?: Record<string, unknown>) =>
    api.get<{
      total: number;
      rows: Array<{
        name: string;
        ticker: string;
        region: string;
        description: string;
        date: string | null;
        open: number | null;
        high: number | null;
        low: number | null;
        close: number | null;
        volume: number | null;
        last_modified: string | null;
        as_of_date: string | null;
        return_1d: number | null;
        return_2d: number | null;
        return_3d: number | null;
        return_4d: number | null;
        return_5d: number | null;
        return_21d: number | null;
        return_63d: number | null;
        return_126d: number | null;
        return_252d: number | null;
        return_504d: number | null;
        return_756d: number | null;
        return_1260d: number | null;
        return_2520d: number | null;
      }>;
      as_of_date: string | null;
    }>("/api/indices/features", { params }),

  latestDate: () => api.get<{ date: string | null }>("/api/indices/features/latest-date"),

  priceHistory: (params?: Record<string, unknown>) =>
    api.get<
      Array<{
        date: string | null;
        open: number | null;
        high: number | null;
        low: number | null;
        close: number | null;
        volume: number | null;
      }>
    >("/api/indices/price-history", { params }),

  regions: () => api.get<string[]>("/api/indices/regions"),

  regionalStrength: (params?: Record<string, unknown>) =>
    api.get<{
      period: string;
      rows: Array<{
        region: string;
        avg_return: number | null;
        index_count: number;
      }>;
    }>("/api/indices/regional-strength", { params }),
};
