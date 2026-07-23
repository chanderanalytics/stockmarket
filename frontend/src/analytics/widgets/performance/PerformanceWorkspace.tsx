"use client";

import * as React from "react";
import { VisualizationContainer } from "@/visualization/primitives";
import { PerformanceFilters } from "./PerformanceFilters";
import { PerformanceSummary } from "./PerformanceSummary";
import { CompanyPerformanceTable } from "./CompanyPerformanceTable";
import { TradeExplorerTable } from "./TradeExplorerTable";

export function PerformanceWorkspace() {
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [hasFilters, setHasFilters] = React.useState(false);

  return (
    <VisualizationContainer fullscreen={false} className="flex flex-col gap-4">
      <div className="flex flex-col gap-3 border-b border-border pb-3">
        <PerformanceFilters />
        <div className="flex items-center justify-between">
          <div className="text-sm text-muted-foreground">
            {hasFilters ? "Filtered performance view" : "Showing all performance data"}
          </div>
        </div>
      </div>

      {error && (
        <div className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive">
          {error}
        </div>
      )}

      {!error && !loading && (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
          <div className="lg:col-span-1">
            <PerformanceSummary />
          </div>
          <div className="lg:col-span-2">
            <CompanyPerformanceTable />
          </div>
        </div>
      )}

      {!error && !loading && (
        <div className="mt-2">
          <TradeExplorerTable />
        </div>
      )}
    </VisualizationContainer>
  );
}
