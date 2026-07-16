/**
 * @legacy BarChartCard
 *
 * Legacy Recharts-based bar chart component.
 *
 * Migration path:
 * - New widgets should use VisualizationPrimitive + EChartsAdapter
 * - This component is retained for backward compatibility only
 * - Do not add new features here
 *
 * See: docs/VISUALIZATION_ARCHITECTURE.md
 */

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
import { ChartFrame } from "./chart-frame";
import { ChartTooltip, colorAt, chartColors } from "./chart-theme";
import type { ChartSeries } from "./types";

export function BarChartCard({
  data,
  xKey,
  series,
  height = 320,
  title,
  state = "ready",
  error,
  exportName,
  layout = "vertical",
}: {
  data: Record<string, any>[];
  xKey: string;
  series: ChartSeries[];
  height?: number;
  title?: React.ReactNode;
  state?: "loading" | "error" | "empty" | "ready";
  error?: string;
  exportName?: string;
  layout?: "vertical" | "horizontal";
}) {
  return (
    <ChartFrame title={title} state={state} error={error} height={height} exportName={exportName ?? `${title || "bar"}.png`}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} layout={layout} margin={{ top: 8, right: 12, bottom: 0, left: -8 }}>
          <CartesianGrid stroke={chartColors.grid} strokeDasharray="3 3" />
          <XAxis
            type={layout === "vertical" ? "category" : "number"}
            dataKey={layout === "vertical" ? xKey : undefined}
            stroke={chartColors.axis}
            tickLine={false}
            fontSize={11}
          />
          <YAxis
            type={layout === "vertical" ? "number" : "category"}
            dataKey={layout === "vertical" ? undefined : xKey}
            stroke={chartColors.axis}
            tickLine={false}
            fontSize={11}
            width={layout === "horizontal" ? 80 : 40}
          />
          <Tooltip content={<ChartTooltip />} cursor={{ fill: "hsl(var(--muted))", opacity: 0.4 }} />
          <Legend wrapperStyle={{ fontSize: 12 }} />
          {series.map((s, i) => (
            <Bar key={s.key} dataKey={s.key} name={s.name ?? s.key} fill={s.color ?? colorAt(i)} isAnimationActive={false} />
          ))}
        </BarChart>
      </ResponsiveContainer>
    </ChartFrame>
  );
}
