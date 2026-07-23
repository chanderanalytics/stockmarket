"use client";
import * as React from "react";
import * as echarts from "echarts";
import type { EChartsOption } from "echarts";
import { useDebouncedResize } from "./useResize";
import type { IndexFeatureRow } from "./types";
import { RETURN_PERIODS, type ReturnSortKey, type SortKey, type SortDir } from "./types";

interface ReturnsHeatmapProps {
  rows: IndexFeatureRow[];
  loading?: boolean;
  periods?: ReturnSortKey[];
  sortKey?: SortKey;
  sortDir?: SortDir;
  onSortChange?: (key: SortKey) => void;
  onSortDirToggle?: () => void;
}

export function ReturnsHeatmap({
  rows,
  loading,
  periods = RETURN_PERIODS.map((p) => p.key),
  sortKey,
  sortDir = "desc",
  onSortChange,
  onSortDirToggle,
}: ReturnsHeatmapProps) {
  const containerRef = React.useRef<HTMLDivElement>(null);
  const chartRef = React.useRef<echarts.ECharts | null>(null);
  const width = useDebouncedResize(containerRef);

  const periodLabels = React.useMemo(
    () => periods.map((key) => RETURN_PERIODS.find((p) => p.key === key)?.label ?? key),
    [periods],
  );

  const sortedRows = React.useMemo(() => {
    if (!sortKey) return rows;
    const key = sortKey as ReturnSortKey;
    const data = [...rows];
    data.sort((a, b) => {
      const aVal = a[key];
      const bVal = b[key];
      if (aVal === null && bVal === null) return 0;
      if (aVal === null) return 1;
      if (bVal === null) return -1;
      const aNum = Number(aVal);
      const bNum = Number(bVal);
      return sortDir === "asc" ? aNum - bNum : bNum - aNum;
    });
    return data;
  }, [rows, sortKey, sortDir]);

  const yAxis = React.useMemo(() => sortedRows.map((r) => r.name), [sortedRows]);

  const periodMinMax = React.useMemo(() => {
    const map = new Map<ReturnSortKey, { min: number; max: number }>();
    periods.forEach((period) => {
      const values = rows
        .map((r) => r[period])
        .filter((v): v is number => v !== null && v !== undefined && Number.isFinite(v));
      if (!values.length) {
        map.set(period, { min: -5, max: 5 });
        return;
      }
      const min = Math.min(0, ...values);
      const max = Math.max(0, ...values);
      map.set(period, { min: Math.floor(min), max: Math.ceil(max) });
    });
    return map;
  }, [rows, periods]);

  function heatmapColor(value: number, min: number, max: number): string {
    const stops = ["#dc2626", "#fca5a5", "#fef2f2", "#fef9c3", "#86efac", "#166534"];
    if (max <= min) {
      const mid = Math.floor(stops.length / 2);
      return stops[mid];
    }
    const t = Math.max(0, Math.min(1, (value - min) / (max - min)));
    const scaled = t * (stops.length - 1);
    const idx = Math.min(Math.floor(scaled), stops.length - 2);
    const frac = scaled - idx;
    const c1 = hexToRgb(stops[idx]);
    const c2 = hexToRgb(stops[idx + 1]);
    if (!c1 || !c2) return stops[idx];
    const r = Math.round(c1.r + (c2.r - c1.r) * frac);
    const g = Math.round(c1.g + (c2.g - c1.g) * frac);
    const b = Math.round(c1.b + (c2.b - c1.b) * frac);
    return `rgb(${r},${g},${b})`;
  }

  function hexToRgb(hex: string): { r: number; g: number; b: number } | null {
    const m = hex.replace("#", "").match(/^([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i);
    if (!m) return null;
    return { r: parseInt(m[1], 16), g: parseInt(m[2], 16), b: parseInt(m[3], 16) };
  }

  const series = React.useMemo(() => {
    const data: { value: [number, number, number]; itemStyle: { color: string } }[] = [];
    sortedRows.forEach((row, rowIndex) => {
      periods.forEach((period, colIndex) => {
        const raw = row[period];
        const value = raw == null ? raw : Number(raw);
        if (value === null || value === undefined || !Number.isFinite(value)) return;
        const range = periodMinMax.get(period) ?? { min: -5, max: 5 };
        data.push({
          value: [colIndex, rowIndex, Number(value.toFixed(1))],
          itemStyle: { color: heatmapColor(value, range.min, range.max) },
        });
      });
    });
    return [
      {
        type: "heatmap" as const,
        data,
        label: {
          show: true,
          formatter: (params: { value?: number | number[] }) => {
            const raw = params.value;
            const v = Array.isArray(raw) ? raw[2] : raw;
            if (v === undefined || v === null) return "—";
            const num = Number(v);
            if (!Number.isFinite(num)) return "—";
            const sign = num > 0 ? "+" : "";
            return `${sign}${num.toFixed(1)}%`;
          },
          fontSize: 10,
        },
        itemStyle: {
          borderColor: "#fff",
          borderWidth: 1,
        },
      },
    ];
  }, [sortedRows, periods, periodMinMax]);

  React.useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    chartRef.current = echarts.init(el);
    return () => chartRef.current?.dispose();
  }, []);

  React.useEffect(() => {
    const chart = chartRef.current;
    if (!chart) return;

    const handleAxisClick = (event: any) => {
      if (!onSortChange) return;

      const { offsetX, offsetY } = event;
      const chartWidth = chart.getWidth();
      const chartHeight = chart.getHeight();

      const gridTop = 32;
      const gridBottom = chartHeight - 48;
      const gridLeft = 120;
      const gridRight = chartWidth - 70;

      const handleSort = (colIndex: number) => {
        if (colIndex < 0 || colIndex >= periods.length) return;
        const key = periods[colIndex];
        if (sortKey === key) {
          onSortDirToggle?.();
        } else {
          onSortChange(key);
        }
      };

      if (offsetY >= 0 && offsetY <= gridTop && offsetX >= gridLeft && offsetX <= gridRight) {
        const colIndex = Math.round(((offsetX - gridLeft) / (gridRight - gridLeft)) * (periods.length - 1));
        handleSort(colIndex);
      } else if (offsetY >= gridBottom && offsetY <= chartHeight && offsetX >= gridLeft && offsetX <= gridRight) {
        const colIndex = Math.round(((offsetX - gridLeft) / (gridRight - gridLeft)) * (periods.length - 1));
        handleSort(colIndex);
      }
    };

    const zr = chart.getZr();
    if (zr) {
      zr.on("click", handleAxisClick);
      return () => zr.off("click", handleAxisClick);
    }
    return undefined;
  }, [periods, sortKey, sortDir, onSortChange, onSortDirToggle]);

  React.useEffect(() => {
    const chart = chartRef.current;
    if (!chart) return;
    const option: EChartsOption = {
      tooltip: {
        trigger: "item",
        formatter: (params: any) => {
          const val = params?.value;
          if (!val || val.length < 3) return "";
          const [col, row, value] = val;
          const name = yAxis[row];
          const period = periodLabels[col] ?? "";
          const num = Number(value);
          if (!Number.isFinite(num)) return "";
          const sign = num > 0 ? "+" : "";
          return `${params.marker ?? ""} ${name}<br/>${period}: ${sign}${num.toFixed(1)}%`;
        },
      },
      grid: { top: 32, right: 70, bottom: 48, left: 120 },
      xAxis: [
        {
          type: "category",
          position: "top",
          data: periodLabels,
          splitArea: { show: true },
          axisLabel: {
            formatter: (value: string, index: number) => {
              const periodKey = periods[index];
              const active = sortKey === periodKey;
              const arrow = active ? (sortDir === "asc" ? "↑" : "↓") : "↕";
              return `${arrow} ${value} ${arrow}`;
            },
            fontSize: 10,
          },
        },
        {
          type: "category",
          position: "bottom",
          data: periodLabels,
          splitArea: { show: true },
          axisLabel: { fontSize: 10 },
        },
      ],
      yAxis: {
        type: "category",
        data: yAxis,
        splitArea: { show: true },
      },
      series: series as any,
    };
    chart.setOption(option, true);
  }, [series, yAxis, periodLabels]);

  React.useEffect(() => {
    const chart = chartRef.current;
    if (!chart || !width) return;
    chart.resize();
  }, [width]);

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
        Loading heatmap...
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <div ref={containerRef} className="h-[500px] w-full" />
    </div>
  );
}
