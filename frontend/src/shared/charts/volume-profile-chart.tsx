"use client";

import * as React from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import { ChartFrame } from "@/shared/charts/chart-frame";
import { ChartTooltip, colorAt } from "@/shared/charts/chart-theme";

export type VolumeProfileLevel = "sector" | "industry" | "company";

export type VolumeProfileRow = {
  id: string;
  name: string;
  sector: string;
  industry: string;
  industrySubGroup: string | null;
  volume: number;
  avgVol1W: number;
  avgVol1M: number;
  avgVol1Y: number;
  volSortPct: number;
  marketCap: number;
  companyCount: number | null;
  total: number;
  volumePct?: number;
  avgVol1WPct?: number;
  avgVol1MPct?: number;
  avgVol1YPct?: number;
  sortVolume?: number;
  sortAvgVol1W?: number;
  sortAvgVol1M?: number;
  sortAvgVol1Y?: number;
};

type Props = {
  data: VolumeProfileRow[];
  level: VolumeProfileLevel;
  height?: number;
  title?: React.ReactNode;
  state?: "loading" | "error" | "empty" | "ready";
  error?: string;
  exportName?: string;
  onDrillDown?: (level: VolumeProfileLevel, id: string, name: string) => void;
};

const SERIES = [
  { key: "volume", name: "Volume", color: "#2563eb" },
  { key: "avgVol1W", name: "AvgVol_1W", color: "#f97316" },
  { key: "avgVol1M", name: "AvgVol_1M", color: "#a855f7" },
  { key: "avgVol1Y", name: "AvgVol_1Y", color: "#6366f1" },
];

export function VolumeProfileChart({
  data,
  level,
  height = 520,
  title = "Volume Profiling - Averages",
  state = "ready",
  error,
  exportName = "volume-profile.png",
  onDrillDown,
}: Props) {
  const normalized = React.useMemo(() => {
    return data.map((row) => {
      const total = row.total || 1;
      return {
        ...row,
        volumePct: +((row.volume / total) * 100).toFixed(2),
        avgVol1WPct: +((row.avgVol1W / total) * 100).toFixed(2),
        avgVol1MPct: +((row.avgVol1M / total) * 100).toFixed(2),
        avgVol1YPct: +((row.avgVol1Y / total) * 100).toFixed(2),
      };
    });
  }, [data]);

  const [sortBy, setSortBy] = React.useState<"volume" | "avgVol1W" | "avgVol1M" | "avgVol1Y">("avgVol1W");
  const [sortDir, setSortDir] = React.useState<"asc" | "desc">("desc");

  const sorted = React.useMemo(() => {
    const rows = [...normalized];
    rows.sort((a, b) => {
      let av: number, bv: number;
      if (sortBy === "volume") {
        av = a.sortVolume ?? a.volume;
        bv = b.sortVolume ?? b.volume;
      } else if (sortBy === "avgVol1W") {
        av = a.sortAvgVol1W ?? a.avgVol1W;
        bv = b.sortAvgVol1W ?? b.avgVol1W;
      } else if (sortBy === "avgVol1M") {
        av = a.sortAvgVol1M ?? a.avgVol1M;
        bv = b.sortAvgVol1M ?? b.avgVol1M;
      } else {
        av = a.sortAvgVol1Y ?? a.avgVol1Y;
        bv = b.sortAvgVol1Y ?? b.avgVol1Y;
      }
      return sortDir === "asc" ? av - bv : bv - av;
    });
    return rows;
  }, [normalized, sortBy, sortDir]);

  const cycleSort = (key: "volume" | "avgVol1W" | "avgVol1M" | "avgVol1Y") => {
    if (sortBy === key) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortBy(key);
      setSortDir("desc");
    }
  };

  const handleYClick = (row: VolumeProfileRow) => {
    if (!onDrillDown) return;
    if (level === "sector") {
      onDrillDown("industry", row.id, row.name);
    } else if (level === "industry") {
      onDrillDown("company", row.id, row.name);
    }
  };

  return (
    <ChartFrame title={title} state={state} error={error} height={height} exportName={exportName}>
      <div className="mb-1 flex flex-wrap items-center gap-1 text-xs">
        <span className="text-muted-foreground">Sort by</span>
        {([
          { key: "volume", label: "Volume" },
          { key: "avgVol1W", label: "AvgVol_1W" },
          { key: "avgVol1M", label: "AvgVol_1M" },
          { key: "avgVol1Y", label: "AvgVol_1Y" },
        ] as const).map(({ key, label }) => (
          <button
            key={key}
            onClick={() => cycleSort(key)}
            className={`rounded-md border px-2 py-1 ${
              sortBy === key ? "border-primary bg-primary/10 text-primary" : "border-border hover:bg-muted"
            }`}
          >
            {label} {sortBy === key ? (sortDir === "asc" ? "↑" : "↓") : ""}
          </button>
        ))}
        {level !== "company" && (
          <button
            onClick={() => onDrillDown?.("sector", "", "All Sectors")}
            className="rounded-md border border-border px-2 py-1 hover:bg-muted"
          >
            Drill Up
          </button>
        )}
      </div>
      <ResponsiveContainer width="100%" height={height - 40}>
        <BarChart data={sorted} layout="horizontal" margin={{ top: 4, right: 12, bottom: 0, left: -8 }} barSize={12}>
          <CartesianGrid stroke="hsl(var(--border))" strokeDasharray="3 3" />
          <XAxis
            type="number"
            stroke="hsl(var(--muted-foreground))"
            tickLine={false}
            fontSize={10}
            tickFormatter={(v) => `${v}%`}
            domain={[0, 100]}
          />
          <YAxis
            type="category"
            dataKey="name"
            stroke="hsl(var(--muted-foreground))"
            tickLine={false}
            fontSize={10}
            width={level === "company" ? 140 : 100}
            onClick={(e) => {
              const row = sorted.find((r) => r.name === e?.payload?.name);
              if (row) handleYClick(row);
            }}
            style={{ cursor: onDrillDown ? "pointer" : "default" }}
          />
          <Tooltip
            content={({ active, payload }) => {
              if (!active || !payload?.length) return null;
              const row = payload[0]?.payload as VolumeProfileRow | undefined;
              if (!row) return null;
              return (
                <div className="rounded-lg border border-border bg-card p-3 text-xs shadow">
                  <div className="mb-1 font-medium">{row.name}</div>
                  <div className="text-muted-foreground">{row.sector} · {row.industry}</div>
                  <div className="mt-2 space-y-1">
                    <div className="flex items-center justify-between gap-4">
                      <span className="flex items-center gap-1">
                        <span className="inline-block h-2 w-2 rounded-full" style={{ backgroundColor: "#2563eb" }} />
                        Volume
                      </span>
                      <span className="tabular-nums">{row.volume.toLocaleString("en-IN")} ({row.volumePct}%)</span>
                    </div>
                    <div className="flex items-center justify-between gap-4">
                      <span className="flex items-center gap-1">
                        <span className="inline-block h-2 w-2 rounded-full" style={{ backgroundColor: "#f97316" }} />
                        AvgVol_1W
                      </span>
                      <span className="tabular-nums">{row.avgVol1W.toLocaleString("en-IN")} ({row.avgVol1WPct}%)</span>
                    </div>
                    <div className="flex items-center justify-between gap-4">
                      <span className="flex items-center gap-1">
                        <span className="inline-block h-2 w-2 rounded-full" style={{ backgroundColor: "#a855f7" }} />
                        AvgVol_1M
                      </span>
                      <span className="tabular-nums">{row.avgVol1M.toLocaleString("en-IN")} ({row.avgVol1MPct}%)</span>
                    </div>
                    <div className="flex items-center justify-between gap-4">
                      <span className="flex items-center gap-1">
                        <span className="inline-block h-2 w-2 rounded-full" style={{ backgroundColor: "#6366f1" }} />
                        AvgVol_1Y
                      </span>
                      <span className="tabular-nums">{row.avgVol1Y.toLocaleString("en-IN")} ({row.avgVol1YPct}%)</span>
                    </div>
                  </div>
                  {row.companyCount != null && (
                    <div className="mt-2 text-muted-foreground">Company Count: {row.companyCount}</div>
                  )}
                </div>
              );
            }}
          />
          <Legend wrapperStyle={{ fontSize: 12 }} />
          {SERIES.map((s, i) => (
            <Bar
              key={s.key}
              dataKey={s.key === "volume" ? "volumePct" : s.key === "avgVol1W" ? "avgVol1WPct" : s.key === "avgVol1M" ? "avgVol1MPct" : "avgVol1YPct"}
              name={s.name}
              fill={s.color}
              isAnimationActive={false}
              stackId="volume"
            />
          ))}
        </BarChart>
      </ResponsiveContainer>
    </ChartFrame>
  );
}
