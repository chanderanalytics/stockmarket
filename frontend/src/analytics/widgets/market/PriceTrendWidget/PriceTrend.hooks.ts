import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { priceTrendService } from "@/shared/api/services";
import type { PriceTrendResponse, PriceTrendPeriod, PriceTrendSortMetric, PriceTrendSortDir } from "./PriceTrend.types";
import { getDefaultPeriods } from "./PriceTrend.utils";

export interface PriceTrendQueryParams {
  date?: string;
  sector?: string;
  industry?: string;
  industrySubGroup?: string;
  marketCap?: string;
  marketCapBucket?: string;
  rank?: string;
  company?: string;
  companyName?: string;
  selectedPeriods?: PriceTrendPeriod[];
  sortMetric?: PriceTrendSortMetric;
  sortDirection?: PriceTrendSortDir;
  limit?: number;
  offset?: number;
}

export function usePriceTrend(params: PriceTrendQueryParams) {
  const queryParams: Record<string, unknown> = {};
  if (params.date) queryParams.date = params.date;
  if (params.sector) queryParams.sector = params.sector;
  if (params.industry) queryParams.industry = params.industry;
  if (params.industrySubGroup) queryParams.industrySubGroup = params.industrySubGroup;
  if (params.marketCap) queryParams.marketCap = params.marketCap;
  if (params.marketCapBucket) queryParams.marketCapBucket = params.marketCapBucket;
  if (params.rank) queryParams.rank = params.rank;
  if (params.company) queryParams.company = params.company;
  if (params.companyName) queryParams.companyName = params.companyName;

  const effectiveSelectedPeriods = params.selectedPeriods && params.selectedPeriods.length
    ? params.selectedPeriods
    : getDefaultPeriods();
  if (effectiveSelectedPeriods.length) queryParams.selectedPeriods = effectiveSelectedPeriods;

  if (params.sortMetric) queryParams.sortMetric = params.sortMetric;
  if (params.sortDirection) queryParams.sortDirection = params.sortDirection;
  queryParams.limit = params.limit ?? 50;
  queryParams.offset = params.offset ?? 0;

  return useApiQuery<PriceTrendResponse>(
    queryKeys.priceTrend.data(queryParams),
    () => priceTrendService.data(queryParams),
  );
}

export function useLatestPriceTrendDate() {
  return useApiQuery<{ date: string | null }>(
    queryKeys.priceTrend.latestDate(),
    () => priceTrendService.latestDate(),
    { staleTime: 5 * 60_000 },
  );
}
