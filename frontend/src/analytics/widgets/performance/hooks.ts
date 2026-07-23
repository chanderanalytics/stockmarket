import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { performanceService } from "@/shared/api/services/performance";
import type { CompanyPerformance, TradePerformance, PerformanceSummary, PerformanceFilters } from "./types";

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

export function usePerformanceSummary() {
  return useApiQuery<PerformanceSummary>(
    queryKeys.performance.summary(),
    () => performanceService.summary(),
  );
}

export function useCompanyPerformance(filters?: {
  companyName?: string;
  status?: string;
  limit?: number;
  offset?: number;
}) {
  return useApiQuery<CompanyPerformanceResponse>(
    queryKeys.performance.companies(filters ?? {}),
    () => performanceService.companies(filters),
  );
}

export function useTradePerformance(filters?: {
  company_id?: number;
  companyName?: string;
  status?: string;
  entry_date_from?: string;
  entry_date_to?: string;
  exit_date_from?: string;
  exit_date_to?: string;
  limit?: number;
  offset?: number;
}) {
  return useApiQuery<TradePerformanceResponse>(
    queryKeys.performance.trades(filters ?? {}),
    () => performanceService.trades(filters),
  );
}

export function usePerformanceCompanyDetail(companyId: number) {
  return useApiQuery<CompanyPerformance>(
    queryKeys.performance.companyDetail(companyId),
    () => performanceService.companyDetail(companyId),
    { enabled: Boolean(companyId) },
  );
}

export function usePerformanceTradeDetail(tradeId: string) {
  return useApiQuery<TradePerformance>(
    queryKeys.performance.tradeDetail(tradeId),
    () => performanceService.tradeDetail(tradeId),
    { enabled: Boolean(tradeId) },
  );
}
