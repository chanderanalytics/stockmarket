"use client";

import { create } from "zustand";

// Global filters: shared across views (e.g. Market Pulse, Breadth, Sectors).
// Views subscribe to this store instead of holding their own filter state,
// so filters persist as the user navigates between related pages.
export interface GlobalFilters {
  search: string;
  sector: string | null;
  industry: string | null;
  marketCapMin: number | null;
  marketCapMax: number | null;
  dateRange: { from: string | null; to: string | null };
}

interface FiltersState extends GlobalFilters {
  setSearch: (v: string) => void;
  setSector: (v: string | null) => void;
  setIndustry: (v: string | null) => void;
  setMarketCap: (min: number | null, max: number | null) => void;
  setDateRange: (from: string | null, to: string | null) => void;
  reset: () => void;
}

const initial: GlobalFilters = {
  search: "",
  sector: null,
  industry: null,
  marketCapMin: null,
  marketCapMax: null,
  dateRange: { from: null, to: null },
};

export const useFiltersStore = create<FiltersState>((set) => ({
  ...initial,
  setSearch: (v) => set({ search: v }),
  setSector: (v) => set({ sector: v }),
  setIndustry: (v) => set({ industry: v }),
  setMarketCap: (min, max) => set({ marketCapMin: min, marketCapMax: max }),
  setDateRange: (from, to) => set({ dateRange: { from, to } }),
  reset: () => set(initial),
}));
