"use client";

import * as React from "react";
import { ChevronDown, ChevronRight } from "lucide-react";
import {
  StackedBarPrimitive,
  VisualizationContainer,
  VisualizationEmpty,
} from "@/visualization/primitives";
import { EChartsAdapter, exportEChartPng } from "@/visualization/adapters";
import type { VisualizationConfiguration } from "@/visualization/types";
import { useVolumeProfile, useVolumeProfileOptions, useLatestVolumeProfileDate } from "./VolumeProfile.hooks";
import { useDebounce } from "@/shared/hooks";
import { VolumeProfileToolbar } from "./VolumeProfileToolbar";
import { VolumeProfileFilters } from "./VolumeProfileFilters";
import { VolumeProfileHierarchy } from "./VolumeProfileHierarchy";
import { VolumeProfileLegend } from "./VolumeProfileLegend";
import {
  mapRowsToChartPayload,
  nextDrillLevel,
  levelLabel,
} from "./VolumeProfile.utils";
import type {
  CompanyOption,
  VolumeProfileLevel,
  VolumeProfileMarketCap,
  VolumeProfileMarketCapBucket,
  VolumeProfileSortMetric,
  VolumeProfileSortDir,
  VolumeProfileDrillState,
} from "./VolumeProfile.types";

const echartsAdapter = new EChartsAdapter();
const CHART_ID = "volume-profile-chart";

// Reverse of the backend's CAP_TIER_BUCKET: cap_class bucket -> large/mid/small tier.
const BUCKET_TO_TIER: Record<string, VolumeProfileMarketCap> = {
  "top 10perc by mcap": "large",
  "50-90% by mcap": "mid",
  "bottom 50% by mcap": "small",
};

export function VolumeProfileWidget() {
  const [level, setLevel] = React.useState<VolumeProfileLevel>("sector");
  const [sector, setSector] = React.useState("");
  const [industry, setIndustry] = React.useState("");
  const [industrySubGroup, setIndustrySubGroup] = React.useState("");
  const [marketCap, setMarketCap] = React.useState<VolumeProfileMarketCap>("");
  const [marketCapBucket, setMarketCapBucket] = React.useState<VolumeProfileMarketCapBucket>("");
  const [limit, setLimit] = React.useState(50);
  const [expanded, setExpanded] = React.useState(false);
  const [filtersExpanded, setFiltersExpanded] = React.useState(false);
  const [companyName, setCompanyName] = React.useState("");
  const [sortMetric, setSortMetric] = React.useState<VolumeProfileSortMetric>("volume");
  const [sortDir, setSortDir] = React.useState<VolumeProfileSortDir>("desc");
  const [fullscreen, setFullscreen] = React.useState(false);

  const drill: VolumeProfileDrillState = { level, sector, industry, industrySubGroup };

  const parent =
    level === "industry" ? sector :
    level === "industrySubGroup" ? industry :
    level === "company" ? industrySubGroup :
    undefined;

  const query = useVolumeProfile({
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

  // Option lists for the Sector / Industry / Sub-Group dropdowns.
  const sectorOptions = useVolumeProfileOptions("sector").data?.rows ?? [];
  const industryOptions =
    useVolumeProfileOptions("industry", sector || undefined).data?.rows ?? [];
  const subGroupOptions =
    useVolumeProfileOptions("industrySubGroup", industry || undefined).data?.rows ?? [];

  // Company search runs against the full universe (5000+ names). Debounce the
  // keystrokes and let the backend do the substring match so we don't rely on a
  // truncated local list.
  const debouncedCompany = useDebounce(companyName, 250);
  const companyRows =
    useVolumeProfileOptions("company", undefined, debouncedCompany).data?.rows ?? [];
  const companyOptions: CompanyOption[] = companyRows.map((r) => ({
    id: r.id,
    name: r.name,
    sector: r.sector,
    industry: r.industry,
    industrySubGroup: r.industrySubGroup,
    marketCapBucket: r.marketCapBucket,
  }));

  const latestDateQuery = useLatestVolumeProfileDate();
  const latestDate = latestDateQuery.data?.date ?? null;

  const rawRows = query.data?.rows ?? [];

  // Typing in the company search resets the hierarchy + cap filters, because a
  // company can belong to any sector in the full 5000+ universe.
  const handleCompanyNameChange = (value: string) => {
    setCompanyName(value);
    setSector("");
    setIndustry("");
    setIndustrySubGroup("");
    setMarketCap("");
    setMarketCapBucket("");
    setLevel("company");
  };

  // Selecting a concrete company from the suggestions populates every filter
  // with that company's actual classification (sector / industry / sub-group /
  // market-cap tier / cap bucket).
  const handleCompanySelect = (row: CompanyOption) => {
    setCompanyName(row.name);
    setSector(row.sector);
    setIndustry(row.industry);
    setIndustrySubGroup(row.industrySubGroup);
    setMarketCap(BUCKET_TO_TIER[row.marketCapBucket] ?? "");
    setMarketCapBucket((row.marketCapBucket as VolumeProfileMarketCapBucket) ?? "");
    setLevel("company");
  };
  const searched = companyName.trim()
    ? rawRows.filter((r) => r.name.toLowerCase().includes(companyName.trim().toLowerCase()))
    : rawRows;
  const displayRows = searched;

  const payload = React.useMemo(() => mapRowsToChartPayload(displayRows), [displayRows]);

  const chartHeight = Math.min(1000, Math.max(400, displayRows.length * 30));

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
  const handleChartClick = React.useCallback(
    (name: string) => {
      if (level === "sector") handleSector(name);
      else if (level === "industry") handleIndustry(name);
      else if (level === "industrySubGroup") handleIndustrySubGroup(name);
    },
    [level, handleSector, handleIndustry, handleIndustrySubGroup],
  );
  const chartConfig: VisualizationConfiguration = {
    primitive: "stacked-bar-chart",
    adapter: "echarts",
    data: {},
    options: { percentStack: true, height: chartHeight, chartId: CHART_ID, onChartClick: handleChartClick },
  };
  const handleHierarchySelect = (target: VolumeProfileLevel) => {
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

  return (
    <VisualizationContainer fullscreen={fullscreen} className="flex flex-col gap-3">
      <div className="flex flex-col gap-3 border-b border-border pb-3 lg:flex-row lg:items-center lg:justify-between">
        <VolumeProfileHierarchy drill={drill} onSelect={handleHierarchySelect} />
        <div className="flex items-center gap-3">
          <VolumeProfileToolbar
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
            onExport={() => exportEChartPng(CHART_ID, "volume-profile.png")}
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
            <VolumeProfileFilters
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
              onLimit={(n) => {
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
        <VolumeProfileLegend />
      </div>

      {isError ? (
        <StackedBarPrimitive
          loading={false}
          error={query.error instanceof Error ? query.error.message : "Failed to load"}
          data={null}
          config={chartConfig}
          adapter={echartsAdapter}
        />
      ) : isEmpty ? (
        <VisualizationEmpty message="No volume profile data for the current selection." />
      ) : (
        <StackedBarPrimitive
          loading={isLoading}
          error={null}
          data={payload}
          config={chartConfig}
          adapter={echartsAdapter}
        />
      )}

      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
        <span>Level: {levelLabel(level)}</span>
        <span>
          Showing: {displayRows.length} / {query.data?.total ?? rawRows.length}
        </span>
      </div>
    </VisualizationContainer>
  );
}
