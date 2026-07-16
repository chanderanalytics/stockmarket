"use client";

import { useDebounce } from "./use-debounce";
import { useApiQuery } from "./use-api-query";
import { stocksService } from "@/shared/api/services/stocks";
import { queryKeys } from "@/shared/api/query-keys";

// Debounced, react-query-backed stock search for command palettes / pickers.
export function useStockSearch(query: string, enabled = true) {
  const debounced = useDebounce(query, 250);
  return useApiQuery(
    [...queryKeys.stocks.search(debounced)] as unknown[],
    () => stocksService.search(debounced),
    { enabled: enabled && debounced.trim().length > 0, staleTime: 60_000 },
  );
}
