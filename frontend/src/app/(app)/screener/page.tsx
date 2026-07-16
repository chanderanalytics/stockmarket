"use client";

import * as React from "react";
import { Suspense } from "react";
import { Filter } from "lucide-react";
import { DataTable } from "@/shared/data-table";
import { TreemapCard } from "@/shared/charts";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useFilters } from "@/shared/hooks";
import { formatINR, formatPct } from "@/lib/format";
import { stocks, makeQuote } from "@/shared/mock/data";

function ScreenerInner() {
  const { filters, setFilter, reset } = useFilters({ sector: "", minChangePct: "" });

  const results = React.useMemo(() => {
    return stocks
      .map((s) => ({ stock: s, q: makeQuote(s) }))
      .filter(({ stock, q }) => {
        if (filters.sector && stock.sector !== filters.sector) return false;
        if (filters.minChangePct && q.changePct < Number(filters.minChangePct)) return false;
        return true;
      });
  }, [filters]);

  const columns = [
    { key: "symbol", header: "Symbol", sortable: true, cell: (r: any) => <span className="font-medium text-primary">{r.stock.symbol}</span> },
    { key: "name", header: "Name", sortable: true, accessor: (r: any) => r.stock.name },
    { key: "sector", header: "Sector", sortable: true, accessor: (r: any) => r.stock.sector },
    { key: "price", header: "Price", align: "right" as const, sortable: true, accessor: (r: any) => r.q.lastPrice, cell: (r: any) => formatINR(r.q.lastPrice) },
    { key: "chg", header: "Chg %", align: "right" as const, sortable: true, accessor: (r: any) => r.q.changePct, cell: (r: any) => <span className={r.q.changePct >= 0 ? "text-success" : "text-destructive"}>{formatPct(r.q.changePct)}</span> },
  ];

  return (
    <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
      <Card className="h-fit space-y-4 p-4 lg:col-span-1">
        <h3 className="flex items-center gap-2 text-sm font-medium">
          <Filter className="h-4 w-4" /> Filters
        </h3>
        <div className="space-y-1.5">
          <Label htmlFor="sector">Sector</Label>
          <select
            id="sector"
            className="h-9 w-full rounded-md border border-input bg-transparent px-2 text-sm"
            value={filters.sector ?? ""}
            onChange={(e) => setFilter("sector", e.target.value)}
          >
            <option value="">All sectors</option>
            {Array.from(new Set(stocks.map((s) => s.sector))).map((sec) => (
              <option key={sec} value={sec}>
                {sec}
              </option>
            ))}
          </select>
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="minChangePct">Min change %</Label>
          <Input id="minChangePct" type="number" placeholder="0" value={filters.minChangePct ?? ""} onChange={(e) => setFilter("minChangePct", e.target.value)} />
        </div>
        <Button variant="outline" className="w-full" onClick={reset}>
          Reset
        </Button>
        <p className="text-xs text-muted-foreground">{results.length} results · synced to URL</p>
      </Card>

      <div className="space-y-4 lg:col-span-3">
        <DataTable data={results} columns={columns as any} rowKey={(r: any) => r.stock.symbol} pageSize={8} />
        <TreemapCard
          title="Market Cap Allocation"
          data={results.map((r) => ({ name: r.stock.symbol, size: r.stock.marketCap ?? 0 }))}
          height={260}
        />
      </div>
    </div>
  );
}

export default function ScreenerPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Screener</h1>
        <p className="text-sm text-muted-foreground">Filter the universe and visualise allocation.</p>
      </div>
      <Suspense fallback={<div className="text-sm text-muted-foreground">Loading…</div>}>
        <ScreenerInner />
      </Suspense>
    </div>
  );
}
