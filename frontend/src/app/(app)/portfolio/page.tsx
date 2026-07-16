"use client";

import * as React from "react";
import Link from "next/link";
import { Briefcase, TrendingUp, TrendingDown } from "lucide-react";
import { DataTable } from "@/shared/data-table";
import { AreaChartCard, TreemapCard } from "@/shared/charts";
import { StatCard } from "@/components/data-display/stat-card";
import { Tag } from "@/components/data-display/tag";
import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { portfolioService } from "@/shared/api/services";
import { formatINR, formatPct } from "@/lib/format";

export default function PortfolioPage() {
  const { data: portfolio } = useApiQuery(queryKeys.portfolio.summary(), () => portfolioService.summary());

  const columns = [
    { key: "symbol", header: "Symbol", sortable: true, cell: (r: any) => <Link href={`/stocks/${r.symbol}`} className="font-medium text-primary hover:underline">{r.symbol}</Link> },
    { key: "qty", header: "Qty", align: "right" as const, sortable: true, accessor: (r: any) => r.quantity },
    { key: "avg", header: "Avg", align: "right" as const, sortable: true, accessor: (r: any) => r.avgPrice, cell: (r: any) => formatINR(r.avgPrice) },
    { key: "last", header: "Last", align: "right" as const, sortable: true, accessor: (r: any) => r.lastPrice, cell: (r: any) => formatINR(r.lastPrice) },
    { key: "pnl", header: "P&L", align: "right" as const, sortable: true, accessor: (r: any) => r.pnl, cell: (r: any) => <span className={r.pnl >= 0 ? "text-success" : "text-destructive"}>{formatINR(r.pnl)}</span> },
    { key: "pnlPct", header: "P&L %", align: "right" as const, sortable: true, accessor: (r: any) => r.pnlPct, cell: (r: any) => <Tag tone={r.pnlPct >= 0 ? "success" : "destructive"}>{formatPct(r.pnlPct)}</Tag> },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-semibold tracking-tight">
          <Briefcase className="h-5 w-5" /> {portfolio?.name ?? "Portfolio"}
        </h1>
        <p className="text-sm text-muted-foreground">Holdings, performance and allocation.</p>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard title="Total Value" value={portfolio ? formatINR(portfolio.totalValue) : "—"} icon={<Briefcase className="h-4 w-4" />} />
        <StatCard title="Total P&L" value={portfolio ? formatINR(portfolio.totalPnl) : "—"} trend={portfolio ? formatPct(portfolio.totalPnlPercent) : undefined} trendUp={!!portfolio && portfolio.totalPnl >= 0} icon={portfolio && portfolio.totalPnl >= 0 ? <TrendingUp className="h-4 w-4" /> : <TrendingDown className="h-4 w-4" />} />
        <StatCard title="Holdings" value={portfolio ? String(portfolio.holdingsCount) : "—"} />
        <StatCard title="Exposure" value={portfolio ? `${portfolio.exposure.toFixed(1)}%` : "—"} />
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <AreaChartCard title="Portfolio Value" xKey="date" series={[{ key: "value", name: "Value" }]} data={[]} height={280} />
        </div>
        <TreemapCard title="Allocation" data={[]} height={280} />
      </div>

      <DataTable data={[]} columns={columns as any} rowKey={(r: any) => r.symbol} pageSize={10} />
    </div>
  );
}
