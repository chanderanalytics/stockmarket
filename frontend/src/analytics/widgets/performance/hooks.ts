import { useApiQuery } from "@/shared/hooks";
import { performanceService } from "@/shared/api/services/performance";
import type { CompanyPerformance, TradePerformance, PerformanceSummary, PerformanceFilters } from "./types";

export function usePerformanceSummary(filters?: PerformanceFilters) {
  return useApiQuery<PerformanceSummary>(
    ["performance", "summary", filters],
    () => performanceService.summary(),
  );
}

export function useCompanyPerformance(filters?: PerformanceFilters) {
  return useApiQuery<CompanyPerformance[]>(
    ["performance", "companies", filters],
    () => performanceService.companies(filters),
  );
}

export function useTradePerformance(filters?: PerformanceFilters) {
  return useApiQuery<TradePerformance[]>(
    ["performance", "trades", filters],
    () => performanceService.trades(filters),
  );
}

export function usePerformanceCompanyDetail(companyId: number) {
  return useApiQuery<CompanyPerformance>(
    ["performance", "company", companyId],
    () => performanceService.companyDetail(companyId),
    { enabled: Boolean(companyId) },
  );
}

export function usePerformanceTradeDetail(tradeId: string) {
  return useApiQuery<TradePerformance>(
    ["performance", "trade", tradeId],
    () => performanceService.tradeDetail(tradeId),
    { enabled: Boolean(tradeId) },
  );
}
