import { api } from "@/shared/api/api-client";
import type { CompanyPerformance, TradePerformance, PerformanceSummary } from "@/analytics/widgets/performance/types";

export const performanceService = {
  summary: () =>
    api.get<PerformanceSummary>("/performance/summary"),

  companies: (params?: { status?: string; company_id?: number }) =>
    api.get<CompanyPerformance[]>("/performance/companies", { params }),

  trades: (params?: { company_id?: number; status?: string; entry_date?: string }) =>
    api.get<TradePerformance[]>("/performance/trades", { params }),

  companyDetail: (companyId: number) =>
    api.get<CompanyPerformance>(`/performance/companies/${companyId}`),

  tradeDetail: (tradeId: string) =>
    api.get<TradePerformance>(`/performance/trades/${tradeId}`),
};
