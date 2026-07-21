import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { marketBreadthService } from "@/shared/api/services/market-breadth";
import type {
  BreadthSummary,
  BreadthDistribution,
  BreadthResponse,
  BreadthHistoryResponse,
  BreadthHorizon,
  BreadthSignalType,
  BreadthSortMetric,
  BreadthSortDir,
} from "./types";

export interface BreadthQueryParams {
  horizons?: BreadthHorizon[];
  signalType?: BreadthSignalType;
  sector?: string;
  industry?: string;
  industrySubGroup?: string;
  marketCap?: string;
  marketCapBucket?: string;
  companyName?: string;
  sortBy?: BreadthSortMetric;
  sortDirection?: BreadthSortDir;
  limit?: number;
  offset?: number;
}

function buildParams(params?: BreadthQueryParams): Record<string, unknown> {
  const q: Record<string, unknown> = {};
  if (params?.horizons?.length) q.horizons = params.horizons;
  if (params?.signalType) q.signalType = params.signalType;
  if (params?.sector) q.sector = params.sector;
  if (params?.industry) q.industry = params.industry;
  if (params?.industrySubGroup) q.industrySubGroup = params.industrySubGroup;
  if (params?.marketCap) q.marketCap = params.marketCap;
  if (params?.marketCapBucket) q.marketCapBucket = params.marketCapBucket;
  if (params?.companyName) q.companyName = params.companyName;
  if (params?.sortBy) q.sortBy = params.sortBy;
  if (params?.sortDirection) q.sortDirection = params.sortDirection;
  if (params?.limit != null) q.limit = params.limit;
  if (params?.offset != null) q.offset = params.offset;
  return q;
}

export function useBreadthSummary(params?: Omit<BreadthQueryParams, "sortBy" | "sortDirection" | "limit" | "offset">) {
  const q = buildParams(params);
  return useApiQuery<BreadthSummary>(
    queryKeys.marketBreadth.summary(q),
    () => marketBreadthService.summary(q),
    { staleTime: 5 * 60_000 },
  );
}

export function useBreadthDistribution(params?: { horizons?: BreadthHorizon[]; marketCap?: string; marketCapBucket?: string; companyName?: string }) {
  const q: Record<string, unknown> = {};
  if (params?.horizons?.length) q.horizons = params.horizons;
  if (params?.marketCap) q.marketCap = params.marketCap;
  if (params?.marketCapBucket) q.marketCapBucket = params.marketCapBucket;
  if (params?.companyName) q.companyName = params.companyName;
  return useApiQuery<BreadthDistribution>(
    queryKeys.marketBreadth.distribution(q),
    () => marketBreadthService.distribution(q),
    { staleTime: 5 * 60_000 },
  );
}

export function useBreadthSectors(params?: BreadthQueryParams) {
  const q = buildParams(params);
  return useApiQuery<BreadthResponse>(
    queryKeys.marketBreadth.sectors(q),
    () => marketBreadthService.sectors(q),
  );
}

export function useBreadthIndustries(params?: BreadthQueryParams) {
  const q = buildParams(params);
  if (params?.industry) q.industryGroup = params.industry;
  return useApiQuery<BreadthResponse>(
    queryKeys.marketBreadth.industries(q),
    () => marketBreadthService.industries(q),
  );
}

export function useBreadthCompanies(params?: BreadthQueryParams) {
  const q = buildParams(params);
  return useApiQuery<BreadthResponse>(
    queryKeys.marketBreadth.companies(q),
    () => marketBreadthService.companies(q),
  );
}

export function useBreadthSubgroups(params?: BreadthQueryParams) {
  const q = buildParams(params);
  return useApiQuery<BreadthResponse>(
    queryKeys.marketBreadth.subgroups(q),
    () => marketBreadthService.subgroups(q),
  );
}

export function useBreadthHistory(params?: { period?: string; horizons?: BreadthHorizon[]; marketCap?: string; marketCapBucket?: string; companyName?: string }) {
  const q: Record<string, unknown> = {};
  if (params?.period) q.period = params.period;
  if (params?.horizons?.length) q.horizons = params.horizons;
  if (params?.marketCap) q.marketCap = params.marketCap;
  if (params?.marketCapBucket) q.marketCapBucket = params.marketCapBucket;
  if (params?.companyName) q.companyName = params.companyName;
  return useApiQuery<BreadthHistoryResponse>(
    queryKeys.marketBreadth.history(q),
    () => marketBreadthService.history(q),
    { staleTime: 10 * 60_000 },
  );
}
