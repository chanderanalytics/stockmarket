"use client";

import * as React from "react";
import Link from "next/link";
import { ArrowUpRight, ArrowDownRight } from "lucide-react";
import { AreaChartCard } from "@/shared/charts";
import { DataTable } from "@/shared/data-table";
import { List } from "@/components/data-display/list";
import { Button } from "@/components/ui/button";
import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { marketService, watchlistService } from "@/shared/api/services";
import { formatPct } from "@/lib/format";
import type { MarketPulse } from "@/shared/api/types";
import { KPIStripWidget } from "@/analytics/widgets";
import type { KPIWidgetConfig, KPIStatus, KPISeverity } from "@/analytics/widgets";

function sentimentStatus(sentiment: MarketPulse["overallSentiment"]): KPIStatus {
  if (sentiment === "bullish") return "ok";
  if (sentiment === "bearish") return "warning";
  return "neutral";
}

function riskSeverity(count: number): KPISeverity {
  if (count >= 3) return "high";
  if (count >= 1) return "medium";
  return "low";
}

function formatPulseTime(timestamp: string): string {
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) return timestamp;
  return date.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" });
}

function mapPulseToKpis(pulse: MarketPulse | undefined): KPIWidgetConfig[] {
  if (!pulse) return [];
  const riskCount = pulse.risks?.length ?? 0;
  const severity = riskSeverity(riskCount);
  return [
    {
      id: "market-regime",
      title: "Market Regime",
      value: pulse.marketRegime,
      formattedValue: pulse.marketRegime,
      status: "info",
      tooltip: `Regime confidence: ${pulse.regimeConfidence}`,
    },
    {
      id: "market-sentiment",
      title: "Sentiment",
      value: pulse.overallSentiment,
      formattedValue: pulse.overallSentiment.charAt(0).toUpperCase() + pulse.overallSentiment.slice(1),
      status: sentimentStatus(pulse.overallSentiment),
      trend: "flat",
      tooltip: pulse.outlook,
    },
    {
      id: "risk-level",
      title: "Risk Level",
      value: riskCount,
      formattedValue: `${riskCount} ${riskCount === 1 ? "risk" : "risks"}`,
      severity,
      status: severity === "high" ? "error" : severity === "medium" ? "warning" : "ok",
      tooltip: pulse.risks?.join(", "),
    },
    {
      id: "last-updated",
      title: "Last Updated",
      value: pulse.timestamp,
      formattedValue: formatPulseTime(pulse.timestamp),
      status: "neutral",
      trend: "none",
    },
  ];
}

export default function DashboardPage() {
  const idxQ = useApiQuery(queryKeys.market.indices(), () => marketService.indices());
  const pulseQ = useApiQuery(queryKeys.market.pulse(), () => marketService.pulse());
  const wlQ = useApiQuery(queryKeys.watchlist.all(), () => watchlistService.list());
  const moversQ = useApiQuery(queryKeys.market.movers(), () => marketService.movers());

  const indices = idxQ.data ?? [];
  const pulse = pulseQ.data;
  const watchlist = wlQ.data;
  const movers = moversQ.data;

  const gainers = movers?.gainers ?? [];
  const losers = movers?.losers ?? [];
  const allMovers = [...gainers, ...losers];

  const columns = [
    { key: "symbol", header: "Symbol", sortable: true, cell: (r: any) => <Link href={`/stocks/${r.symbol}`} className="font-medium text-primary hover:underline">{r.symbol}</Link> },
    { key: "name", header: "Name", sortable: true, accessor: (r: any) => r.name },
    { key: "lastPrice", header: "Last", align: "right" as const, sortable: true, accessor: (r: any) => r.lastPrice },
    { key: "changePct", header: "Chg %", align: "right" as const, sortable: true, accessor: (r: any) => r.changePct, cell: (r: any) => <span className={r.changePct >= 0 ? "text-success" : "text-destructive"}>{formatPct(r.changePct)}</span> },
    { key: "trend", header: "Trend", align: "right" as const, cell: () => null },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Dashboard</h1>
          <p className="text-sm text-muted-foreground">Market overview and your tracked instruments.</p>
        </div>
        <Button asChild>
          <Link href="/screener">Open Screener</Link>
        </Button>
      </div>

      <KPIStripWidget
        items={mapPulseToKpis(pulse)}
        variant="cards"
        state={{
          loading: pulseQ.isLoading,
          error: pulseQ.error ? "Failed to load market pulse" : null,
          empty: !pulseQ.data,
          refreshing: pulseQ.isFetching,
        }}
        onRefresh={() => pulseQ.refetch()}
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <AreaChartCard
            title="Portfolio Performance"
            xKey="date"
            series={[{ key: "value", name: "Value" }]}
            data={[]}
            height={300}
          />
        </div>
        <div className="space-y-4">
          <h3 className="text-sm font-medium">Indices</h3>
          <div className="space-y-2">
            {indices.map((ix) => (
              <div key={ix.name} className="flex items-center justify-between rounded-md border border-border bg-card px-3 py-2">
                <span className="text-sm font-medium">{ix.name}</span>
                <div className="text-right">
                  <div className="text-sm tabular-nums">{ix.value.toLocaleString("en-IN")}</div>
                  <div className={`text-xs tabular-nums ${ix.changePct >= 0 ? "text-success" : "text-destructive"}`}>
                    {ix.changePct >= 0 ? <ArrowUpRight className="inline h-3 w-3" /> : <ArrowDownRight className="inline h-3 w-3" />}
                    {formatPct(ix.changePct)}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <DataTable
            title="Top Movers"
            data={allMovers}
            columns={columns as any}
            rowKey={(r: any) => r.symbol}
            pageSize={6}
            onRowClick={(r: any) => (window.location.href = `/stocks/${r.symbol}`)}
          />
        </div>
        <div>
          <h3 className="mb-3 text-sm font-medium">Watchlist</h3>
          <List
            items={watchlist?.items.map((it) => ({
              id: it.symbol,
              title: it.symbol,
              description: it.symbol,
              trailing: watchlist.avgChangePercent >= 0 ? <span className="text-success">{formatPct(watchlist.avgChangePercent)}</span> : <span className="text-destructive">{formatPct(watchlist.avgChangePercent)}</span>,
              href: `/stocks/${it.symbol}`,
            })) ?? []}
          />
        </div>
      </div>
    </div>
  );
}
