/**
 * @legacy AreaChartCard
 *
 * Legacy Recharts-based area chart component.
 * See: docs/VISUALIZATION_ARCHITECTURE.md
 */

import * as React from "react";
import {
  AreaChart,
  Area,
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

export function AreaChartCard({
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
    <ChartFrame title={title} state={state} error={error} height={height} exportName={exportName ?? `${title || "area"}.png`}>
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 8, right: 12, bottom: 0, left: -8 }}>
          <defs>
            {series.map((s, i) => (
              <linearGradient key={s.key} id={`fill-${s.key}-${i}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={s.color ?? colorAt(i)} stopOpacity={0.4} />
                <stop offset="95%" stopColor={s.color ?? colorAt(i)} stopOpacity={0.02} />
              </linearGradient>
            ))}
          </defs>
          <CartesianGrid stroke={chartColors.grid} strokeDasharray="3 3" />
          <XAxis dataKey={xKey} stroke={chartColors.axis} tickLine={false} fontSize={11} />
          <YAxis stroke={chartColors.axis} tickLine={false} fontSize={11} />
          <Tooltip content={<ChartTooltip />} />
          <Legend wrapperStyle={{ fontSize: 12 }} />
          {series.map((s, i) => (
            <Area
              key={s.key}
              type="monotone"
              dataKey={s.key}
              name={s.name ?? s.key}
              stroke={s.color ?? colorAt(i)}
              fill={`url(#fill-${s.key}-${i})`}
              strokeWidth={2}
              isAnimationActive={false}
            />
          ))}
        </AreaChart>
      </ResponsiveContainer>
    </ChartFrame>
  );
}
