"use client";

import * as React from "react";
import {
  ScatterChart,
  Scatter,
  XAxis,
  YAxis,
  ZAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import { ChartFrame } from "./chart-frame";
import { ChartTooltip, colorAt, chartColors } from "./chart-theme";

// Each group is a named series of {x, y, z?} points.
export function ScatterChartCard({
  groups,
  height = 320,
  title,
  state = "ready",
  error,
  exportName,
  xLabel,
  yLabel,
}: {
  groups: { name: string; color?: string; points: { x: number; y: number; z?: number }[] }[];
  height?: number;
  title?: React.ReactNode;
  state?: "loading" | "error" | "empty" | "ready";
  error?: string;
  exportName?: string;
  xLabel?: string;
  yLabel?: string;
}) {
  return (
    <ChartFrame title={title} state={state} error={error} height={height} exportName={exportName ?? `${title || "scatter"}.png`}>
      <ResponsiveContainer width="100%" height="100%">
        <ScatterChart margin={{ top: 8, right: 12, bottom: 8, left: -8 }}>
          <CartesianGrid stroke={chartColors.grid} strokeDasharray="3 3" />
          <XAxis type="number" dataKey="x" name={xLabel} stroke={chartColors.axis} tickLine={false} fontSize={11} />
          <YAxis type="number" dataKey="y" name={yLabel} stroke={chartColors.axis} tickLine={false} fontSize={11} />
          <ZAxis type="number" dataKey="z" range={[40, 400]} />
          <Tooltip content={<ChartTooltip />} cursor={{ strokeDasharray: "3 3" }} />
          <Legend wrapperStyle={{ fontSize: 12 }} />
          {groups.map((g, i) => (
            <Scatter key={g.name} name={g.name} data={g.points} fill={g.color ?? colorAt(i)} isAnimationActive={false} />
          ))}
        </ScatterChart>
      </ResponsiveContainer>
    </ChartFrame>
  );
}
