import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { volumeProfileService } from "@/shared/api/services";
import type { VolumeProfileResponse } from "./VolumeProfile.types";

export interface VolumeProfileQueryParams {
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

export function useVolumeProfile(params: VolumeProfileQueryParams) {
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

  return useApiQuery<VolumeProfileResponse>(
    queryKeys.volumeProfile.data(queryParams),
    () => volumeProfileService.data(queryParams),
  );
}

// Fetch the list of valid values for a given hierarchy level, used to populate
// the Sector / Industry / Sub-Group filter dropdowns. When `companyName` is
// provided (company level search), the backend returns matching companies
// together with their sector / industry / sub-group classification.
export function useVolumeProfileOptions(level: string, parent?: string, companyName?: string) {
  const queryParams: Record<string, unknown> = {
    hierarchyLevel: level,
    level,
    limit: 1000,
  };
  if (parent) queryParams.parent = parent;
  if (companyName) queryParams.companyName = companyName;

  return useApiQuery<VolumeProfileResponse>(
    queryKeys.volumeProfile.options(level, parent, companyName),
    () => volumeProfileService.data(queryParams),
    { enabled: level !== "company" || Boolean(companyName) },
  );
}

export function useLatestVolumeProfileDate() {
  return useApiQuery<{ date: string | null }>(
    queryKeys.volumeProfile.latestDate(),
    () => volumeProfileService.latestDate(),
    { staleTime: 5 * 60_000 },
  );
}
