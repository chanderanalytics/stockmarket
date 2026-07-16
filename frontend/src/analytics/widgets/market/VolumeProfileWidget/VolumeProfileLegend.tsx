"use client";

import * as React from "react";
import { VisualizationLegend } from "@/visualization/primitives";
import { VOLUME_PROFILE_SERIES } from "./VolumeProfile.utils";

export function VolumeProfileLegend() {
  const items = VOLUME_PROFILE_SERIES.map((s) => ({
    key: s.key,
    label: s.name,
    color: s.color,
  }));
  return <VisualizationLegend items={items} position="bottom" />;
}
