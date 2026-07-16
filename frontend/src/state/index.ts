// Domain stores (market / portfolio / watchlist) are intentionally not created
// yet. They will be added when the corresponding features land (Milestone 2+),
// following the same pattern as the stores in this folder. Keeping them out
// now avoids speculative state that nothing consumes.
export { useUiStore } from "./ui-store";
export { usePreferencesStore } from "./preferences-store";
export { useFiltersStore, type GlobalFilters } from "./filters-store";
