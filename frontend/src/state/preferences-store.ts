"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";

// User preferences: persisted across sessions (favorites, recently visited pages).
interface PreferencesState {
  favorites: string[];
  recent: string[];
  toggleFavorite: (href: string) => void;
  pushRecent: (href: string) => void;
  isFavorite: (href: string) => boolean;
}

const MAX_RECENT = 8;

export const usePreferencesStore = create<PreferencesState>()(
  persist(
    (set, get) => ({
      favorites: [],
      recent: [],
      toggleFavorite: (href) =>
        set((s) => ({
          favorites: s.favorites.includes(href)
            ? s.favorites.filter((h) => h !== href)
            : [...s.favorites, href],
        })),
      pushRecent: (href) =>
        set((s) => ({
          recent: [href, ...s.recent.filter((h) => h !== href)].slice(0, MAX_RECENT),
        })),
      isFavorite: (href) => get().favorites.includes(href),
    }),
    { name: "sm-preferences" }
  )
);
