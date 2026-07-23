import * as React from "react";
import { ChevronDown, ChevronRight } from "lucide-react";
import {
  VisualizationContainer,
  VisualizationEmpty,
} from "@/visualization/primitives";
import {
  usePriceTrend,
  useLatestPriceTrendDate,
} from "./PriceTrend.hooks";
import { useDebounce } from "@/shared/hooks";
import { PriceTrendToolbar } from "./PriceTrendToolbar";
import { PriceTrendFilters } from "./PriceTrendFilters";
import { PriceTrendTable } from "./PriceTrendTable";
import { PriceTrendTextTable } from "./PriceTrendTextTable";
import { PriceTrendGrid } from "./PriceTrendGrid";
import { usePriceTrendTable } from "./usePriceTrendTable";
import {
  getDefaultPeriods,
  sortPeriodsChronologically,
  formatPeriodLabel,
} from "./PriceTrend.utils";
import type {
  PriceTrendPeriod,
  PriceTrendMarketCap,
  PriceTrendMarketCapBucket,
  PriceTrendSortMetric,
  PriceTrendSortDir,
} from "./PriceTrend.types";

// Reverse of the backend's CAP_TIER_BUCKET: cap_class bucket -> large/mid/small tier.
const BUCKET_TO_TIER: Record<string, PriceTrendMarketCap> = {
  "top 10perc by mcap": "large",
  "50-90% by mcap": "mid",
  "bottom 50% by mcap": "small",
};

export function PriceTrendWidget() {
  const [sector, setSector] = React.useState("");
  const [industry, setIndustry] = React.useState("");
  const [industrySubGroup, setIndustrySubGroup] = React.useState("");
  const [marketCap, setMarketCap] = React.useState<PriceTrendMarketCap>("");
  const [marketCapBucket, setMarketCapBucket] = React.useState<PriceTrendMarketCapBucket>("");
  const [limit, setLimit] = React.useState(50);
  const [expanded, setExpanded] = React.useState(false);
  const [filtersExpanded, setFiltersExpanded] = React.useState(false);
  const [companyName, setCompanyName] = React.useState("");
  const [selectedPeriods, setSelectedPeriods] = React.useState<PriceTrendPeriod[]>(getDefaultPeriods());
  const [sortMetric, setSortMetric] = React.useState<PriceTrendSortMetric>("1d");
  const [sortDir, setSortDir] = React.useState<PriceTrendSortDir>("desc");
  const [fullscreen, setFullscreen] = React.useState(false);
  const [view, setView] = React.useState<"chart" | "table">("chart");

  const query = usePriceTrend({
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
  });

  // Option lists for the Sector / Industry / Sub-Group dropdowns.
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

  const latestDateQuery = useLatestPriceTrendDate();
  const latestDate = latestDateQuery.data?.date ?? null;

  const rawRows = query.data?.rows ?? [];

  // Typing in the company search resets the hierarchy + cap filters, because a
  // company can belong to any sector in the full universe.
  const handleCompanyNameChange = (value: string) => {
    setCompanyName(value);
    setSector("");
    setIndustry("");
    setIndustrySubGroup("");
    setMarketCap("");
    setMarketCapBucket("");
  };

  const handleSector = (value: string) => {
    setSector(value);
    setIndustry("");
    setIndustrySubGroup("");
  };
  const handleIndustry = (value: string) => {
    setIndustry(value);
    setIndustrySubGroup("");
  };
  const handleIndustrySubGroup = (value: string) => {
    setIndustrySubGroup(value);
  };

  const searched = companyName.trim()
    ? rawRows.filter((r) => r.name.toLowerCase().includes(companyName.trim().toLowerCase()))
    : rawRows;
  const displayRows = searched;

  const periods = selectedPeriods;
  const sortedPeriods = React.useMemo(() => sortPeriodsChronologically(periods), [periods]);
  const { rows: gridRows, scales } = usePriceTrendTable(displayRows, sortedPeriods);

  const chartHeight = Math.max(400, Math.min(200000, displayRows.length * 32));

  const isLoading = query.isLoading;
  const isError = Boolean(query.error);
  const isEmpty = !isLoading && !isError && rawRows.length === 0;
  const isRefreshing = query.isFetching;

  const handlePeriodsChange = (newPeriods: PriceTrendPeriod[]) => {
    setSelectedPeriods(newPeriods);
    if (newPeriods.length && !newPeriods.includes(sortMetric as PriceTrendPeriod)) {
      setSortMetric(newPeriods[newPeriods.length - 1]);
    }
  };

  const handleExport = React.useCallback(() => {
    const header = ["Company", "Sector", "Industry", ...sortedPeriods.map((p) => formatPeriodLabel(p))];
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
    a.download = "price-trends.csv";
    a.click();
    URL.revokeObjectURL(url);
  }, [displayRows, sortedPeriods]);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-3 border-b border-border pb-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <PriceTrendToolbar
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
            view={view}
            onViewChange={setView}
            disabled={isLoading || isError}
          />
          {latestDate && (
            <span className="text-xs text-muted-foreground">
              Data date: {new Date(latestDate).toLocaleDateString("en-IN")}
            </span>
          )}
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
              <PriceTrendFilters
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
           Companies: <span className="font-medium text-foreground">{query.data?.total ?? rawRows.length}</span>
         </span>
       </div>

       <VisualizationContainer fullscreen={fullscreen} className="flex flex-col gap-3">
        {isError && (
          <div className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive">
            Failed to load price trends.
            <button type="button" onClick={() => query.refetch()} className="ml-2 underline">Retry</button>
          </div>
        )}
        {isEmpty && <VisualizationEmpty message="No companies found. Try adjusting filters." />}
        {!isEmpty && view === "table" && (
          <PriceTrendTextTable
            rows={displayRows}
            periods={sortedPeriods}
            loading={isLoading}
            sortMetric={sortMetric}
            sortDir={sortDir}
            onSortChange={setSortMetric}
            onSortDirToggle={() => setSortDir((d) => (d === "asc" ? "desc" : "asc"))}
          />
        )}
        {!isEmpty && view === "chart" && (
          <PriceTrendGrid
            rows={gridRows}
            periods={sortedPeriods}
            scales={scales}
            sortMetric={sortMetric}
            sortDir={sortDir}
            onSortChange={setSortMetric}
            onSortDirToggle={() => setSortDir((d) => (d === "asc" ? "desc" : "asc"))}
            onExport={handleExport}
            onFullscreenToggle={() => setFullscreen((v) => !v)}
          />
        )}
      </VisualizationContainer>
    </div>
  );
}
