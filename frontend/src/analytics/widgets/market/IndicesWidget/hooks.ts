import { useQuery } from "@tanstack/react-query";
import { indicesService } from "@/shared/api/services/indices";
import { queryKeys } from "@/shared/api/query-keys";

export function useIndicesFeatures(params?: Record<string, unknown>) {
  return useQuery({
    queryKey: queryKeys.indices.features(params),
    queryFn: async () => {
      return indicesService.features(params);
    },
  });
}

export function useIndicesLatestDate() {
  return useQuery({
    queryKey: queryKeys.indices.latestDate(),
    queryFn: async () => {
      return indicesService.latestDate();
    },
  });
}

export function useIndexPriceHistory(params?: Record<string, unknown>) {
  return useQuery({
    queryKey: queryKeys.indices.priceHistory(params),
    queryFn: async () => {
      return indicesService.priceHistory(params);
    },
    enabled: Boolean(params && (params.name || params.ticker)),
  });
}

export function useIndicesRegions() {
  return useQuery<string[], Error>({
    queryKey: queryKeys.indices.regions(),
    queryFn: async () => {
      return indicesService.regions();
    },
  });
}

export function useIndicesRegionalStrength(params?: Record<string, unknown>) {
  return useQuery({
    queryKey: queryKeys.indices.regionalStrength(params),
    queryFn: async () => {
      return indicesService.regionalStrength(params);
    },
  });
}
