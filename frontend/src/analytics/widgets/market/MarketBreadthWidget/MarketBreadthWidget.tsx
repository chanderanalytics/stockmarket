"use client";

import * as React from "react";
import { ChevronDown, ChevronRight, GripVertical } from "lucide-react";
import {
  VisualizationContainer,
  VisualizationEmpty,
} from "@/visualization/primitives";
import { useBreadthSummary, useBreadthSectors, useBreadthIndustries, useBreadthSubgroups, useBreadthCompanies } from "./hooks";
import { nextDrillLevel, levelLabel, LEVEL_ORDER, SORT_METRIC_LABELS } from "./utils";
import type {
  BreadthLevel,
  BreadthHorizon,
  BreadthSortMetric,
  BreadthSortDir,
  BreadthSignalType,
  BreadthViewMode,
  BreadthMetricMode,
  BreadthRow,
  BreadthSummary,
} from "./types";
import { HORIZON_ORDER, HORIZON_LABELS } from "./types";
import { BreadthToolbar } from "./BreadthToolbar";
import { BreadthHierarchy } from "./BreadthHierarchy";
import { BreadthGridTable } from "./BreadthGridTable";
import { DMADistanceTable } from "./DMADistanceTable";
import { MarketHealthCards } from "./MarketHealthCards";
import { MarketBreadthFilters } from "./MarketBreadthFilters";
import { MomentumMatrix } from "./MomentumMatrix";
import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { marketService } from "@/shared/api/services/market";

const DEFAULT_HORIZONS: BreadthHorizon[] = [1, 5, 21, 63, 126, 256];

interface DrillState {
  level: BreadthLevel;
  sector: string;
  industry: string;
  industrySubGroup: string;
}

export function MarketBreadthWidget() {
  const [level, setLevel] = React.useState<BreadthLevel>("sector");
  const [sector, setSector] = React.useState("");
  const [industry, setIndustry] = React.useState("");
  const [industrySubGroup, setIndustrySubGroup] = React.useState("");
  const [marketCap, setMarketCap] = React.useState("");
  const [marketCapBucket, setMarketCapBucket] = React.useState("");
  const [companyName, setCompanyName] = React.useState("");
  const [limit, setLimit] = React.useState(50);
  const [filtersExpanded, setFiltersExpanded] = React.useState(false);
  const [sortMetric, setSortMetric] = React.useState<BreadthSortMetric>("breadthScore");
  const [sortDir, setSortDir] = React.useState<BreadthSortDir>("desc");
  const [fullscreen, setFullscreen] = React.useState(false);
  const [selectedHorizons, setSelectedHorizons] = React.useState<BreadthHorizon[]>(DEFAULT_HORIZONS);
  const [period, setPeriod] = React.useState<BreadthHorizon>(21);
  const [viewMode, setViewMode] = React.useState<BreadthViewMode>("metrics");
  const [metricMode, setMetricMode] = React.useState<BreadthMetricMode>("compositeBreadth");
  const [signalType, setSignalType] = React.useState<BreadthSignalType>("above50dma");
  const [searchQuery, setSearchQuery] = React.useState("");

  const drill: DrillState = { level, sector, industry, industrySubGroup };

  const parent =
    level === "industry" ? sector :
    level === "industrySubGroup" ? industry :
    level === "company" ? industrySubGroup :
    undefined;

  const summaryQuery = useBreadthSummary({ horizons: [period], signalType, marketCap, marketCapBucket, companyName });

  const statusQuery = useApiQuery(queryKeys.market.status(), () => marketService.status(), {
    staleTime: 60_000,
  });

  const activeQuery =
    level === "sector" ? useBreadthSectors({
      sector: sector || undefined,
      industry: industry || undefined,
      industrySubGroup: industrySubGroup || undefined,
      horizons: DEFAULT_HORIZONS,
      signalType,
      marketCap,
      marketCapBucket,
      companyName,
      sortBy: sortMetric,
      sortDirection: sortDir,
      limit,
    }) :
    level === "industry" ? useBreadthIndustries({
      sector: sector || undefined,
      industry: industry || undefined,
      industrySubGroup: industrySubGroup || undefined,
      horizons: DEFAULT_HORIZONS,
      signalType,
      marketCap,
      marketCapBucket,
      companyName,
      sortBy: sortMetric,
      sortDirection: sortDir,
      limit,
    }) :
    level === "industrySubGroup" ? useBreadthSubgroups({
      sector: sector || undefined,
      industry: industry || undefined,
      industrySubGroup: industrySubGroup || undefined,
      horizons: DEFAULT_HORIZONS,
      signalType,
      marketCap,
      marketCapBucket,
      companyName,
      sortBy: sortMetric,
      sortDirection: sortDir,
      limit,
    }) :
    useBreadthCompanies({
      sector: sector || undefined,
      industry: industry || undefined,
      industrySubGroup: industrySubGroup || undefined,
      horizons: DEFAULT_HORIZONS,
      signalType,
      marketCap,
      marketCapBucket,
      companyName,
      sortBy: sortMetric,
      sortDirection: sortDir,
      limit,
    });

  const rawRows: BreadthRow[] = (activeQuery.data?.rows ?? []).map((r) => ({
    ...r,
    horizons: r.horizons && typeof r.horizons === "object" ? r.horizons : {},
  }));

  const asOf = statusQuery.data?.asOf ?? "";
  const formattedDate = asOf
    ? new Date(asOf).toLocaleDateString("en-IN", {
        day: "2-digit",
        month: "short",
        year: "numeric",
      })
    : "";

  const filteredRows = React.useMemo(() => {
    if (!searchQuery.trim()) return rawRows;
    const q = searchQuery.toLowerCase();
    return rawRows.filter((r) =>
      r.name.toLowerCase().includes(q) ||
      r.sector.toLowerCase().includes(q) ||
      r.industry.toLowerCase().includes(q) ||
      r.industrySubGroup.toLowerCase().includes(q),
    );
  }, [rawRows, searchQuery]);

  const sectorOptions = React.useMemo(() => {
    return [...new Set(rawRows.map((r) => r.sector).filter(Boolean))].sort();
  }, [rawRows]);

  const industryOptions = React.useMemo(() => {
    return [...new Set(rawRows.filter((r) => !sector || r.sector === sector).map((r) => r.industry).filter(Boolean))].sort();
  }, [rawRows, sector]);

  const subGroupOptions = React.useMemo(() => {
    return [...new Set(rawRows.filter((r) => !industry || r.industry === industry).map((r) => r.industrySubGroup).filter(Boolean))].sort();
  }, [rawRows, industry]);

  const handleReset = React.useCallback(() => {
    setSector("");
    setIndustry("");
    setIndustrySubGroup("");
    setMarketCap("");
    setMarketCapBucket("");
    setCompanyName("");
    setSearchQuery("");
    setLevel("sector");
    setSelectedHorizons(DEFAULT_HORIZONS);
  }, []);

  const handleHorizonsChange = React.useCallback((next: BreadthHorizon[]) => {
    setSelectedHorizons(next);
  }, []);

  const isLoading = activeQuery.isLoading;
  const isError = Boolean(activeQuery.error);
  const isEmpty = !isLoading && !isError && rawRows.length === 0;
  const isRefreshing = activeQuery.isFetching || summaryQuery.isFetching;

  const handleSector = (value: string) => {
    setSector(value);
    setIndustry("");
    setIndustrySubGroup("");
    setLevel(value ? "industry" : "sector");
  };
  const handleIndustry = (value: string) => {
    setIndustry(value);
    setIndustrySubGroup("");
    setLevel(value ? "industrySubGroup" : "industry");
  };
  const handleIndustrySubGroup = (value: string) => {
    setIndustrySubGroup(value);
    setLevel(value ? "company" : "industrySubGroup");
  };

  const handleEntityClick = React.useCallback(
    (name: string) => {
      if (level === "sector") handleSector(name);
      else if (level === "industry") handleIndustry(name);
      else if (level === "industrySubGroup") handleIndustrySubGroup(name);
    },
    [level],
  );

  const handleHierarchySelect = (target: BreadthLevel) => {
    if (target === "sector") {
      setSector(""); setIndustry(""); setIndustrySubGroup(""); setLevel("sector");
    } else if (target === "industry") {
      setIndustry(""); setIndustrySubGroup(""); setLevel("industry");
    } else if (target === "industrySubGroup") {
      setIndustrySubGroup(""); setLevel("industrySubGroup");
    } else {
      setLevel("company");
    }
  };

  const handleDrillDown = () => {
    const next = nextDrillLevel(level);
    if (next) setLevel(next);
  };
  const handleDrillUp = () =>
    handleHierarchySelect(
      level === "company" ? "industrySubGroup" : level === "industrySubGroup" ? "industry" : "sector",
    );

  const canDrillUp = level !== "sector";
  const canDrillDown = nextDrillLevel(level) !== null;

  const handleExport = React.useCallback(() => {
    const header = ["Entity", "Sector", "Industry", "Sub-Group", "Trend", ...selectedHorizons.map((h) => HORIZON_LABELS[h])];
    const lines = [header.join(",")];
    for (const row of rawRows) {
      const horizonVals = selectedHorizons.map((h) => {
        const m = row.horizons?.[String(h)];
        return m ? m.breadthScore.toFixed(1) : "";
      });
      const cells = [
        `"${String(row.name ?? "").replace(/"/g, '""')}"`,
        `"${String(row.sector ?? "")}"`,
        `"${String(row.industry ?? "")}"`,
        `"${String(row.industrySubGroup ?? "")}"`,
        row.trendStrength?.toFixed(1) ?? "",
        ...horizonVals,
      ];
      lines.push(cells.join(","));
    }
    const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "market-breadth.csv";
    a.click();
    URL.revokeObjectURL(url);
  }, [rawRows]);

  return (
    <VisualizationContainer fullscreen={fullscreen} className="flex flex-col gap-3">
      <MarketHealthCards summary={summaryQuery.data} isLoading={summaryQuery.isLoading} />

      <div className="flex flex-col gap-3 border-b border-border pb-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">Level</span>
            {(["market", "sector", "industry", "industrySubGroup", "company"] as const).map((lvl) => (
              <button
                key={lvl}
                type="button"
                onClick={() => {
                  if (lvl === "market") { setSector(""); setIndustry(""); setIndustrySubGroup(""); }
                  setLevel(lvl);
                }}
                className={`h-8 rounded-md border px-2.5 text-xs font-medium transition-colors select-none ${
                  level === lvl ? "border-foreground bg-foreground text-background" : "border-border hover:bg-accent"
                }`}
              >
                {lvl === "market" ? "Market" : lvl === "sector" ? "Sector" : lvl === "industry" ? "Industry" : lvl === "industrySubGroup" ? "Sub-Industry" : "Company"}
              </button>
            ))}
          </div>
          {formattedDate && (
            <span className="text-xs text-muted-foreground">
              Data as of {formattedDate}
            </span>
          )}
        </div>
        <BreadthToolbar
          level={level}
          canDrillUp={canDrillUp}
          canDrillDown={canDrillDown}
          fullscreen={fullscreen}
          refreshing={isRefreshing}
          selectedHorizons={selectedHorizons}
          onHorizonsChange={handleHorizonsChange}
          signalType={signalType}
          onDrillUp={handleDrillUp}
          onDrillDown={handleDrillDown}
          onFullscreenToggle={() => setFullscreen((v) => !v)}
          onExport={handleExport}
          onRefresh={() => {
            activeQuery.refetch();
            summaryQuery.refetch();
          }}
          onSignalChange={setSignalType}
          total={activeQuery.data?.total ?? rawRows.length}
          drill={drill}
          onBreadcrumbSelect={handleHierarchySelect}
        />
      </div>

      {isError ? (
        <div className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive">
          Failed to load market breadth.
          <button type="button" onClick={() => activeQuery.refetch()} className="ml-2 underline">Retry</button>
        </div>
      ) : isEmpty ? (
        <VisualizationEmpty message="No breadth data for the current selection." />
      ) : (
        <>
          <DMADistanceTable summary={summaryQuery.data} isLoading={isLoading} period={period} viewMode={viewMode} level={level} rows={filteredRows} onPeriodChange={setPeriod} onViewModeChange={setViewMode} onExport={handleExport} onDrillDown={handleEntityClick} />
          <BreadthGridTable
            rows={filteredRows}
            selectedHorizons={selectedHorizons}
            signalType={signalType}
            metricMode={metricMode}
            onMetricModeChange={setMetricMode}
            onSignalTypeChange={setSignalType}
            onHorizonsChange={setSelectedHorizons}
            onExport={handleExport}
            onFullscreenToggle={() => setFullscreen((v) => !v)}
            onEntityClick={level === "company" ? undefined : handleEntityClick}
          />
          <MomentumMatrix rows={filteredRows} isLoading={isLoading} signalType={signalType} onEntityClick={level === "company" ? undefined : handleEntityClick} />
        </>
      )}

      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
        <span>Showing: {filteredRows.length} / {activeQuery.data?.total ?? rawRows.length}</span>
      </div>
    </VisualizationContainer>
  );
}
