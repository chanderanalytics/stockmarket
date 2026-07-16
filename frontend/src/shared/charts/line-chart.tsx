/**
 * @legacy LineChartCard
 *
 * Legacy Recharts-based line chart component.
 * See: docs/VISUALIZATION_ARCHITECTURE.md
 */

import * as React from "react";
import {
  LineChart,
  Line,
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

export function LineChartCard({
  data,
  xKey,
  series,
  height = 320,
  title,
  state = "ready",
  error,
  exportName,
}: {
  data: Record<string, any>[];
  xKey: string;
  series: ChartSeries[];
  height?: number;
  title?: React.ReactNode;
  state?: "loading" | "error" | "empty" | "ready";
  error?: string;
  exportName?: string;
}) {
  return (
    <ChartFrame title={title} state={state} error={error} height={height} exportName={exportName ?? `${title || "line"}.png`}>
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 8, right: 12, bottom: 0, left: -8 }}>
          <CartesianGrid stroke={chartColors.grid} strokeDasharray="3 3" />
          <XAxis dataKey={xKey} stroke={chartColors.axis} tickLine={false} fontSize={11} />
          <YAxis stroke={chartColors.axis} tickLine={false} fontSize={11} />
          <Tooltip content={<ChartTooltip />} cursor={{ stroke: chartColors.crosshair, opacity: 0.3 }} />
          <Legend wrapperStyle={{ fontSize: 12 }} />
          {series.map((s, i) => (
            <Line
              key={s.key}
              type="monotone"
              dataKey={s.key}
              name={s.name ?? s.key}
              stroke={s.color ?? colorAt(i)}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 4 }}
              isAnimationActive={false}
            />
          ))}
        </LineChart>
      </ResponsiveContainer>
    </ChartFrame>
  );
}
