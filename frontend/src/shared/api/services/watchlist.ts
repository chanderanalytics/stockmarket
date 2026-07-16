import { api } from "../api-client";
import type { Watchlist, WatchlistItem } from "../types";

export const watchlistService = {
  list: () => api.get<Watchlist>("/watchlist"),
};
