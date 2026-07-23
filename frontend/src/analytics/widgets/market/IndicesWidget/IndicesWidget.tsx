"use client";

import * as React from "react";
import { GripVertical } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuCheckboxItem,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import {
  VisualizationContainer,
  VisualizationEmpty,
} from "@/visualization/primitives";
import {
  useIndicesFeatures,
  useIndicesLatestDate,
  useIndicesRegionalStrength,
  useIndexPriceHistory,
} from "./hooks";
import type { IndexFeatureRow, ReturnSortKey, SortKey, SortDir } from "./types";
import { RETURN_PERIODS } from "./types";
import { IndexPerformanceTable } from "./IndexPerformanceTable";
import { ReturnsHeatmap } from "./ReturnsHeatmap";
import { PerformanceBarChart } from "./PerformanceBarChart";
import { IndexPriceTimeSeries } from "./IndexPriceTimeSeries";
import { RegionalStrengthSummary } from "./RegionalStrengthSummary";

const DEFAULT_PERIODS: ReturnSortKey[] = [
  "return_1d",
  "return_5d",
  "return_21d",
  "return_63d",
  "return_126d",
  "return_252d",
];

interface DrillState {
  name: string;
  ticker: string;
}

const PERIOD_LABELS: Record<ReturnSortKey, string> = {
  return_1d: "1D",
  return_2d: "2D",
  return_3d: "3D",
  return_4d: "4D",
  return_5d: "5D",
  return_21d: "1M",
  return_63d: "3M",
  return_126d: "6M",
  return_252d: "1Y",
  return_504d: "2Y",
  return_756d: "3Y",
  return_1260d: "5Y",
  return_2520d: "10Y",
};

export function IndicesWidget() {
  const [limit, setLimit] = React.useState(50);
  const [expanded, setExpanded] = React.useState(false);
  const [sortKey, setSortKey] = React.useState<SortKey>("return_21d");
  const [sortDir, setSortDir] = React.useState<SortDir>("desc");
  const [tableSortKey, setTableSortKey] = React.useState<SortKey>("return_21d");
  const [tableSortDir, setTableSortDir] = React.useState<SortDir>("desc");
  const [activeTab, setActiveTab] = React.useState<"table" | "heatmap" | "bars" | "timeseries" | "regional">("table");
  const [drill, setDrill] = React.useState<DrillState>({ name: "", ticker: "" });
  const [selectedPeriods, setSelectedPeriods] = React.useState<ReturnSortKey[]>(["return_21d"]);
  const [activeCategory, setActiveCategory] = React.useState<"regions" | "commodities">("regions");

  const activePeriod = selectedPeriods[0] ?? "return_21d";

  const sortedSelectedPeriods = React.useMemo(
    () => [...selectedPeriods].sort((a, b) => {
      const ai = RETURN_PERIODS.findIndex((x) => x.key === a);
      const bi = RETURN_PERIODS.findIndex((x) => x.key === b);
      return ai - bi;
    }),
    [selectedPeriods],
  );

  React.useEffect(() => {
    setSortKey(activePeriod);
  }, [activePeriod]);

  const handlePeriodChange = (next: ReturnSortKey) => {
    setSelectedPeriods([next]);
  };

  const featuresQuery = useIndicesFeatures({
    limit: expanded ? Math.max(limit, 500) : limit,
  });

  const latestDateQuery = useIndicesLatestDate();

  const priceHistoryQuery = useIndexPriceHistory({
    name: drill.name || undefined,
    ticker: drill.ticker || undefined,
    days: 252,
  });

  const regionalQuery = useIndicesRegionalStrength({ period: "21d" });

  const rawRows: IndexFeatureRow[] = featuresQuery.data?.rows ?? [];
  const latestDate = latestDateQuery.data?.date ?? null;

  const filteredRows = React.useMemo(() => {
    if (activeCategory === "regions") return rawRows.filter((r) => r.region !== "Commodities");
    if (activeCategory === "commodities") return rawRows.filter((r) => r.region === "Commodities");
    return rawRows;
  }, [rawRows, activeCategory]);

  const sortedRows = React.useMemo(() => {
    const rows = [...filteredRows];
    rows.sort((a, b) => {
      const sortKeyLocal = tableSortKey;
      const aVal = a[sortKeyLocal];
      const bVal = b[sortKeyLocal];
      if (aVal === null && bVal === null) return 0;
      if (aVal === null) return 1;
      if (bVal === null) return -1;
      const aStr = typeof aVal === "string";
      const bStr = typeof bVal === "string";
      if (aStr && bStr) {
        return tableSortDir === "asc" ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
      }
      const aNum = Number(aVal);
      const bNum = Number(bVal);
      return tableSortDir === "asc" ? aNum - bNum : bNum - aNum;
    });
    return rows;
  }, [filteredRows, tableSortKey, tableSortDir]);

  const handleRowClick = React.useCallback((name: string, ticker: string) => {
    setDrill({ name, ticker });
    setActiveTab("timeseries");
  }, []);

  const handleExport = React.useCallback(() => {
    const header = ["Name", "Ticker", "Region", "Price", ...DEFAULT_PERIODS.map((p) => p.replace("return_", ""))];
    const lines = [header.join(",")];
    for (const row of sortedRows) {
      const cells = [
        `"${String(row.name ?? "").replace(/"/g, '""')}"`,
        `"${String(row.ticker ?? "")}"`,
        `"${String(row.region ?? "")}"`,
        row.close != null ? String(Number(row.close).toFixed(1)) : "",
        ...DEFAULT_PERIODS.map((p) => {
          const v = row[p];
          return v !== null && v !== undefined ? String(Number(v).toFixed(1)) : "";
        }),
      ];
      lines.push(cells.join(","));
    }
    const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "indices-performance.csv";
    a.click();
    URL.revokeObjectURL(url);
  }, [sortedRows]);

  const isLoading = featuresQuery.isLoading;
  const isError = Boolean(featuresQuery.error);
  const isEmpty = !isLoading && !isError && rawRows.length === 0;

  const BAR_CHART_PERIODS = 3;

  const togglePeriod = (period: ReturnSortKey) => {
    setSelectedPeriods((prev) => {
      if (prev.includes(period)) {
        if (prev.length > 1) return prev.filter((p) => p !== period);
        return prev;
      }
      return [...prev, period];
    });
  };

  const toggleAll = () => {
    setSelectedPeriods((prev) => {
      if (prev.length >= RETURN_PERIODS.length) return ["return_21d"];
      return [...RETURN_PERIODS].map((p) => p.key);
    });
  };

  const barChartPeriods = selectedPeriods.slice(0, BAR_CHART_PERIODS);

  return (
    <VisualizationContainer fullscreen={false} className="flex flex-col gap-4">
      <div className="flex flex-col gap-3 border-b border-border pb-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button
                type="button"
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
                checked={selectedPeriods.length >= RETURN_PERIODS.length}
                onCheckedChange={toggleAll}
              >
                {selectedPeriods.length >= RETURN_PERIODS.length ? "Unselect All" : "Select All"}
              </DropdownMenuCheckboxItem>
              <DropdownMenuSeparator />
              {RETURN_PERIODS.map((period) => (
                <DropdownMenuCheckboxItem
                  key={period.key}
                  checked={selectedPeriods.includes(period.key)}
                  onCheckedChange={() => togglePeriod(period.key)}
                  onSelect={(e) => e.preventDefault()}
                >
                  {PERIOD_LABELS[period.key]}
                </DropdownMenuCheckboxItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
          <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
            <span className="font-medium text-foreground">View:</span>
            {[
              { key: "table", label: "Performance" },
              { key: "heatmap", label: "Heatmap" },
              { key: "bars", label: "Bar Chart" },
              { key: "timeseries", label: "Price History" },
              { key: "regional", label: "Regional" },
            ].map((tab) => (
              <button
                key={tab.key}
                type="button"
                onClick={() => setActiveTab(tab.key as typeof activeTab)}
                className={`rounded-md px-2 py-1 ${activeTab === tab.key ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>
        {latestDate && (
          <span className="text-xs text-muted-foreground">
            Data as of: {new Date(latestDate).toLocaleDateString("en-IN")}
          </span>
        )}
        <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={() => setExpanded((v) => !v)}
              className="rounded-md border border-border px-2.5 py-1.5 text-xs hover:bg-accent"
            >
              {expanded ? "Show Less" : "Show More"}
            </button>
            <button
              type="button"
              onClick={handleExport}
              className="rounded-md border border-border px-2.5 py-1.5 text-xs hover:bg-accent"
            >
              Export CSV
            </button>
            <button
              type="button"
              onClick={() => featuresQuery.refetch()}
              className="rounded-md border border-border px-2.5 py-1.5 text-xs hover:bg-accent"
            >
              Refresh
            </button>
            {drill.name && (
              <button
                type="button"
                onClick={() => { setDrill({ name: "", ticker: "" }); setActiveTab("table"); }}
                className="rounded-md border border-border px-2.5 py-1.5 text-xs hover:bg-accent"
              >
                Clear Selection
              </button>
            )}
          </div>
        </div>

        {isError ? (
          <div className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive">
            Failed to load indices.
            <button type="button" onClick={() => featuresQuery.refetch()} className="ml-2 underline">Retry</button>
          </div>
        ) : isEmpty ? (
          <VisualizationEmpty message="No index data found. Try adjusting filters." />
        ) : (
          <>
            {activeTab === "table" && (
              <div className="flex flex-col gap-3">
                <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
                  <span className="font-medium text-foreground">Type:</span>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("regions")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "regions" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Regions
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("commodities")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "commodities" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Commodities
                  </button>
                </div>
                <IndexPerformanceTable
                  rows={sortedRows}
                  sortKey={tableSortKey}
                  sortDir={tableSortDir}
                  onSortChange={setTableSortKey}
                  onSortDirToggle={() => setTableSortDir((d) => (d === "asc" ? "desc" : "asc"))}
                  periods={sortedSelectedPeriods}
                  onRowClick={handleRowClick}
                />
              </div>
            )}
            {activeTab === "heatmap" && (
              <div className="flex flex-col gap-3">
                <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
                  <span className="font-medium text-foreground">Type:</span>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("regions")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "regions" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Regions
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("commodities")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "commodities" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Commodities
                  </button>
                </div>
                <ReturnsHeatmap
                  rows={filteredRows}
                  periods={sortedSelectedPeriods}
                  sortKey={sortKey as ReturnSortKey}
                  sortDir={sortDir}
                  onSortChange={setSortKey}
                  onSortDirToggle={() => setSortDir((d) => (d === "asc" ? "desc" : "asc"))}
                  loading={isLoading}
                />
              </div>
            )}
            {activeTab === "bars" && (
              <div className="flex flex-col gap-3">
                <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
                  <span className="font-medium text-foreground">Type:</span>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("regions")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "regions" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Regions
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("commodities")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "commodities" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Commodities
                  </button>
                </div>
                <PerformanceBarChart
                  rows={filteredRows}
                  periods={barChartPeriods}
                  loading={isLoading}
                  sortKey={sortKey as ReturnSortKey}
                  sortDir={sortDir}
                  onSortChange={setSortKey}
                  onSortDirToggle={() => setSortDir((d) => (d === "asc" ? "desc" : "asc"))}
                />
              </div>
            )}
            {activeTab === "timeseries" && (
              <div className="flex flex-col gap-3">
                <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
                  <span className="font-medium text-foreground">Index:</span>
                  <select
                    value={`${drill.name}|${drill.ticker}`}
                    onChange={(e) => {
                      const [name, ticker] = e.target.value.split("|");
                      setDrill({ name, ticker });
                    }}
                    className="rounded-md border border-border bg-background px-2 py-1 text-sm"
                  >
                    <option value="">Select index</option>
                    {filteredRows.map((r) => (
                      <option key={r.ticker} value={`${r.name}|${r.ticker}`}>
                        {r.name} ({r.ticker})
                      </option>
                    ))}
                  </select>
                  <span className="font-medium text-foreground ml-2">Type:</span>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("regions")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "regions" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Regions
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("commodities")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "commodities" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Commodities
                  </button>
                </div>
                {drill.name && (
                  <IndexPriceTimeSeries
                    series={[{ name: drill.name, data: priceHistoryQuery.data ?? [] }]}
                    loading={priceHistoryQuery.isLoading}
                  />
                )}
              </div>
            )}
            {activeTab === "regional" && (
              <div className="flex flex-col gap-3">
                <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
                  <span className="font-medium text-foreground">Type:</span>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("regions")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "regions" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Regions
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveCategory("commodities")}
                    className={`rounded-md px-2 py-1 ${activeCategory === "commodities" ? "bg-accent text-accent-foreground" : "hover:text-foreground"}`}
                  >
                    Commodities
                  </button>
                </div>
                <RegionalStrengthSummary
                  rows={regionalQuery.data?.rows?.filter((r) => activeCategory === "commodities" ? r.region === "Commodities" : r.region !== "Commodities") ?? []}
                  period={regionalQuery.data?.period ?? "21d"}
                  loading={regionalQuery.isLoading}
                />
              </div>
            )}
          </>
        )}
      </div>

      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
        <span>
          Showing: {sortedRows.length} / {featuresQuery.data?.total ?? rawRows.length}
        </span>
      </div>
    </VisualizationContainer>
  );
}
