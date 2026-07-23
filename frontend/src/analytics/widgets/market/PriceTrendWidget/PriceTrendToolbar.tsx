"use client";

import * as React from "react";
import {
  ArrowUpToLine,
  ArrowDownToLine,
  ChevronsDownUp,
  ChevronsUpDown,
  Download,
  Maximize2,
  RefreshCw,
  GripVertical,
  Table as TableIcon,
  BarChart3,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuCheckboxItem,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import type { PriceTrendSortMetric, PriceTrendSortDir, PriceTrendPeriod } from "./PriceTrend.types";
import { getDefaultPeriods } from "./PriceTrend.utils";

interface PriceTrendToolbarProps {
  sortMetric: PriceTrendSortMetric;
  sortDir: PriceTrendSortDir;
  fullscreen: boolean;
  refreshing: boolean;
  selectedPeriods: PriceTrendPeriod[];
  onSortChange: (metric: PriceTrendSortMetric) => void;
  onSortDirToggle: () => void;
  onFullscreenToggle: () => void;
  onExport: () => void;
  onRefresh: () => void;
  onPeriodsChange: (periods: PriceTrendPeriod[]) => void;
  view: "chart" | "table";
  onViewChange: (view: "chart" | "table") => void;
  disabled?: boolean;
}

const PERIOD_LABELS: Record<PriceTrendPeriod, string> = {
  "1d": "1D", "2d": "2D", "3d": "3D", "4d": "4D", "5d": "5D",
  "21d": "21D", "63d": "63D", "126d": "126D", "252d": "252D",
  "504d": "504D", "756d": "756D", "1260d": "1260D", "2520d": "2520D",
};

const ALL_PERIODS: PriceTrendPeriod[] = [
  "1d", "2d", "3d", "4d", "5d", "21d", "63d", "126d", "252d", "504d", "756d", "1260d", "2520d"
];

export function PriceTrendToolbar({
  sortMetric,
  sortDir,
  fullscreen,
  refreshing,
  selectedPeriods,
  onSortChange,
  onSortDirToggle,
  onFullscreenToggle,
  onExport,
  onRefresh,
  onPeriodsChange,
  view,
  onViewChange,
  disabled,
}: PriceTrendToolbarProps) {
  const togglePeriod = (period: PriceTrendPeriod) => {
    if (selectedPeriods.includes(period)) {
      if (selectedPeriods.length > 1) {
        onPeriodsChange(selectedPeriods.filter((p) => p !== period));
      }
    } else {
      onPeriodsChange([...selectedPeriods, period]);
    }
  };

  return (
    <div className="flex flex-wrap items-center gap-2">
      <div className="flex items-center gap-1">
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
      </div>

      <div className="flex items-center gap-1">
        <select
          value={sortMetric}
          onChange={(e) => onSortChange(e.target.value as PriceTrendSortMetric)}
          disabled={disabled}
          className="h-8 rounded-md border border-border bg-background px-2 text-xs"
        >
          {ALL_PERIODS.map((p) => (
            <option key={p} value={p}>Sort by {PERIOD_LABELS[p]}</option>
          ))}
          <option value="name">Sort by Name</option>
          <option value="marketCap">Sort by Market Cap</option>
        </select>
        <button
          type="button"
          onClick={onSortDirToggle}
          disabled={disabled}
          className="flex h-8 w-8 items-center justify-center rounded-md border border-border hover:bg-accent"
          title={sortDir === "asc" ? "Ascending" : "Descending"}
        >
          {sortDir === "asc" ? <ArrowUpToLine className="h-4 w-4" /> : <ArrowDownToLine className="h-4 w-4" />}
        </button>
      </div>

      <div className="flex items-center gap-1">
        <div className="flex items-center rounded-md border border-border">
          <button
            type="button"
            onClick={() => onViewChange("chart")}
            disabled={disabled}
            className={`flex h-8 w-8 items-center justify-center ${view === "chart" ? "bg-accent text-accent-foreground" : "hover:bg-accent"}`}
            title="Chart view"
          >
            <BarChart3 className="h-4 w-4" />
          </button>
          <button
            type="button"
            onClick={() => onViewChange("table")}
            disabled={disabled}
            className={`flex h-8 w-8 items-center justify-center ${view === "table" ? "bg-accent text-accent-foreground" : "hover:bg-accent"}`}
            title="Table view"
          >
            <TableIcon className="h-4 w-4" />
          </button>
        </div>
        <button
          type="button"
          onClick={onRefresh}
          disabled={disabled || refreshing}
          className="flex h-8 w-8 items-center justify-center rounded-md border border-border hover:bg-accent disabled:opacity-50"
          title="Refresh"
        >
          <RefreshCw className={`h-4 w-4 ${refreshing ? "animate-spin" : ""}`} />
        </button>
        <button
          type="button"
          onClick={onFullscreenToggle}
          disabled={disabled}
          className="flex h-8 w-8 items-center justify-center rounded-md border border-border hover:bg-accent"
          title={fullscreen ? "Exit fullscreen" : "Fullscreen"}
        >
          <Maximize2 className="h-4 w-4" />
        </button>
        <button
          type="button"
          onClick={onExport}
          disabled={disabled}
          className="flex h-8 w-8 items-center justify-center rounded-md border border-border hover:bg-accent"
          title="Export CSV"
        >
          <Download className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
