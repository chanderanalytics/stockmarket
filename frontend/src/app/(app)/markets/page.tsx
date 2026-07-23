"use client";

import * as React from "react";
import { ArrowUpRight, ArrowDownRight } from "lucide-react";
import { Heatmap, VolumeProfileChart } from "@/shared/charts";
import { DataTable } from "@/shared/data-table";
import { StatCard } from "@/components/data-display/stat-card";
import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { marketService, volumeProfileService } from "@/shared/api/services";
import { formatPct } from "@/lib/format";
import type { VolumeProfileRow } from "@/shared/charts/volume-profile-chart";

export default function MarketsPage() {
  const idxQ = useApiQuery(queryKeys.market.indices(), () => marketService.indices());
  const moversQ = useApiQuery(queryKeys.market.movers(), () => marketService.movers());
  const sectorsQ = useApiQuery(queryKeys.market.sectors(), () => marketService.sectors());
  const volumeQ = useApiQuery(
    queryKeys.volumeProfile.data({ level: "company", limit: 50 }),
    () => volumeProfileService.data({ level: "company", limit: 50 }),
  );
  const statusQ = useApiQuery(queryKeys.market.status(), () => marketService.status(), {
    staleTime: 60_000,
  });

  const indices = idxQ.data ?? [];
  const movers = moversQ.data;
  const sectors = sectorsQ.data ?? [];
  const volumeRows = (volumeQ.data?.rows ?? []) as VolumeProfileRow[];

  const gainers = movers?.gainers ?? [];
  const losers = movers?.losers ?? [];

  const asOf = statusQ.data?.asOf ?? "";
  const formattedDate = asOf
    ? new Date(asOf).toLocaleDateString("en-IN", {
        day: "2-digit",
        month: "short",
        year: "numeric",
      })
    : "";

  const heatmapRows = React.useMemo(() => sectors.map((s) => s.sector), [sectors]);
  const heatmapCols = React.useMemo(() => ["Return"], []);
  const heatmapValues = React.useMemo(() => sectors.map((s) => [s.avgReturn]), [sectors]);

  const columns = [
    { key: "symbol", header: "Symbol", sortable: true, cell: (r: any) => <span className="font-medium">{r.symbol}</span> },
    { key: "name", header: "Name", sortable: true, accessor: (r: any) => r.name },
    { key: "price", header: "Last", align: "right" as const, sortable: true, accessor: (r: any) => r.lastPrice },
    { key: "chg", header: "Chg %", align: "right" as const, sortable: true, accessor: (r: any) => r.changePct, cell: (r: any) => <span className={r.changePct >= 0 ? "text-success" : "text-destructive"}>{formatPct(r.changePct)}</span> },
  ];

  const handleVolumeDrillDown = React.useCallback((nextLevel: "sector" | "industry" | "company", _id: string, _name: string) => {
    volumeQ.refetch();
  }, [volumeQ]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Markets</h1>
          <p className="text-sm text-muted-foreground">Indices, movers and sector heatmap.</p>
        </div>
        {formattedDate && (
          <span className="text-xs text-muted-foreground">
            Data as of {formattedDate}
          </span>
        )}
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-5">
        {indices.map((ix) => (
          <StatCard
            key={ix.name}
            title={ix.name}
            value={ix.value.toLocaleString("en-IN")}
            trend={formatPct(ix.changePct)}
            trendUp={ix.changePct >= 0}
          />
        ))}
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <DataTable title="Top Gainers" data={gainers} columns={columns} rowKey={(r: any) => r.symbol} pageSize={6} />
        <DataTable title="Top Losers" data={losers} columns={columns} rowKey={(r: any) => r.symbol} pageSize={6} />
      </div>

      <div className="rounded-lg border border-border bg-card p-4">
        <h3 className="mb-3 text-sm font-medium">Sector Performance (1D %)</h3>
        <Heatmap
          rows={heatmapRows}
          cols={heatmapCols}
          values={heatmapValues}
          formatValue={(v) => formatPct(v)}
        />
      </div>

      <div className="rounded-lg border border-border bg-card p-4">
        <VolumeProfileChart
          title="Volume Profiling - Averages"
          data={volumeRows}
          level="company"
          state={volumeQ.status === "pending" ? "loading" : volumeQ.status === "error" ? "error" : volumeRows.length === 0 ? "empty" : "ready"}
          error={volumeQ.error instanceof Error ? volumeQ.error.message : undefined}
          height={420}
          onDrillDown={handleVolumeDrillDown}
          exportName="volume-profile.png"
        />
      </div>
    </div>
  );
}
