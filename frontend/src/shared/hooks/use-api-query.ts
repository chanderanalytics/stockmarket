"use client";

import { useQuery, type UseQueryOptions, type UseQueryResult } from "@tanstack/react-query";

// Thin wrapper around react-query with sensible defaults for GET requests.
export function useApiQuery<TData, TError = Error>(
  queryKey: readonly unknown[],
  queryFn: () => Promise<TData>,
  options?: Omit<UseQueryOptions<TData, TError>, "queryKey" | "queryFn">,
): UseQueryResult<TData, TError> {
  return useQuery<TData, TError>({
    queryKey,
    queryFn,
    staleTime: 30_000,
    refetchOnWindowFocus: false,
    retry: 1,
    ...options,
  });
}
