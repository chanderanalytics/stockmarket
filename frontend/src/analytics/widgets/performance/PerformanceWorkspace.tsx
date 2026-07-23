"use client";

import * as React from "react";
import { VisualizationContainer } from "@/visualization/primitives";
import type { CompanyPerformance, TradePerformance, PerformanceFilters } from "./types";
import { PerformanceFilters as PerformanceFiltersComponent } from "./PerformanceFilters";
import { PerformanceSummary } from "./PerformanceSummary";
import { CompanyPerformanceTable } from "./CompanyPerformanceTable";
import { TradeExplorerTable } from "./TradeExplorerTable";
import { useCompanyPerformance, useTradePerformance } from "./hooks";

const INITIAL_FILTERS: PerformanceFilters = {
  dateRange: "ALL",
  status: "ALL",
};

export function PerformanceWorkspace() {
  const [filters, setFilters] = React.useState<PerformanceFilters>(INITIAL_FILTERS);
  const [selectedCompanyId, setSelectedCompanyId] = React.useState<number | null>(null);
  const [companySearch, setCompanySearch] = React.useState("");
  const [companyPage, setCompanyPage] = React.useState(0);
  const [tradePage, setTradePage] = React.useState(0);
  const [companySort, setCompanySort] = React.useState<{ key: string; dir: "asc" | "desc" }>({
    key: "company_name",
    dir: "asc",
  });
  const [tradeSort, setTradeSort] = React.useState<{ key: string; dir: "asc" | "desc" }>({
    key: "entry_date",
    dir: "desc",
  });

  const companiesQuery = useCompanyPerformance({
    companyName: companySearch || undefined,
    status: filters.status !== "ALL" ? filters.status : undefined,
    limit: 25,
    offset: companyPage * 25,
  });

  const tradesQuery = useTradePerformance({
    company_id: selectedCompanyId ?? undefined,
    status: filters.status !== "ALL" ? filters.status : undefined,
    limit: 25,
    offset: tradePage * 25,
  });

  const companyRows = companiesQuery.data?.rows ?? [];
  const tradeRows = tradesQuery.data?.rows ?? [];
  const selectedCompany = companyRows.find((c: CompanyPerformance) => c.company_id === selectedCompanyId) ?? null;

  return (
    <VisualizationContainer fullscreen={false} className="flex flex-col gap-4">
      <div className="flex flex-col gap-3 border-b border-border pb-3">
        <PerformanceFiltersComponent
          filters={filters}
          onFiltersChange={setFilters}
          companySearch={companySearch}
          onCompanySearchChange={setCompanySearch}
        />
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="text-sm text-muted-foreground">
            {selectedCompanyId
              ? `Showing trades for: ${selectedCompany?.company_name ?? `Company ${selectedCompanyId}`}`
              : "Showing all companies · Select a company to view trades"}
          </div>
          {selectedCompanyId && (
            <button
              type="button"
              onClick={() => {
                setSelectedCompanyId(null);
                setTradePage(0);
              }}
              className="rounded-md border border-border px-2 py-1 text-xs hover:bg-accent"
            >
              Clear Selection
            </button>
          )}
        </div>
      </div>

      <PerformanceSummary />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <CompanyPerformanceTable
          rows={companyRows}
          loading={companiesQuery.isLoading}
          total={companiesQuery.data?.total ?? 0}
          page={companyPage}
          pageSize={25}
          sort={companySort}
          selectedCompanyId={selectedCompanyId}
          onSortChange={(key, dir) => setCompanySort({ key, dir })}
          onPageChange={setCompanyPage}
          onRowSelect={setSelectedCompanyId}
        />
        <TradeExplorerTable
          rows={tradeRows}
          loading={tradesQuery.isLoading}
          total={tradesQuery.data?.total ?? 0}
          page={tradePage}
          pageSize={25}
          sort={tradeSort}
          selectedCompanyId={selectedCompanyId}
          onSortChange={(key, dir) => setTradeSort({ key, dir })}
          onPageChange={setTradePage}
          onRowSelect={() => {}}
        />
      </div>
    </VisualizationContainer>
  );
}
