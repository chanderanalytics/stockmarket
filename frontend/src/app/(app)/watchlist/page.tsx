"use client";

import * as React from "react";
import Link from "next/link";
import { Star } from "lucide-react";
import { DataTable } from "@/shared/data-table";
import { Sparkline } from "@/shared/charts";
import { StatCard } from "@/components/data-display/stat-card";
import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { watchlistService } from "@/shared/api/services";
import { formatPct } from "@/lib/format";

export default function WatchlistPage() {
  const { data: watchlist } = useApiQuery(queryKeys.watchlist.all(), () => watchlistService.list());

  const columns = [
    { key: "symbol", header: "Symbol", sortable: true, cell: (r: any) => <Link href={`/stocks/${r.symbol}`} className="font-medium text-primary hover:underline">{r.symbol}</Link> },
    { key: "name", header: "Name", sortable: true, accessor: (r: any) => r.name },
    { key: "price", header: "Last", align: "right" as const, sortable: true, accessor: (r: any) => r.currentPrice },
    { key: "chg", header: "Chg %", align: "right" as const, sortable: true, accessor: (r: any) => r.changePct, cell: (r: any) => <span className={r.changePct >= 0 ? "text-success" : "text-destructive"}>{formatPct(r.changePct)}</span> },
    { key: "spark", header: "7d", align: "right" as const, cell: () => null },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-semibold tracking-tight">
          <Star className="h-5 w-5 text-primary" /> {watchlist?.name ?? "Watchlist"}
        </h1>
        <p className="text-sm text-muted-foreground">Tracked instruments and their intraday movement.</p>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard title="Instruments" value={watchlist ? String(watchlist.itemCount) : "—"} />
        <StatCard title="Advancers" value={watchlist ? String(watchlist.advancers) : "—"} trendUp icon={<Star className="h-4 w-4" />} />
        <StatCard title="Decliners" value={watchlist ? String(watchlist.decliners) : "—"} />
        <StatCard title="Avg Change" value={watchlist ? formatPct(watchlist.avgChangePercent) : "—"} trendUp={!!watchlist && watchlist.avgChangePercent >= 0} />
      </div>

      <DataTable
        data={watchlist?.items ?? []}
        columns={columns as any}
        rowKey={(r: any) => r.symbol}
        pageSize={10}
        selectable
        onRowClick={(r: any) => {}}
      />
    </div>
  );
}
