"use client";

import * as React from "react";
import { ResponsiveContainer, Treemap } from "recharts";
import { ChartFrame } from "./chart-frame";
import { colorAt } from "./chart-theme";

// Simple treemap: data = [{ name, size }]. Colors are derived by index.
export function TreemapCard({
  data,
  height = 320,
  title,
  state = "ready",
  error,
  exportName,
}: {
  data: { name: string; size: number }[];
  height?: number;
  title?: React.ReactNode;
  state?: "loading" | "error" | "empty" | "ready";
  error?: string;
  exportName?: string;
}) {
  const colored = React.useMemo(
    () =>
      data.map((d, i) => ({
        ...d,
        fill: colorAt(i),
      })),
    [data],
  );

  return (
    <ChartFrame title={title} state={state} error={error} height={height} exportName={exportName ?? `${title || "treemap"}.png`}>
      <ResponsiveContainer width="100%" height="100%">
        <Treemap
          data={colored}
          dataKey="size"
          stroke="hsl(var(--background))"
          content={<TreemapCell />}
          isAnimationActive={false}
        />
      </ResponsiveContainer>
    </ChartFrame>
  );
}

function TreemapCell(props: any) {
  const { x, y, width, height, name, fill } = props;
  if (width <= 0 || height <= 0) return null;
  return (
    <g>
      <rect x={x} y={y} width={width} height={height} fill={fill} fillOpacity={0.85} rx={2} />
      {width > 48 && height > 20 && (
        <text x={x + 6} y={y + 16} fill="hsl(var(--primary-foreground))" fontSize={11}>
          {name}
        </text>
      )}
    </g>
  );
}
