import { api } from "@/shared/api/api-client";
import type { CompanyPerformance, TradePerformance, PerformanceSummary } from "@/analytics/widgets/performance/types";

export interface CompanyPerformanceResponse {
  rows: CompanyPerformance[];
  total: number;
  limit: number;
  offset: number;
}

export interface TradePerformanceResponse {
  rows: TradePerformance[];
  total: number;
  limit: number;
  offset: number;
}

export const performanceService = {
  summary: () =>
    api.get<PerformanceSummary>("/performance/summary"),

  companies: (params?: Record<string, unknown>) =>
    api.get<CompanyPerformanceResponse>("/performance/companies", { params }),

  trades: (params?: Record<string, unknown>) =>
    api.get<TradePerformanceResponse>("/performance/trades", { params }),

  companyDetail: (companyId: number) =>
    api.get<CompanyPerformance>(`/performance/companies/${companyId}`),

  tradeDetail: (tradeId: string) =>
    api.get<TradePerformance>(`/performance/trades/${tradeId}`),
};
