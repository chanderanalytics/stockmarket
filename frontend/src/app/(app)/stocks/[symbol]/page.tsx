"use client";

import * as React from "react";
import Link from "next/link";
import { use } from "react";
import { ArrowLeft } from "lucide-react";
import { LineChartCard, BarChartCard } from "@/shared/charts";
import { StatCard } from "@/components/data-display/stat-card";
import { List } from "@/components/data-display/list";
import { Tag } from "@/components/data-display/tag";
import { Breadcrumbs } from "@/components/navigation";
import { formatINR, formatPct, formatCompact } from "@/lib/format";
import { useApiQuery } from "@/shared/hooks";
import { queryKeys } from "@/shared/api/query-keys";
import { stocksService } from "@/shared/api/services";

export default function StockDetailPage({ params }: { params: Promise<{ symbol: string }> }) {
  const { symbol } = use(params);
  const snapshotQ = useApiQuery(queryKeys.stocks.snapshot(symbol), () => stocksService.snapshot(symbol));

  const stock = snapshotQ.data;
  const prices = stock?.prices ?? [];

  const quote = React.useMemo(() => {
    if (!prices.length) return null;
    const latest = prices[prices.length - 1];
    const prev = prices.length > 1 ? prices[prices.length - 2] : latest;
    const change = latest.close - prev.close;
    const changePct = prev.close !== 0 ? (change / prev.close) * 100 : 0;
    return {
      lastPrice: latest.close,
      change,
      changePct,
      open: latest.open,
      high: latest.high,
      low: latest.low,
      close: latest.close,
      volume: latest.volume,
    };
  }, [prices]);

  const series = React.useMemo(
    () => prices.map((c) => ({ date: c.time, close: c.close, volume: c.volume })),
    [prices],
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-3">
        <Breadcrumbs items={[{ label: "Markets", href: "/markets" }, { label: symbol }]} />
        <Link href="/dashboard" className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
          <ArrowLeft className="h-4 w-4" /> Dashboard
        </Link>
      </div>

      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">{symbol}</h1>
          <p className="text-sm text-muted-foreground">
            {stock?.name ?? ""} · {stock?.exchange ?? ""} · <span className="text-foreground">{stock?.sector ?? ""}</span>
          </p>
        </div>
        <div className="text-right">
          <div className="text-2xl tabular-nums">{quote ? formatINR(quote.lastPrice) : "—"}</div>
          {quote && <Tag tone={quote.changePct >= 0 ? "success" : "destructive"}>{formatPct(quote.changePct)}</Tag>}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-5">
        <StatCard title="Open" value={quote ? formatINR(quote.open) : "—"} />
        <StatCard title="High" value={quote ? formatINR(quote.high) : "—"} />
        <StatCard title="Low" value={quote ? formatINR(quote.low) : "—"} />
        <StatCard title="Volume" value={quote ? formatCompact(quote.volume) : "—"} />
        <StatCard title="Mkt Cap" value={formatCompact(stock?.marketCap ?? 0)} />
      </div>

      <LineChartCard title="Price (60d)" xKey="date" series={[{ key: "close", name: symbol }]} data={series} height={300} />
      <BarChartCard title="Volume" xKey="date" series={[{ key: "volume", name: "Volume" }]} data={series} height={220} />

      <div>
        <h3 className="mb-3 text-sm font-medium">Related News</h3>
        <List items={[]} />
      </div>
    </div>
  );
}
