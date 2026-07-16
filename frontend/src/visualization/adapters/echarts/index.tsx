/**
 * Apache ECharts adapter.
 *
 * Renders complex, high-density charts (volume profiling, heatmaps, financial
 * multi-series charts) using Apache ECharts. The adapter is the only place that
 * knows about the ECharts API — primitives and widgets stay library-agnostic.
 */

import * as React from "react";
import * as echarts from "echarts";
import type { EChartsOption } from "echarts";
import type {
  PrimitiveType,
  AdapterLibrary,
  VisualizationPrimitive,
  ChartData,
  HierarchyData,
  TableData,
} from "../../types";
import type { StackedBarChartData } from "../../primitives/charts/types";

export const ECHARTS_PRIMITIVES: readonly PrimitiveType[] = [
  "stacked-bar-chart",
  "grouped-bar-chart",
  "heatmap",
  "treemap",
  "scatter-plot",
  "distribution-chart",
  "timeline",
  "candlestick-chart",
  "ohlc-chart",
];

const instances = new Map<string, echarts.ECharts>();

export function getEchartsInstance(id: string): echarts.ECharts | undefined {
  return instances.get(id);
}

export function exportEChartPng(id: string, name = "chart.png"): void {
  const inst = instances.get(id);
  if (!inst) return;
  const url = inst.getDataURL({ type: "png", pixelRatio: 2, backgroundColor: "#ffffff" });
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
}

function formatNum(value: number): string {
  if (!Number.isFinite(value)) return "—";
  const abs = Math.abs(value);
  if (abs >= 1_00_00_000) return `${(value / 1_00_00_000).toFixed(2)}Cr`;
  if (abs >= 1_00_000) return `${(value / 1_00_000).toFixed(2)} Lacs`;
  return new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(value);
}

function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function isStackedBarData(data: unknown): data is StackedBarChartData {
  return typeof data === "object" && data !== null && "series" in data && "categories" in data;
}

function themeColors(): { axis: string; split: string } {
  if (typeof document === "undefined") return { axis: "#6b7280", split: "rgba(0,0,0,0.08)" };
  const isDark = document.documentElement.classList.contains("dark");
  return isDark
    ? { axis: "#9ca3af", split: "rgba(255,255,255,0.08)" }
    : { axis: "#6b7280", split: "rgba(0,0,0,0.08)" };
}

function buildStackedBarOption(
  data: StackedBarChartData,
  options: Record<string, unknown>,
): EChartsOption {
  const percent = options.percentStack === true;
  const onChartClick = typeof options.onChartClick === "function" ? (options.onChartClick as (name: string) => void) : undefined;
  const categories = data.categories ?? [];
  const meta = data.meta ?? [];
  const { axis, split } = themeColors();

  // For a 100% stacked bar we normalise each row's values to sum to 100.
  // (This echarts build does not support stackStrategy: "percentage".)
  const rowTotals: number[] = percent
    ? categories.map((_, i) =>
        data.series.reduce((acc, s) => acc + (Number((s.data as number[])[i]) || 0), 0),
      )
    : [];

  const series = data.series.map((s) => {
    const raw = (s.data as number[]) ?? [];
    const seriesData = percent
      ? raw.map((v, i) => (rowTotals[i] ? (Number(v) / rowTotals[i]) * 100 : 0))
      : raw;
    return {
      name: s.name ?? s.key,
      type: "bar" as const,
      stack: "total",
      data: seriesData,
      itemStyle: { color: s.color ?? "#5470c6", cursor: "pointer" },
      large: true,
      largeThreshold: 400,
      emphasis: { focus: "series" as const },
      label:
        percent
          ? {
              show: true,
              position: "inside" as const,
              formatter: (params: unknown) => {
                const v = Math.round(Number((params as { value?: number }).value ?? 0));
                return v <= 0 ? "" : `${v}%`;
              },
              color: "#ffffff",
              fontSize: 10,
            }
          : { show: false },
    };
  });

  return {
    animation: false,
    grid: { left: 200, right: 16, top: 8, bottom: 8, containLabel: false },
    legend: { show: false },
    tooltip: {
      trigger: "axis",
      axisPointer: { type: "shadow" },
      confine: true,
      formatter: (params: unknown) => {
        const arr = Array.isArray(params) ? params : [params];
        const first = arr[0] as { dataIndex?: number } | undefined;
        const idx = first?.dataIndex ?? 0;
        const row = meta[idx] as Record<string, unknown> | undefined;
        const header = row
          ? `<div style="font-weight:600;margin-bottom:4px">${escapeHtml(row.name)}</div>` +
            `<div style="color:#94a3b8;margin-bottom:6px">${escapeHtml(row.sector)} · ${escapeHtml(row.industry)}</div>`
          : "";
        // Series name -> row field, so the tooltip shows the ACTUAL volume
        // (formatted in Lacs/Cr) rather than the normalised percentage.
        const SERIES_KEY: Record<string, string> = {
          "Today's Volume": "volume",
          "Average Volume (1 Week)": "avgVol1W",
          "Average Volume (1 Month)": "avgVol1M",
          "Average Volume (1 Year)": "avgVol1Y",
        };
        const lines = arr
          .map((p) => {
            const item = p as { marker?: string; seriesName?: string };
            const key = SERIES_KEY[item.seriesName ?? ""];
            const actual = row && key ? Number(row[key]) : 0;
            return `<div style="display:flex;justify-content:space-between;gap:20px;line-height:1.6">` +
              `<span>${item.marker ?? ""} ${escapeHtml(item.seriesName)}</span>` +
              `<span style="font-variant-numeric:tabular-nums">${formatNum(actual)}</span></div>`;
          })
          .join("");
        const extra = row && row.companyCount != null
          ? `<div style="margin-top:6px;color:#94a3b8;font-size:11px">Companies: ${escapeHtml(row.companyCount)}</div>`
          : "";
        return `<div style="min-width:200px">${header}${lines}${extra}</div>`;
      },
    },
    xAxis: {
      type: "value",
      max: percent ? 100 : undefined,
      axisLabel: { color: axis, formatter: (v: number) => (percent ? `${v}%` : formatNum(v)) },
      splitLine: { lineStyle: { color: split } },
    },
    yAxis: {
      type: "category",
      data: categories,
      inverse: true,
      axisLabel: { color: axis, fontSize: 11, width: 190, overflow: "truncate" },
      axisLine: { lineStyle: { color: split } },
    },
    series,
  };
}

function EChartView({
  option,
  chartId,
  height,
  onChartClick,
}: {
  option: EChartsOption;
  chartId?: string;
  height: number;
  onChartClick?: (name: string) => void;
}) {
  const ref = React.useRef<HTMLDivElement>(null);
  const instRef = React.useRef<echarts.ECharts | null>(null);
  const onClickRef = React.useRef(onChartClick);
  onClickRef.current = onChartClick;

  React.useEffect(() => {
    if (!ref.current) return;
    const inst = echarts.init(ref.current);
    instRef.current = inst;
    if (chartId) instances.set(chartId, inst);
    inst.setOption(option);
    const cleanups: (() => void)[] = [];
    if (onClickRef.current) {
      inst.on("click", (params: any) => {
        if (typeof params?.name === "string") onClickRef.current!(params.name);
      });
      const zr = inst.getZr();
      const onZrClick = (e: any) => {
        const target = e.target;
        if (target && typeof target.anid === "string" && target.anid.startsWith("yAxisLabel_")) {
          const idx = Number(target.anid.replace("yAxisLabel_", ""));
          const cats = (option as any)?.yAxis?.data ?? [];
          const name = cats[idx];
          if (typeof name === "string") onClickRef.current!(name);
        }
      };
      zr.on("click", onZrClick);
      cleanups.push(() => zr.off("click", onZrClick));
    }
    const onResize = () => inst.resize();
    window.addEventListener("resize", onResize);
    return () => {
      window.removeEventListener("resize", onResize);
      cleanups.forEach((fn) => fn());
      if (chartId) instances.delete(chartId);
      inst.dispose();
      instRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  React.useEffect(() => {
    const cats = (option as any)?.yAxis?.data ?? [];
    if (Array.isArray(cats)) {
      // keep click handler in sync with categories if needed
    }
    instRef.current?.setOption(option, true);
  }, [option]);

  return <div ref={ref} style={{ width: "100%", height }} />;
}

function Placeholder({ primitive, library }: { primitive: PrimitiveType; library: AdapterLibrary }) {
  return (
    <div data-primitive={primitive} data-adapter={library} className="viz-adapter-placeholder">
      {primitive} · {library}
    </div>
  );
}

export class EChartsAdapter {
  readonly library: AdapterLibrary = "echarts";
  readonly supportedPrimitives: readonly PrimitiveType[] = ECHARTS_PRIMITIVES;

  canHandle(primitive: PrimitiveType): boolean {
    return this.supportedPrimitives.includes(primitive);
  }

  render(
    primitive: VisualizationPrimitive,
    data: ChartData | HierarchyData | TableData | Record<string, unknown>,
    config: Record<string, unknown>,
  ): React.ReactNode {
    if (primitive.type === "stacked-bar-chart" && isStackedBarData(data)) {
      const height = typeof config.height === "number" ? config.height : 520;
      const chartId = typeof config.chartId === "string" ? config.chartId : undefined;
      const onChartClick = (config.onChartClick as ((name: string) => void)) || undefined;
      return (
        <EChartView
          option={buildStackedBarOption(data, config)}
          chartId={chartId}
          height={height}
          onChartClick={onChartClick}
        />
      );
    }
    return <Placeholder primitive={primitive.type} library={this.library} />;
  }
}
