"use client";

import * as React from "react";
import { VisualizationLegend } from "@/visualization/primitives";
import { VOLUME_PROFILE_V2_SERIES } from "./VolumeProfileV2.utils";

export function VolumeProfileV2Legend() {
  const items = VOLUME_PROFILE_V2_SERIES.map((s) => ({
    key: s.key,
    label: s.name,
    color: s.color,
  }));
  return <VisualizationLegend items={items} position="bottom" />;
}
