import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { volumeProfileV2Service } from "@/shared/api/services/volume-profile-v2";
import type { VolumeProfileV2Response } from "./VolumeProfileV2.types";

export interface VolumeProfileV2QueryParams {
  level: string;
  parent?: string;
  sector?: string;
  industry?: string;
  industrySubGroup?: string;
  marketCap?: string;
  marketCapBucket?: string;
  company?: string;
  companyName?: string;
  date?: string;
  sortMetric?: string;
  sortDirection?: string;
  limit?: number;
  offset?: number;
}

export function useVolumeProfileV2(params: VolumeProfileV2QueryParams) {
  const queryParams: Record<string, unknown> = {
    hierarchyLevel: params.level,
    level: params.level,
  };
  if (params.parent) queryParams.parent = params.parent;
  if (params.sector) queryParams.sector = params.sector;
  if (params.industry) queryParams.industry = params.industry;
  if (params.industrySubGroup) queryParams.industrySubGroup = params.industrySubGroup;
  if (params.marketCap) queryParams.marketCap = params.marketCap;
  if (params.marketCapBucket) queryParams.marketCapBucket = params.marketCapBucket;
  if (params.company) queryParams.company = params.company;
  if (params.companyName) queryParams.companyName = params.companyName;
  if (params.date) queryParams.date = params.date;
  if (params.sortMetric) queryParams.sortMetric = params.sortMetric;
  if (params.sortDirection) queryParams.sortDirection = params.sortDirection;
  queryParams.limit = params.limit ?? 50;
  queryParams.offset = params.offset ?? 0;

  return useApiQuery<VolumeProfileV2Response>(
    queryKeys.volumeProfileV2.data(queryParams),
    () => volumeProfileV2Service.data(queryParams),
  );
}

export function useVolumeProfileV2Options(level: string, parent?: string, companyName?: string) {
  const queryParams: Record<string, unknown> = {
    hierarchyLevel: level,
    level,
    limit: 1000,
  };
  if (parent) queryParams.parent = parent;
  if (companyName) queryParams.companyName = companyName;

  return useApiQuery<VolumeProfileV2Response>(
    queryKeys.volumeProfileV2.options(level, parent, companyName),
    () => volumeProfileV2Service.data(queryParams),
    { enabled: level !== "company" || Boolean(companyName) },
  );
}

export function useLatestVolumeProfileV2Date() {
  return useApiQuery<{ date: string | null }>(
    queryKeys.volumeProfileV2.latestDate(),
    () => volumeProfileV2Service.latestDate(),
    { staleTime: 5 * 60_000 },
  );
}
