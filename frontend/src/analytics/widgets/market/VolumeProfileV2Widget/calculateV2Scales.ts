import type { VolumeProfileV2Row } from "./VolumeProfileV2.types";

export interface V2Scale {
  metric: "relative1W" | "relative1M" | "relative1Y";
  maxAbs: number;
}

const METRIC_KEYS = ["relative1W", "relative1M", "relative1Y"] as const;

export function calculateV2Scales(rows: VolumeProfileV2Row[]): Map<string, V2Scale> {
  const scales = new Map<string, V2Scale>();

  for (const key of METRIC_KEYS) {
    let maxAbs = 0;
    for (const row of rows) {
      const v = typeof row[key] === "number" ? row[key] : NaN;
      if (Number.isFinite(v)) maxAbs = Math.max(maxAbs, Math.abs(v));
    }
    maxAbs = maxAbs || 1;
    scales.set(key, { metric: key, maxAbs });
  }

  return scales;
}
