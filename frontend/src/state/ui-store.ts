"use client";

import { create } from "zustand";

// UI state: transient chrome state (sidebar, command palette, mobile nav).
// Deliberately separate from domain/filter state so it can be reset independently.
interface UiState {
  sidebarCollapsed: boolean;
  mobileNavOpen: boolean;
  commandOpen: boolean;
  toggleSidebar: () => void;
  setSidebarCollapsed: (v: boolean) => void;
  setMobileNavOpen: (v: boolean) => void;
  setCommandOpen: (v: boolean) => void;
}

export const useUiStore = create<UiState>((set) => ({
  sidebarCollapsed: false,
  mobileNavOpen: false,
  commandOpen: false,
  toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
  setSidebarCollapsed: (v) => set({ sidebarCollapsed: v }),
  setMobileNavOpen: (v) => set({ mobileNavOpen: v }),
  setCommandOpen: (v) => set({ commandOpen: v }),
}));
