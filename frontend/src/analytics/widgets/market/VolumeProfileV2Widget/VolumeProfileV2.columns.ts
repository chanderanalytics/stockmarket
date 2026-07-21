import type { VolumeProfileV2Row } from "./VolumeProfileV2.types";
import { formatVolume, formatRelative } from "./VolumeProfileV2.utils";

export interface VolumeProfileV2Column {
  key: keyof VolumeProfileV2Row;
  header: string;
  align: "left" | "right";
  render?: (row: VolumeProfileV2Row) => string;
}

export const VOLUME_PROFILE_V2_COLUMNS: readonly VolumeProfileV2Column[] = [
  { key: "rank", header: "#", align: "right" },
  { key: "name", header: "Entity", align: "left" },
  { key: "sector", header: "Sector", align: "left" },
  { key: "industry", header: "Industry", align: "left" },
  { key: "industrySubGroup", header: "Sub-Group", align: "left" },
  { key: "volume", header: "Today's Volume", align: "right", render: (r) => formatVolume(r.volume) },
  { key: "avgVol1W", header: "Avg Vol (1W)", align: "right", render: (r) => formatVolume(r.avgVol1W) },
  { key: "avgVol1M", header: "Avg Vol (1M)", align: "right", render: (r) => formatVolume(r.avgVol1M) },
  { key: "avgVol1Y", header: "Avg Vol (1Y)", align: "right", render: (r) => formatVolume(r.avgVol1Y) },
  { key: "relative1W", header: "Rel (1W)", align: "right", render: (r) => formatRelative(r.relative1W) },
  { key: "relative1M", header: "Rel (1M)", align: "right", render: (r) => formatRelative(r.relative1M) },
  { key: "relative1Y", header: "Rel (1Y)", align: "right", render: (r) => formatRelative(r.relative1Y) },
  { key: "companyCount", header: "Companies", align: "right" },
];
