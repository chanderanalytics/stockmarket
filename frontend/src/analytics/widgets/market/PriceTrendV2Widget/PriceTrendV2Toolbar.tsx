"use client";

import * as React from "react";
import {
  ArrowUpToLine,
  ArrowDownToLine,
  ChevronsDownUp,
  ChevronsUpDown,
  Maximize2,
  Download,
  RefreshCw,
  GripVertical,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuCheckboxItem,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import { VisualizationToolbar } from "@/visualization/primitives";
import type { PriceTrendV2SortMetric, PriceTrendV2SortDir, PriceTrendV2Period } from "./PriceTrendV2.types";

interface PriceTrendV2ToolbarProps {
  sortMetric: PriceTrendV2SortMetric;
  sortDir: PriceTrendV2SortDir;
  expanded: boolean;
  fullscreen: boolean;
  refreshing: boolean;
  selectedPeriods: PriceTrendV2Period[];
  onSortChange: (metric: PriceTrendV2SortMetric) => void;
  onSortDirToggle: () => void;
  onExpandToggle: () => void;
  onFullscreenToggle: () => void;
  onExport: () => void;
  onRefresh: () => void;
  onPeriodsChange?: (periods: PriceTrendV2Period[]) => void;
  onDrillDown?: () => void;
  onDrillUp?: () => void;
  canDrillDown?: boolean;
  canDrillUp?: boolean;
  disabled?: boolean;
}

const PERIOD_LABELS: Record<PriceTrendV2Period, string> = {
  "1d": "1D", "2d": "2D", "3d": "3D", "4d": "4D", "5d": "5D",
  "21d": "21D", "63d": "63D", "126d": "126D", "252d": "252D",
  "504d": "504D", "756d": "756D", "1260d": "1260D", "2520d": "2520D",
};

const ALL_PERIODS: PriceTrendV2Period[] = [
  "1d", "2d", "3d", "4d", "5d", "21d", "63d", "126d", "252d", "504d", "756d", "1260d", "2520d"
];

export function PriceTrendV2Toolbar({
  sortMetric,
  sortDir,
  expanded,
  fullscreen,
  refreshing,
  selectedPeriods,
  onSortChange,
  onSortDirToggle,
  onExpandToggle,
  onFullscreenToggle,
  onExport,
  onRefresh,
  onPeriodsChange,
  onDrillDown,
  onDrillUp,
  canDrillDown,
  canDrillUp,
  disabled,
}: PriceTrendV2ToolbarProps) {
  const togglePeriod = (period: PriceTrendV2Period) => {
    if (!onPeriodsChange) return;
    if (selectedPeriods.includes(period)) {
      if (selectedPeriods.length > 1) {
        onPeriodsChange(selectedPeriods.filter((p) => p !== period));
      }
    } else {
      onPeriodsChange([...selectedPeriods, period]);
    }
  };

  const items = [
    ...(canDrillUp ? [{ key: "drill-up", label: "Drill Up", icon: <ArrowUpToLine className="h-4 w-4" />, onClick: onDrillUp! }] : []),
    ...(canDrillDown ? [{ key: "drill-down", label: "Drill Down", icon: <ArrowDownToLine className="h-4 w-4" />, onClick: onDrillDown! }] : []),
    {
      key: "expand",
      label: expanded ? "Collapse" : "Expand",
      icon: expanded ? <ChevronsDownUp className="h-4 w-4" /> : <ChevronsUpDown className="h-4 w-4" />,
      onClick: onExpandToggle,
    },
    {
      key: "fullscreen",
      label: fullscreen ? "Exit Fullscreen" : "Fullscreen",
      icon: fullscreen ? <Maximize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />,
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
      {onPeriodsChange && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              disabled={disabled}
              className="flex h-7 items-center gap-1.5 rounded-md border border-border px-2 text-xs hover:bg-accent"
            >
              <GripVertical className="h-3.5 w-3.5" />
              <span>Periods</span>
              <span className="text-muted-foreground">
                ({selectedPeriods.length})
              </span>
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="start" className="min-w-[10rem] max-h-[60vh] overflow-y-auto">
            <DropdownMenuCheckboxItem
              checked={selectedPeriods.length === ALL_PERIODS.length}
              onCheckedChange={() => {
                if (selectedPeriods.length === ALL_PERIODS.length) {
                  onPeriodsChange([]);
                } else {
                  onPeriodsChange([...ALL_PERIODS]);
                }
              }}
              disabled={disabled}
            >
              {selectedPeriods.length === ALL_PERIODS.length ? "Unselect All" : "Select All"}
            </DropdownMenuCheckboxItem>
            <DropdownMenuSeparator />
            {ALL_PERIODS.map((period) => {
              const checked = selectedPeriods.includes(period);
              return (
                <DropdownMenuCheckboxItem
                  key={period}
                  checked={checked}
                  onCheckedChange={() => togglePeriod(period)}
                  onSelect={(e) => e.preventDefault()}
                  disabled={disabled}
                >
                  {PERIOD_LABELS[period]}
                </DropdownMenuCheckboxItem>
              );
            })}
          </DropdownMenuContent>
        </DropdownMenu>
      )}
      <label className="flex items-center gap-2 text-xs text-muted-foreground">
        Sort
        <select
          value={sortMetric}
          onChange={(e) => onSortChange(e.target.value as PriceTrendV2SortMetric)}
          disabled={disabled}
          className="h-9 rounded-md border border-border bg-background px-2 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          {ALL_PERIODS.map((p) => (
            <option key={p} value={p}>Sort by {PERIOD_LABELS[p]}</option>
          ))}
          <option value="name">Sort by Name</option>
          <option value="marketCap">Sort by Market Cap</option>
          <option value="weightedMarketCap">Sort by Weighted Market Cap</option>
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
