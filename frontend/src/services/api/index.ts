"use client";

import { createApiClient, type ApiClient } from "./client";
import type {
  CompanyBasic,
  CompanyMetrics,
  MarketOverview,
  MarketIndex,
  Mover,
  PricePoint,
  SectorPerformance,
  IndexPricePoint,
  ProbabilityRow,
} from "@/types";

const BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

// Token storage is auth-ready: swap this for your real auth flow later.
const TOKEN_KEY = "sm_token";

function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(TOKEN_KEY);
}

function setToken(token: string | null) {
  if (typeof window === "undefined") return;
  if (token) window.localStorage.setItem(TOKEN_KEY, token);
  else window.localStorage.removeItem(TOKEN_KEY);
}

export const apiClient: ApiClient = createApiClient({
  baseURL: BASE_URL,
  getToken,
  maxRetries: 2,
  retryDelayMs: 400,
});

// Attach auth header on every request.
apiClient.useRequestInterceptor((init) => {
  const token = getToken();
  if (!token) return init;
  return {
    ...init,
    headers: {
      ...(init.headers as Record<string, string>),
      Authorization: `Bearer ${token}`,
    },
  };
});

export { setToken, getToken, TOKEN_KEY };

// ---------------------------------------------------------------------------
// Typed endpoints (Milestone 1, Task 9 deliverable: `shared/api`).
// Each returns a typed payload; TanStack Query hooks wrap these in `hooks/`.
// ---------------------------------------------------------------------------

export const api = {
  // Companies
  getCompanies: (params?: { skip?: number; limit?: number; sector?: string; industry?: string }) =>
    apiClient.get<CompanyBasic[]>("/api/companies", params),
  getCompany: (id: number) => apiClient.get<CompanyMetrics>(`/api/companies/${id}`),
  getCompanyPrices: (id: number, params?: { start_date?: string; end_date?: string }) =>
    apiClient.get<PricePoint[]>(`/api/companies/${id}/prices`, params),

  // Market
  getMarketOverview: () => apiClient.get<MarketOverview>("/api/market/overview"),
  getTopGainers: (limit = 10) => apiClient.get<Mover[]>("/api/market/top-gainers", { limit }),
  getTopLosers: (limit = 10) => apiClient.get<Mover[]>("/api/market/top-losers", { limit }),
  getHighVolume: (limit = 10) => apiClient.get<Mover[]>("/api/market/high-volume", { limit }),
  getSectorPerformance: () => apiClient.get<SectorPerformance[]>("/api/sectors/performance"),

  // Indices
  getIndices: () => apiClient.get<MarketIndex[]>("/api/indices"),
  getIndexPrices: (id: number, params?: { start_date?: string; end_date?: string }) =>
    apiClient.get<IndexPricePoint[]>(`/api/indices/${id}/prices`, params),

  // Wide analytics tables (used by Probability / Drilldown views).
  // `table` is one of the merged_*_probabilities_wide tables.
  getProbabilityTable: (table: string, params?: { limit?: number; industry?: string }) =>
    apiClient.get<ProbabilityRow[]>(`/api/analytics/${table}`, params),
};
