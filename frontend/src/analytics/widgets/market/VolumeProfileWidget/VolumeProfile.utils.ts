import type { StackedBarChartData } from "@/visualization/primitives/charts/types";
import type {
  VolumeProfileLevel,
  VolumeProfileRow,
  VolumeProfileSortMetric,
  VolumeProfileSortDir,
} from "./VolumeProfile.types";

export interface VolumeProfileSeriesDef {
  key: "volume" | "avgVol1W" | "avgVol1M" | "avgVol1Y";
  name: string;
  color: string;
}

export const VOLUME_PROFILE_SERIES: readonly VolumeProfileSeriesDef[] = [
  { key: "volume", name: "Today's Volume", color: "#2563eb" },
  { key: "avgVol1W", name: "Average Volume (1 Week)", color: "#f97316" },
  { key: "avgVol1M", name: "Average Volume (1 Month)", color: "#a855f7" },
  { key: "avgVol1Y", name: "Average Volume (1 Year)", color: "#6366f1" },
];

export const LEVEL_ORDER: readonly VolumeProfileLevel[] = [
  "sector",
  "industry",
  "industrySubGroup",
  "company",
];

export function levelLabel(level: VolumeProfileLevel): string {
  switch (level) {
    case "sector":
      return "Sector";
    case "industry":
      return "Industry";
    case "industrySubGroup":
      return "Industry Sub-Group";
    case "company":
      return "Company";
  }
}

export function nextDrillLevel(level: VolumeProfileLevel): VolumeProfileLevel | null {
  const idx = LEVEL_ORDER.indexOf(level);
  return idx >= 0 && idx < LEVEL_ORDER.length - 1 ? LEVEL_ORDER[idx + 1] : null;
}

export function formatVolume(value: number): string {
  if (!Number.isFinite(value)) return "—";
  const abs = Math.abs(value);
  if (abs >= 1_00_00_000) return `${(value / 1_00_00_000).toFixed(2)}Cr`;
  if (abs >= 1_00_000) return `${(value / 1_00_000).toFixed(2)} Lacs`;
  return new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(value);
}

export function sortRows(
  rows: VolumeProfileRow[],
  metric: VolumeProfileSortMetric,
  dir: VolumeProfileSortDir,
): VolumeProfileRow[] {
  const sorted = [...rows].sort((a, b) => {
    const av = a[metric] as number;
    const bv = b[metric] as number;
    return dir === "asc" ? av - bv : bv - av;
  });
  return sorted;
}

export function mapRowsToChartPayload(rows: VolumeProfileRow[]): StackedBarChartData {
  return {
    categories: rows.map((r) => r.name),
    series: VOLUME_PROFILE_SERIES.map((s) => ({
      key: s.key,
      name: s.name,
      color: s.color,
      data: rows.map((r) => r[s.key] as number),
    })),
    meta: rows.map((r) => ({ ...r })),
  };
}

export const SORT_METRIC_LABELS: Record<VolumeProfileSortMetric, string> = {
  volume: "Current Volume",
  avgVol1W: "AvgVol 1wk",
  avgVol1M: "AvgVol 1m",
  avgVol1Y: "AvgVol 1yr",
};
