"use client";

import * as React from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

// Filter state backed by the URL query string. Keeps shareable, bookmarkable
// list views and syncs with browser navigation.
export function useFilters(initial: Record<string, string> = {}) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const filters = React.useMemo(() => {
    const out: Record<string, string> = { ...initial };
    searchParams.forEach((value, key) => {
      out[key] = value;
    });
    return out;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  const commit = React.useCallback(
    (next: Record<string, string>) => {
      const params = new URLSearchParams();
      Object.entries(next).forEach(([k, v]) => {
        if (v !== "" && v != null) params.set(k, v);
      });
      const qs = params.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [pathname, router],
  );

  const setFilter = React.useCallback(
    (key: string, value: string) => {
      commit({ ...filters, [key]: value });
    },
    [commit, filters],
  );

  const setFilters = React.useCallback(
    (patch: Record<string, string>) => {
      commit({ ...filters, ...patch });
    },
    [commit, filters],
  );

  const reset = React.useCallback(() => commit({}), [commit]);

  return { filters, setFilter, setFilters, reset };
}
