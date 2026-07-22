"use client";

import * as React from "react";
import * as echarts from "echarts";
import type { EChartsOption } from "echarts";
import { useDebouncedResize } from "./useResize";
import type { IndexFeatureRow } from "./types";
import { RETURN_PERIODS, type ReturnSortKey, type SortKey, type SortDir } from "./types";

interface PerformanceBarChartProps {
  rows: IndexFeatureRow[];
  periods: ReturnSortKey[];
  loading?: boolean;
  sortKey?: SortKey;
  sortDir?: SortDir;
  onSortChange?: (key: SortKey) => void;
  onSortDirToggle?: () => void;
  onBarClick?: (name: string) => void;
}

export function PerformanceBarChart({
  rows,
  periods,
  loading,
  sortKey,
  sortDir = "desc",
  onSortChange,
  onSortDirToggle,
  onBarClick,
}: PerformanceBarChartProps) {
  const containerRef = React.useRef<HTMLDivElement>(null);
  const nodeRefs = React.useRef<Map<string, HTMLDivElement>>(new Map());
  const chartRefs = React.useRef<Map<string, echarts.ECharts>>(new Map());
  const width = useDebouncedResize(containerRef);

  const count = Math.max(periods.length, 1);
  const cols = count === 1 ? 1 : count === 2 ? 2 : count === 3 ? 3 : 2;
  const rowCount = count <= 3 ? 1 : Math.ceil(count / 2);

  const sortPeriod = React.useMemo(() => {
    if (!sortKey) return periods[0];
    return (periods as ReturnSortKey[]).includes(sortKey as ReturnSortKey) ? (sortKey as ReturnSortKey) : periods[0];
  }, [periods, sortKey]);

  const sorted = React.useMemo(() => {
    return [...rows]
      .map((r) => ({ name: r.name, values: periods.map((p) => r[p] as number | null) }))
      .filter((r) => r.values.some((v) => v !== null && Number.isFinite(v)))
      .sort((a, b) => {
        const idx = periods.indexOf(sortPeriod);
        const aVal = (idx >= 0 ? a.values[idx] : a.values[0]) ?? 0;
        const bVal = (idx >= 0 ? b.values[idx] : b.values[0]) ?? 0;
        return sortDir === "asc" ? aVal - bVal : bVal - aVal;
      });
  }, [rows, periods, sortPeriod, sortDir]);

  React.useEffect(() => {
    const currentNodes = new Map<string, HTMLDivElement>();
    if (containerRef.current) {
      periods.forEach((period) => {
        const node = containerRef.current?.querySelector(`[data-chart="${period}"]`) as HTMLDivElement | null;
        if (node) currentNodes.set(period, node);
      });
    }
    nodeRefs.current = currentNodes;
  });

  React.useEffect(() => {
    const nodes = nodeRefs.current;
    if (!nodes.size) return;

    const seen = new Set<string>();
    periods.forEach((period, periodIndex) => {
      seen.add(period);
      const node = nodes.get(period);
      if (!node) return;

      const existing = chartRefs.current.get(period);
      if (existing) {
        existing.dispose();
      }
      const chart = echarts.init(node);
      chartRefs.current.set(period, chart);

      const label = RETURN_PERIODS.find((x) => x.key === period)?.label ?? period;
      const idx = periodIndex;
      const values = sorted.map((r) => {
        const value = r.values[idx];
        return value !== null && Number.isFinite(value) ? value : "-";
      });
      const colors = values.map((v) => (v === "-" ? "#94a3b8" : v >= 0 ? "#16a34a" : "#dc2626"));
      const option: EChartsOption = {
        tooltip: {
          trigger: "axis",
          axisPointer: { type: "shadow" },
          formatter: (params: any) => {
            const p = params?.[0] || params;
            const raw = Number(p.value);
            const sign = raw > 0 ? "+" : "";
            return `${p.name}<br/>${label}: ${sign}${raw.toFixed(1)}%`;
          },
        },
        grid: { top: 28, right: 80, bottom: 24, left: 140 },
        xAxis: {
          type: "value",
          axisLabel: { show: false },
          axisTick: { show: false },
          splitLine: { show: false },
        },
        yAxis: {
          type: "category",
          data: sorted.map((r) => r.name),
          axisLabel: { fontSize: 9 },
        },
        series: [
          {
            type: "bar",
            barMaxWidth: 72,
            barMinHeight: 2,
            data: values.map((v, i) => ({
              value: v === "-" ? null : v,
              itemStyle: { color: colors[i] },
            })),
            label: {
              show: true,
              fontSize: 9,
              distance: 8,
              position: "right",
              formatter: (params: any) => {
                const v = params?.value;
                if (v === undefined || v === null || v === "-") return "";
                return `${v > 0 ? "+" : ""}${v.toFixed(1)}%`;
              },
            },
          },
        ],
      };
      chart.setOption(option, true);
    });

    chartRefs.current.forEach((chart, key) => {
      if (!seen.has(key)) {
        chart.dispose();
        chartRefs.current.delete(key);
      }
    });
  }, [sorted, periods]);

  React.useEffect(() => {
    chartRefs.current.forEach((chart) => chart.resize());
  }, [width]);

  React.useEffect(() => {
    return () => {
      chartRefs.current.forEach((chart) => chart.dispose());
      chartRefs.current.clear();
    };
  }, []);

  const handleHeaderClick = (period: ReturnSortKey) => {
    if (!onSortChange) return;
    if (sortKey === period) {
      onSortDirToggle?.();
    } else {
      onSortChange(period);
    }
  };

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
        Loading chart...
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="text-xs text-muted-foreground">
        Showing {periods.length} chart{periods.length > 1 ? "s" : ""} · Ranked by {RETURN_PERIODS.find((p) => p.key === periods[0])?.label ?? periods[0]}
      </div>
      <div
        ref={containerRef}
        className="grid w-full gap-3 overflow-hidden"
        style={{
          gridTemplateColumns: `repeat(${cols}, 1fr)`,
          gridTemplateRows: `repeat(${rowCount}, 1fr)`,
          height: "70vh",
        }}
      >
        {periods.map((period) => {
          const label = RETURN_PERIODS.find((x) => x.key === period)?.label ?? period;
          const active = sortKey === period;
          const arrow = active ? (sortDir === "asc" ? "↑" : "↓") : "↕";
          return (
            <div key={period} className="flex h-full min-h-0 flex-col">
              <div
                className="cursor-pointer select-none px-2 py-1 text-center text-xs font-medium hover:text-foreground"
                onClick={() => handleHeaderClick(period)}
              >
                {arrow} {label} {arrow}
              </div>
              <div data-chart={period} className="flex-1 min-h-0 overflow-hidden" />
            </div>
          );
        })}
      </div>
    </div>
  );
}
