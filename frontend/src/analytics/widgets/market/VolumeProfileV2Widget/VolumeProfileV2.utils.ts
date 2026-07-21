import type { VolumeProfileV2Row, VolumeProfileV2Level, VolumeProfileV2SortMetric, VolumeProfileV2SortDir } from "./VolumeProfileV2.types";
import type { StackedBarChartData } from "@/visualization/primitives/charts/types";

export interface VolumeProfileV2SeriesDef {
  key: "relative1W" | "relative1M" | "relative1Y";
  name: string;
  color: string;
}

export const VOLUME_PROFILE_V2_SERIES: readonly VolumeProfileV2SeriesDef[] = [
  { key: "relative1W", name: "Relative (1 Week)", color: "#2563eb" },
  { key: "relative1M", name: "Relative (1 Month)", color: "#f97316" },
  { key: "relative1Y", name: "Relative (1 Year)", color: "#a855f7" },
];

export const LEVEL_ORDER: readonly VolumeProfileV2Level[] = [
  "sector",
  "industry",
  "industrySubGroup",
  "company",
];

export function levelLabel(level: VolumeProfileV2Level): string {
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

export function nextDrillLevel(level: VolumeProfileV2Level): VolumeProfileV2Level | null {
  const idx = LEVEL_ORDER.indexOf(level);
  return idx >= 0 && idx < LEVEL_ORDER.length - 1 ? LEVEL_ORDER[idx + 1] : null;
}

export function formatVolume(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return "—";
  const abs = Math.abs(value);
  if (abs >= 1_00_00_000) return `${(value / 1_00_00_000).toFixed(2)}Cr`;
  if (abs >= 1_00_000) return `${(value / 1_00_000).toFixed(2)} Lacs`;
  return new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(value);
}

export function formatRelative(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return "—";
  return `${value.toFixed(2)}×`;
}

export function sortRows(
  rows: VolumeProfileV2Row[],
  metric: VolumeProfileV2SortMetric,
  dir: VolumeProfileV2SortDir,
): VolumeProfileV2Row[] {
  const sorted = [...rows].sort((a, b) => {
    const av = a[metric];
    const bv = b[metric];
    const avv = typeof av === "number" ? av : 0;
    const bvv = typeof bv === "number" ? bv : 0;
    return dir === "asc" ? avv - bvv : bvv - avv;
  });
  return sorted;
}

export function mapRowsToChartPayload(rows: VolumeProfileV2Row[]): StackedBarChartData {
  return {
    categories: rows.map((r) => r.name),
    series: VOLUME_PROFILE_V2_SERIES.map((s) => ({
      key: s.key,
      name: s.name,
      color: s.color,
      data: rows.map((r) => (typeof r[s.key] === "number" ? r[s.key] : 0)),
    })),
    meta: rows.map((r) => ({ ...r })),
  };
}

export const SORT_METRIC_LABELS: Record<VolumeProfileV2SortMetric, string> = {
  name: "Name",
  relative1W: "Relative 1W",
  relative1M: "Relative 1M",
  relative1Y: "Relative 1Y",
};
