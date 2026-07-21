import * as React from "react";
import { ChevronDown, ChevronRight } from "lucide-react";
import {
  VisualizationContainer,
  VisualizationEmpty,
} from "@/visualization/primitives";
import {
  usePriceTrendV2,
  useLatestPriceTrendV2Date,
} from "./PriceTrendV2.hooks";
import { useDebounce } from "@/shared/hooks";
import { PriceTrendV2Toolbar } from "./PriceTrendV2Toolbar";
import { PriceTrendV2Filters } from "./PriceTrendV2Filters";
import { PriceTrendV2Grid } from "./PriceTrendV2Grid";
import { usePriceTrendTable } from "./usePriceTrendTable";
import {
  getDefaultPeriods,
  sortPeriodsChronologically,
  formatPeriodLabel,
} from "./PriceTrendV2.utils";
import type {
  PriceTrendV2Period,
  PriceTrendV2MarketCap,
  PriceTrendV2MarketCapBucket,
  PriceTrendV2SortMetric,
  PriceTrendV2SortDir,
  PriceTrendV2Level,
} from "./PriceTrendV2.types";

// Reverse of the backend's CAP_TIER_BUCKET: cap_class bucket -> large/mid/small tier.
const BUCKET_TO_TIER: Record<string, PriceTrendV2MarketCap> = {
  "top 10perc by mcap": "large",
  "50-90% by mcap": "mid",
  "bottom 50% by mcap": "small",
};

const LEVEL_ORDER: PriceTrendV2Level[] = ["sector", "industry", "industrySubGroup", "company"];

export function PriceTrendV2Widget() {
  const [level, setLevel] = React.useState<PriceTrendV2Level>("sector");
  const [sector, setSector] = React.useState("");
  const [industry, setIndustry] = React.useState("");
  const [industrySubGroup, setIndustrySubGroup] = React.useState("");
  const [marketCap, setMarketCap] = React.useState<PriceTrendV2MarketCap>("");
  const [marketCapBucket, setMarketCapBucket] = React.useState<PriceTrendV2MarketCapBucket>("");
  const [limit, setLimit] = React.useState(50);
  const [expanded, setExpanded] = React.useState(false);
  const [filtersExpanded, setFiltersExpanded] = React.useState(false);
  const [companyName, setCompanyName] = React.useState("");
  const [selectedPeriods, setSelectedPeriods] = React.useState<PriceTrendV2Period[]>(getDefaultPeriods());
  const [sortMetric, setSortMetric] = React.useState<PriceTrendV2SortMetric>("252d");
  const [sortDir, setSortDir] = React.useState<PriceTrendV2SortDir>("desc");
  const [fullscreen, setFullscreen] = React.useState(false);

  const parent =
    level === "industry" ? sector :
    level === "industrySubGroup" ? industry :
    level === "company" ? industrySubGroup :
    undefined;

  const query = usePriceTrendV2({
    sector: sector || undefined,
    industry: industry || undefined,
    industrySubGroup: industrySubGroup || undefined,
    marketCap: marketCap || undefined,
    marketCapBucket: marketCapBucket || undefined,
    companyName: companyName || undefined,
    selectedPeriods,
    sortMetric,
    sortDirection: sortDir,
    limit: expanded ? Math.max(limit, 500) : limit,
    hierarchyLevel: level,
  });

  const sectorOptions = React.useMemo(() => {
    const rows = query.data?.rows ?? [];
    return [...new Set(rows.map((r) => r.sector).filter(Boolean))].sort();
  }, [query.data?.rows]);
  const industryOptions = React.useMemo(() => {
    const rows = query.data?.rows ?? [];
    return [...new Set(rows.filter((r) => !sector || r.sector === sector).map((r) => r.industry).filter(Boolean))].sort();
  }, [query.data?.rows, sector]);
  const subGroupOptions = React.useMemo(() => {
    const rows = query.data?.rows ?? [];
    return [...new Set(rows.filter((r) => !industry || r.industry === industry).map((r) => r.industrySubGroup).filter(Boolean))].sort();
  }, [query.data?.rows, industry]);

  const latestDateQuery = useLatestPriceTrendV2Date();
  const latestDate = latestDateQuery.data?.date ?? null;

  const rawRows = query.data?.rows ?? [];

  const handleCompanyNameChange = (value: string) => {
    setCompanyName(value);
    setSector("");
    setIndustry("");
    setIndustrySubGroup("");
    setMarketCap("");
    setMarketCapBucket("");
    setLevel("company");
  };

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

  const handleHierarchySelect = (target: PriceTrendV2Level) => {
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
    const idx = LEVEL_ORDER.indexOf(level);
    if (idx >= 0 && idx < LEVEL_ORDER.length - 1) setLevel(LEVEL_ORDER[idx + 1]);
  };
  const handleDrillUp = () =>
    handleHierarchySelect(
      level === "company" ? "industrySubGroup" : level === "industrySubGroup" ? "industry" : "sector",
    );

  const canDrillUp = level !== "sector";
  const canDrillDown = level !== "company";

  const searched = companyName.trim()
    ? rawRows.filter((r) => r.name.toLowerCase().includes(companyName.trim().toLowerCase()))
    : rawRows;
  const displayRows = searched;

  const periods = selectedPeriods;
  const sortedPeriods = React.useMemo(() => sortPeriodsChronologically(periods), [periods]);
  const { rows: gridRows, scales } = usePriceTrendTable(displayRows, sortedPeriods);

  const isLoading = query.isLoading;
  const isError = Boolean(query.error);
  const isEmpty = !isLoading && !isError && rawRows.length === 0;
  const isRefreshing = query.isFetching;

  const handlePeriodsChange = (newPeriods: PriceTrendV2Period[]) => {
    setSelectedPeriods(newPeriods);
    if (newPeriods.length && !newPeriods.includes(sortMetric as PriceTrendV2Period)) {
      setSortMetric(newPeriods[newPeriods.length - 1]);
    }
  };

  const handleExport = React.useCallback(() => {
    const header = ["Entity", "Sector", "Industry", ...sortedPeriods.map((p) => formatPeriodLabel(p))];
    const lines = [header.join(",")];
    for (const row of displayRows) {
      const cells = [
        `"${String(row.name ?? "").replace(/"/g, '""')}"`,
        `"${String(row.sector ?? "")}"`,
        `"${String(row.industry ?? "")}"`,
        ...sortedPeriods.map((p) => {
          const v = row[p];
          if (v === null || v === undefined || v === 9999) return "";
          const n = typeof v === "number" ? v : Number(v);
          return Number.isNaN(n) ? "" : `${n.toFixed(2)}`;
        }),
      ];
      lines.push(cells.join(","));
    }
    const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "price-trends-v2.csv";
    a.click();
    URL.revokeObjectURL(url);
  }, [displayRows, sortedPeriods]);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-3 border-b border-border pb-3">
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
              {lvl === "sector" ? "Sector" : lvl === "industry" ? "Industry" : lvl === "industrySubGroup" ? "Sub-Group" : "Company"}
            </button>
          ))}
        </div>
        <PriceTrendV2Toolbar
          sortMetric={sortMetric}
          sortDir={sortDir}
          expanded={expanded}
          fullscreen={fullscreen}
          refreshing={isRefreshing}
          selectedPeriods={selectedPeriods}
          onSortChange={setSortMetric}
          onSortDirToggle={() => setSortDir((d) => (d === "asc" ? "desc" : "asc"))}
          onExpandToggle={() => setExpanded((v) => !v)}
          onFullscreenToggle={() => setFullscreen((v) => !v)}
          onExport={handleExport}
          onRefresh={() => query.refetch()}
          onPeriodsChange={handlePeriodsChange}
          onDrillDown={handleDrillDown}
          onDrillUp={handleDrillUp}
          canDrillDown={canDrillDown}
          canDrillUp={canDrillUp}
          disabled={isLoading || isError}
        />
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
              <PriceTrendV2Filters
                sector={sector}
                industry={industry}
                industrySubGroup={industrySubGroup}
                marketCap={marketCap}
                marketCapBucket={marketCapBucket}
                limit={limit}
                companyName={companyName}
                sectorOptions={sectorOptions}
                industryOptions={industryOptions}
                subGroupOptions={subGroupOptions}
                onSectorChange={handleSector}
                onIndustryChange={handleIndustry}
                onSubGroupChange={handleIndustrySubGroup}
                onMarketCapChange={setMarketCap}
                onMarketCapBucketChange={setMarketCapBucket}
                onLimitChange={setLimit}
                onCompanyNameChange={handleCompanyNameChange}
                onReset={() => {
                  setSector("");
                  setIndustry("");
                  setIndustrySubGroup("");
                  setMarketCap("");
                  setMarketCapBucket("");
                  setCompanyName("");
                  setLimit(50);
                }}
                disabled={isLoading || isError}
              />
            </div>
          )}
        </div>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-sm text-muted-foreground">
          {level === "sector" ? "Sectors" : level === "industry" ? "Industries" : level === "industrySubGroup" ? "Sub-groups" : "Companies"}: <span className="font-medium text-foreground">{query.data?.total ?? rawRows.length}</span>
        </span>
        {latestDate && (
          <span className="text-xs text-muted-foreground">
            Data date: {new Date(latestDate).toLocaleDateString("en-IN")}
          </span>
        )}
      </div>

      <VisualizationContainer fullscreen={fullscreen} className="flex flex-col gap-3">
        {isError && (
          <div className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive">
            Failed to load price trends.
            <button type="button" onClick={() => query.refetch()} className="ml-2 underline">Retry</button>
          </div>
        )}
        {isEmpty && <VisualizationEmpty message="No data found. Try adjusting filters." />}
        {!isEmpty && (
          <PriceTrendV2Grid
            rows={gridRows}
            periods={sortedPeriods}
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
      </VisualizationContainer>
    </div>
  );
}
