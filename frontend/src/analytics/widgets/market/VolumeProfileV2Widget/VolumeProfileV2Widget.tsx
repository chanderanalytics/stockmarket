"use client";

import * as React from "react";
import { ChevronDown, ChevronRight } from "lucide-react";
import {
  VisualizationContainer,
  VisualizationEmpty,
} from "@/visualization/primitives";
import { useVolumeProfileV2, useVolumeProfileV2Options, useLatestVolumeProfileV2Date } from "./VolumeProfileV2.hooks";
import { useDebounce } from "@/shared/hooks";
import { VolumeProfileV2Toolbar } from "./VolumeProfileV2Toolbar";
import { VolumeProfileV2Filters } from "./VolumeProfileV2Filters";
import { VolumeProfileV2Hierarchy } from "./VolumeProfileV2Hierarchy";
import { VolumeProfileV2Grid } from "./VolumeProfileV2Grid";
import {
  nextDrillLevel,
  levelLabel,
} from "./VolumeProfileV2.utils";
import { calculateV2Scales } from "./calculateV2Scales";
import type {
  VolumeProfileV2Level,
  VolumeProfileV2MarketCap,
  VolumeProfileV2MarketCapBucket,
  VolumeProfileV2SortMetric,
  VolumeProfileV2SortDir,
  VolumeProfileV2DrillState,
} from "./VolumeProfileV2.types";

const BUCKET_TO_TIER: Record<string, VolumeProfileV2MarketCap> = {
  "top 10perc by mcap": "large",
  "50-90% by mcap": "mid",
  "bottom 50% by mcap": "small",
};

const LEVEL_ORDER: VolumeProfileV2Level[] = ["sector", "industry", "industrySubGroup", "company"];

export function VolumeProfileV2Widget() {
  const [level, setLevel] = React.useState<VolumeProfileV2Level>("sector");
  const [sector, setSector] = React.useState("");
  const [industry, setIndustry] = React.useState("");
  const [industrySubGroup, setIndustrySubGroup] = React.useState("");
  const [marketCap, setMarketCap] = React.useState<VolumeProfileV2MarketCap>("");
  const [marketCapBucket, setMarketCapBucket] = React.useState<VolumeProfileV2MarketCapBucket>("");
  const [limit, setLimit] = React.useState(50);
  const [expanded, setExpanded] = React.useState(false);
  const [filtersExpanded, setFiltersExpanded] = React.useState(false);
  const [companyName, setCompanyName] = React.useState("");
  const [sortMetric, setSortMetric] = React.useState<VolumeProfileV2SortMetric>("relative1Y");
  const [sortDir, setSortDir] = React.useState<VolumeProfileV2SortDir>("desc");
  const [fullscreen, setFullscreen] = React.useState(false);

  const drill: VolumeProfileV2DrillState = { level, sector, industry, industrySubGroup };

  const parent =
    level === "industry" ? sector :
    level === "industrySubGroup" ? industry :
    level === "company" ? industrySubGroup :
    undefined;

  const query = useVolumeProfileV2({
    level,
    parent,
    sector: sector || undefined,
    industry: industry || undefined,
    industrySubGroup: industrySubGroup || undefined,
    marketCap: marketCap || undefined,
    marketCapBucket: marketCapBucket || undefined,
    companyName: companyName || undefined,
    limit: expanded ? Math.max(limit, 500) : limit,
    sortMetric,
    sortDirection: sortDir,
  });

  const sectorOptions = useVolumeProfileV2Options("sector").data?.rows ?? [];
  const industryOptions =
    useVolumeProfileV2Options("industry", sector || undefined).data?.rows ?? [];
  const subGroupOptions =
    useVolumeProfileV2Options("industrySubGroup", industry || undefined).data?.rows ?? [];

  const debouncedCompany = useDebounce(companyName, 250);
  const companyRows =
    useVolumeProfileV2Options("company", undefined, debouncedCompany).data?.rows ?? [];
  const companyOptions = companyRows.map((r) => ({
    id: r.id,
    name: r.name,
    sector: r.sector,
    industry: r.industry,
    industrySubGroup: r.industrySubGroup,
    marketCapBucket: r.marketCapBucket,
  }));

  const latestDateQuery = useLatestVolumeProfileV2Date();
  const latestDate = latestDateQuery.data?.date ?? null;

  const rawRows = query.data?.rows ?? [];
  const scales = React.useMemo(() => calculateV2Scales(rawRows), [rawRows]);

  const handleCompanyNameChange = (value: string) => {
    setCompanyName(value);
    setSector("");
    setIndustry("");
    setIndustrySubGroup("");
    setMarketCap("");
    setMarketCapBucket("");
    setLevel("company");
  };

  const handleCompanySelect = (row: { id: string; name: string; sector: string; industry: string; industrySubGroup: string; marketCapBucket: string }) => {
    setCompanyName(row.name);
    setSector(row.sector);
    setIndustry(row.industry);
    setIndustrySubGroup(row.industrySubGroup);
    setMarketCap(BUCKET_TO_TIER[row.marketCapBucket] ?? "");
    setMarketCapBucket((row.marketCapBucket as VolumeProfileV2MarketCapBucket) ?? "");
    setLevel("company");
  };

  const searched = companyName.trim()
    ? rawRows.filter((r) => r.name.toLowerCase().includes(companyName.trim().toLowerCase()))
    : rawRows;
  const displayRows = searched;

  const isLoading = query.isLoading;
  const isError = Boolean(query.error);
  const isEmpty = !isLoading && !isError && rawRows.length === 0;
  const isRefreshing = query.isFetching;

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
    [level, handleSector, handleIndustry, handleIndustrySubGroup],
  );

  const handleHierarchySelect = (target: VolumeProfileV2Level) => {
    if (target === "sector") {
      setSector("");
      setIndustry("");
      setIndustrySubGroup("");
      setLevel("sector");
    } else if (target === "industry") {
      setIndustry("");
      setIndustrySubGroup("");
      setLevel("industry");
    } else if (target === "industrySubGroup") {
      setIndustrySubGroup("");
      setLevel("industrySubGroup");
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
    const header = ["Entity", "Sector", "Industry", "Sub-Group", "Rel (1W)", "Rel (1M)", "Rel (1Y)"];
    const lines = [header.join(",")];
    for (const row of displayRows) {
      const cells = [
        `"${String(row.name ?? "").replace(/"/g, '""')}"`,
        `"${String(row.sector ?? "")}"`,
        `"${String(row.industry ?? "")}"`,
        `"${String(row.industrySubGroup ?? "")}"`,
        typeof row.relative1W === "number" ? row.relative1W.toFixed(2) : "",
        typeof row.relative1M === "number" ? row.relative1M.toFixed(2) : "",
        typeof row.relative1Y === "number" ? row.relative1Y.toFixed(2) : "",
      ];
      lines.push(cells.join(","));
    }
    const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "volume-profile-v2.csv";
    a.click();
    URL.revokeObjectURL(url);
  }, [displayRows]);

  return (
    <VisualizationContainer fullscreen={fullscreen} className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
        <span className="font-medium text-foreground">Level:</span>
        {LEVEL_ORDER.map((lvl) => (
          <button
            key={lvl}
            type="button"
            onClick={() => handleHierarchySelect(lvl)}
            className={`rounded-md px-2 py-1 ${
              level === lvl ? "bg-accent text-accent-foreground" : "hover:text-foreground"
            }`}
          >
            {levelLabel(lvl)}
          </button>
        ))}
      </div>
      <div className="flex flex-col gap-3 border-b border-border pb-3 lg:flex-row lg:items-center lg:justify-between">
        <VolumeProfileV2Hierarchy drill={drill} onSelect={handleHierarchySelect} />
        <div className="flex items-center gap-3">
          <VolumeProfileV2Toolbar
            level={level}
            canDrillUp={canDrillUp}
            canDrillDown={canDrillDown}
            expanded={expanded}
            fullscreen={fullscreen}
            refreshing={isRefreshing}
            sortMetric={sortMetric}
            sortDir={sortDir}
            onDrillUp={handleDrillUp}
            onDrillDown={handleDrillDown}
            onExpandToggle={() => setExpanded((v) => !v)}
            onFullscreenToggle={() => setFullscreen((v) => !v)}
            onExport={handleExport}
            onRefresh={() => query.refetch()}
            onSortChange={setSortMetric}
            onSortDirToggle={() => setSortDir((d) => (d === "asc" ? "desc" : "asc"))}
          />
          {latestDate && (
            <span className="text-xs text-muted-foreground">
              Data date: {new Date(latestDate).toLocaleDateString("en-IN")}
            </span>
          )}
        </div>
      </div>

      <div className="rounded-md border border-border">
        <button
          type="button"
          onClick={() => setFiltersExpanded((v) => !v)}
          className="flex w-full items-center gap-2 px-3 py-2 text-sm text-muted-foreground hover:text-foreground"
        >
          {filtersExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
          Filters
        </button>
        {filtersExpanded && (
          <div className="border-t border-border px-3 py-3">
            <VolumeProfileV2Filters
              sector={sector}
              industry={industry}
              industrySubGroup={industrySubGroup}
              sectorOptions={sectorOptions.map((r) => r.name)}
              industryOptions={industryOptions.map((r) => r.name)}
              subGroupOptions={subGroupOptions.map((r) => r.name)}
              companyOptions={companyOptions}
              marketCap={marketCap}
              marketCapBucket={marketCapBucket}
              limit={limit}
              companyName={companyName}
              onSector={handleSector}
              onIndustry={handleIndustry}
              onIndustrySubGroup={handleIndustrySubGroup}
              onMarketCap={setMarketCap}
              onMarketCapBucket={setMarketCapBucket}
              onLimit={(n: number) => {
                setLimit(n);
                setExpanded(false);
              }}
              onCompanyName={handleCompanyNameChange}
              onCompanySelect={handleCompanySelect}
              disabled={isLoading}
            />
          </div>
        )}
      </div>

      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-sm text-muted-foreground">
          {level === "sector" ? "Sectors" : level === "industry" ? "Industries" : level === "industrySubGroup" ? "Sub-groups" : "Companies"}: <span className="font-medium text-foreground">{query.data?.total ?? rawRows.length}</span>
        </span>
      </div>

      {isError ? (
        <div className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive">
          Failed to load volume profile.
          <button type="button" onClick={() => query.refetch()} className="ml-2 underline">Retry</button>
        </div>
      ) : isEmpty ? (
        <VisualizationEmpty message="No volume profile data for the current selection." />
      ) : (
        <VolumeProfileV2Grid
          rows={displayRows}
          scales={scales}
          sortMetric={sortMetric}
          sortDir={sortDir}
          onSortChange={setSortMetric}
          onSortDirToggle={() => setSortDir((d) => (d === "asc" ? "desc" : "asc"))}
          onExport={handleExport}
          onFullscreenToggle={() => setFullscreen((v) => !v)}
          onEntityClick={handleEntityClick}
        />
      )}

      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
        <span>
          Showing: {displayRows.length} / {query.data?.total ?? rawRows.length}
        </span>
      </div>
    </VisualizationContainer>
  );
}
