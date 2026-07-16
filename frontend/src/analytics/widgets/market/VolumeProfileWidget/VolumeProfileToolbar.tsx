"use client";

import * as React from "react";
import {
  ArrowUpToLine,
  ArrowDownToLine,
  ChevronsDownUp,
  ChevronsUpDown,
  Maximize2,
  Minimize2,
  Download,
  RefreshCw,
} from "lucide-react";
import { VisualizationToolbar } from "@/visualization/primitives";
import type { VolumeProfileLevel, VolumeProfileSortMetric, VolumeProfileSortDir } from "./VolumeProfile.types";
import { SORT_METRIC_LABELS } from "./VolumeProfile.utils";

interface VolumeProfileToolbarProps {
  level: VolumeProfileLevel;
  canDrillUp: boolean;
  canDrillDown: boolean;
  expanded: boolean;
  fullscreen: boolean;
  refreshing: boolean;
  sortMetric: VolumeProfileSortMetric;
  sortDir: VolumeProfileSortDir;
  onDrillUp: () => void;
  onDrillDown: () => void;
  onExpandToggle: () => void;
  onFullscreenToggle: () => void;
  onExport: () => void;
  onRefresh: () => void;
  onSortChange: (metric: VolumeProfileSortMetric) => void;
  onSortDirToggle: () => void;
}

const selectClass =
  "h-9 rounded-md border border-border bg-background px-2 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring";

export function VolumeProfileToolbar({
  canDrillUp,
  canDrillDown,
  expanded,
  fullscreen,
  refreshing,
  sortMetric,
  sortDir,
  onDrillUp,
  onDrillDown,
  onExpandToggle,
  onFullscreenToggle,
  onExport,
  onRefresh,
  onSortChange,
  onSortDirToggle,
}: VolumeProfileToolbarProps) {
  const items = [
    ...(canDrillUp
      ? [{ key: "drill-up", label: "Drill Up", icon: <ArrowUpToLine className="h-4 w-4" />, onClick: onDrillUp }]
      : []),
    ...(canDrillDown
      ? [{ key: "drill-down", label: "Drill Down", icon: <ArrowDownToLine className="h-4 w-4" />, onClick: onDrillDown }]
      : []),
    {
      key: "expand",
      label: expanded ? "Collapse" : "Expand",
      icon: expanded ? <ChevronsDownUp className="h-4 w-4" /> : <ChevronsUpDown className="h-4 w-4" />,
      onClick: onExpandToggle,
    },
    {
      key: "fullscreen",
      label: fullscreen ? "Exit Fullscreen" : "Fullscreen",
      icon: fullscreen ? <Minimize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />,
      onClick: onFullscreenToggle,
    },
    { key: "export", label: "Export", icon: <Download className="h-4 w-4" />, onClick: onExport },
    {
      key: "refresh",
      label: refreshing ? "Refreshing…" : "Refresh",
      icon: <RefreshCw className={`h-4 w-4 ${refreshing ? "animate-spin" : ""}`} />,
      onClick: onRefresh,
    },
  ];

  return (
    <div className="flex flex-wrap items-center gap-3">
      <VisualizationToolbar items={items} />
      <label className="flex items-center gap-2 text-xs text-muted-foreground">
        Sort
        <select
          value={sortMetric}
          onChange={(e) => onSortChange(e.target.value as VolumeProfileSortMetric)}
          className={selectClass}
        >
          {(Object.keys(SORT_METRIC_LABELS) as VolumeProfileSortMetric[]).map((m) => (
            <option key={m} value={m}>
              {SORT_METRIC_LABELS[m]}
            </option>
          ))}
        </select>
        <button
          type="button"
          onClick={onSortDirToggle}
          className="h-9 rounded-md border border-border px-2 text-sm hover:bg-muted"
          aria-label="Toggle sort direction"
        >
          {sortDir === "asc" ? "↑" : "↓"}
        </button>
      </label>
    </div>
  );
}
