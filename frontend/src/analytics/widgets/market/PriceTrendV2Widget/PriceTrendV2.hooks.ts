import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { priceTrendV2Service } from "@/shared/api/services/price-trends-v2";
import type { PriceTrendV2Response, PriceTrendV2Period, PriceTrendV2SortMetric, PriceTrendV2SortDir } from "./PriceTrendV2.types";
import { getDefaultPeriods } from "./PriceTrendV2.utils";

export interface PriceTrendV2QueryParams {
  date?: string;
  sector?: string;
  industry?: string;
  industrySubGroup?: string;
  marketCap?: string;
  marketCapBucket?: string;
  rank?: string;
  company?: string;
  companyName?: string;
  selectedPeriods?: PriceTrendV2Period[];
  sortMetric?: PriceTrendV2SortMetric;
  sortDirection?: PriceTrendV2SortDir;
  limit?: number;
  offset?: number;
  hierarchyLevel?: string;
}

export function usePriceTrendV2(params: PriceTrendV2QueryParams) {
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
  if (params.hierarchyLevel) queryParams.hierarchyLevel = params.hierarchyLevel;

  const effectiveSelectedPeriods = params.selectedPeriods && params.selectedPeriods.length
    ? params.selectedPeriods
    : getDefaultPeriods();
  if (effectiveSelectedPeriods.length) queryParams.selectedPeriods = effectiveSelectedPeriods;

  if (params.sortMetric) queryParams.sortMetric = params.sortMetric;
  if (params.sortDirection) queryParams.sortDirection = params.sortDirection;
  queryParams.limit = params.limit ?? 50;
  queryParams.offset = params.offset ?? 0;

  return useApiQuery<PriceTrendV2Response>(
    queryKeys.priceTrendV2.data(queryParams),
    () => priceTrendV2Service.data(queryParams),
  );
}

export function useLatestPriceTrendV2Date() {
  return useApiQuery<{ date: string | null }>(
    queryKeys.priceTrendV2.latestDate(),
    () => priceTrendV2Service.latestDate(),
    { staleTime: 5 * 60_000 },
  );
}
