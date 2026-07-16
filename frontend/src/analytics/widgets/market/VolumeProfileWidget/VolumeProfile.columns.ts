import type { VolumeProfileRow } from "./VolumeProfile.types";
import { formatVolume } from "./VolumeProfile.utils";

export interface VolumeProfileColumn {
  key: keyof VolumeProfileRow;
  header: string;
  align: "left" | "right";
  render?: (row: VolumeProfileRow) => string;
}

export const VOLUME_PROFILE_COLUMNS: readonly VolumeProfileColumn[] = [
  { key: "rank", header: "#", align: "right" },
  { key: "name", header: "Entity", align: "left" },
  { key: "sector", header: "Sector", align: "left" },
  { key: "industry", header: "Industry", align: "left" },
  { key: "industrySubGroup", header: "Sub-Group", align: "left" },
  { key: "volume", header: "Today's Volume", align: "right", render: (r) => formatVolume(r.volume) },
  { key: "avgVol1W", header: "Avg Vol (1W)", align: "right", render: (r) => formatVolume(r.avgVol1W) },
  { key: "avgVol1M", header: "Avg Vol (1M)", align: "right", render: (r) => formatVolume(r.avgVol1M) },
  { key: "avgVol1Y", header: "Avg Vol (1Y)", align: "right", render: (r) => formatVolume(r.avgVol1Y) },
  { key: "companyCount", header: "Companies", align: "right" },
];
