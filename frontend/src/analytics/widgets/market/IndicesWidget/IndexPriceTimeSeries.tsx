"use client";
import * as React from "react";
import * as echarts from "echarts";
import type { EChartsOption } from "echarts";
import { useDebouncedResize } from "./useResize";
import type { IndexPriceRow } from "./types";

interface IndexPriceTimeSeriesProps {
  series: Array<{ name: string; data: IndexPriceRow[] }>;
  loading?: boolean;
  onExport?: () => void;
}

export function IndexPriceTimeSeries({ series, loading, onExport }: IndexPriceTimeSeriesProps) {
  const containerRef = React.useRef<HTMLDivElement>(null);
  const chartRef = React.useRef<echarts.ECharts | null>(null);
  const width = useDebouncedResize(containerRef);

  const handleExport = React.useCallback(() => {
    const chart = chartRef.current;
    if (!chart) return;
    const url = chart.getDataURL({ type: "png", pixelRatio: 2, backgroundColor: "#ffffff" });
    const a = document.createElement("a");
    a.href = url;
    a.download = "price-history.png";
    a.click();
  }, []);

  const dates = React.useMemo(
    () => series[0]?.data.map((d) => d.date).filter((d): d is string => d !== null) ?? [],
    [series],
  );

  React.useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    chartRef.current = echarts.init(el);
    return () => chartRef.current?.dispose();
  }, []);

  React.useEffect(() => {
    const chart = chartRef.current;
    if (!chart) return;
    const option: EChartsOption = {
      tooltip: {
        trigger: "axis",
        axisPointer: { type: "cross" },
      },
      legend: { data: series.map((s) => s.name), top: 0 },
      grid: [
        { left: 60, right: 20, top: 40, height: "60%" },
        { left: 60, right: 20, top: "75%", height: "20%" },
      ],
      xAxis: [
        { type: "category", gridIndex: 0, data: dates },
        { type: "category", gridIndex: 1, data: dates },
      ],
      yAxis: [
        { type: "value", gridIndex: 0, scale: true, name: "Price" },
        { type: "value", gridIndex: 1, scale: true, name: "Volume" },
      ],
      series: series.flatMap((s, idx) => [
        {
          name: `${s.name} Close`,
          type: "line",
          xAxisIndex: 0,
          yAxisIndex: 0,
          data: s.data.map((d) => d.close),
          smooth: true,
          lineStyle: { width: 2 },
        },
        {
          name: `${s.name} Volume`,
          type: "bar",
          xAxisIndex: 1,
          yAxisIndex: 1,
          data: s.data.map((d) => d.volume),
          itemStyle: { opacity: 0.4 },
        },
      ]),
    };
    chart.setOption(option, true);
  }, [series, dates]);

  React.useEffect(() => {
    const chart = chartRef.current;
    if (!chart || !width) return;
    chart.resize();
  }, [width]);

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
        Loading price history...
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      {onExport && (
        <div className="flex items-center justify-end">
          <button
            type="button"
            onClick={handleExport}
            className="rounded-md border border-border px-2 py-1 text-xs hover:bg-accent"
          >
            Export PNG
          </button>
        </div>
      )}
      <div ref={containerRef} className="h-[400px] w-full" />
    </div>
  );
}
