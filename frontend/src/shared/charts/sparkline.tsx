"use client";

import * as React from "react";
import {
  LineChart,
  Line,
  ResponsiveContainer,
  YAxis,
} from "recharts";
import { colorAt } from "./chart-theme";

// Sparkline: a compact, axis-less trend line for inline use (tables, cards).
export function Sparkline({
  data,
  dataKey,
  color,
  height = 36,
  width = 120,
}: {
  data: Record<string, any>[];
  dataKey: string;
  color?: string;
  height?: number;
  width?: number;
}) {
  return (
    <div style={{ width, height }}>
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 2, right: 2, bottom: 2, left: 2 }}>
          <YAxis hide domain={["dataMin", "dataMax"]} />
          <Line
            type="monotone"
            dataKey={dataKey}
            stroke={color ?? colorAt(0)}
            strokeWidth={1.5}
            dot={false}
            isAnimationActive={false}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
