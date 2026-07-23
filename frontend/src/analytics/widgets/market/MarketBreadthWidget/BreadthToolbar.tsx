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
import type { BreadthLevel, BreadthSignalType, BreadthHorizon } from "./types";
import { SIGNAL_TYPE_LABELS, HORIZON_ORDER, HORIZON_LABELS } from "./types";
import { BreadthHierarchy } from "./BreadthHierarchy";

interface BreadthToolbarProps {
  level: BreadthLevel;
  canDrillUp: boolean;
  canDrillDown: boolean;
  fullscreen: boolean;
  refreshing: boolean;
  selectedHorizons: BreadthHorizon[];
  onHorizonsChange: (horizons: BreadthHorizon[]) => void;
  signalType: BreadthSignalType;
  onDrillUp: () => void;
  onDrillDown: () => void;
  onFullscreenToggle: () => void;
  onExport: () => void;
  onRefresh: () => void;
  onSignalChange: (signal: BreadthSignalType) => void;
  total?: number;
  drill?: { level: BreadthLevel; sector: string; industry: string; industrySubGroup: string };
  onBreadcrumbSelect?: (target: BreadthLevel) => void;
}

export function BreadthToolbar({
  level,
  canDrillUp,
  canDrillDown,
  fullscreen,
  refreshing,
  selectedHorizons,
  onHorizonsChange,
  signalType,
  onDrillUp,
  onDrillDown,
  onFullscreenToggle,
  onExport,
  onRefresh,
  onSignalChange,
  total,
  drill,
  onBreadcrumbSelect,
}: BreadthToolbarProps) {
  const toggleHorizon = (horizon: BreadthHorizon) => {
    if (!onHorizonsChange) return;
    if (selectedHorizons.includes(horizon)) {
      if (selectedHorizons.length > 1) {
        onHorizonsChange(selectedHorizons.filter((h) => h !== horizon));
      }
    } else {
      onHorizonsChange([...selectedHorizons, horizon]);
    }
  };

  const items = [
    ...(canDrillUp
      ? [{ key: "drill-up", label: "Drill Up", icon: <ArrowUpToLine className="h-4 w-4" />, onClick: onDrillUp }]
      : []),
    ...(canDrillDown
      ? [{ key: "drill-down", label: "Drill Down", icon: <ArrowDownToLine className="h-4 w-4" />, onClick: onDrillDown }]
      : []),
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

  const chipBase =
    "h-8 rounded-md border px-2.5 text-xs font-medium transition-colors select-none";
  const chipActive = "border-foreground bg-foreground text-background";
  const chipInactive = "border-border hover:bg-accent";

  const labelClass = "text-[11px] font-medium uppercase tracking-wide text-muted-foreground";

  const levelLabel =
    level === "sector" ? "Sectors" :
    level === "industry" ? "Industries" :
    level === "company" ? "Companies" :
    "Sub-groups";

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center gap-2">
        {drill && onBreadcrumbSelect ? (
          <BreadthHierarchy drill={drill} onSelect={onBreadcrumbSelect} />
        ) : (
          <>
            <span className="text-sm font-medium text-foreground">
              {level === "sector" ? "Sectors" : level === "industry" ? "Industries" : level === "company" ? "Companies" : "Sub-groups"}
            </span>
            <span className="text-sm text-muted-foreground">· {total ?? 0} items</span>
          </>
        )}
      </div>
      <div className="flex justify-start">
        <VisualizationToolbar items={items} />
      </div>
    </div>
  );
}
