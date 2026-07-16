"use client";

import * as React from "react";
import type { TooltipProps } from "recharts";

// Shared chart theme (Milestone 1, Task 7). All chart wrappers read these so
// colors, grids and tooltips stay consistent and theme-aware (dark/light).
export const chartPalette = [
  "hsl(var(--primary))",
  "hsl(var(--success))",
  "hsl(var(--warning))",
  "hsl(var(--destructive))",
  "hsl(199 89% 48%)",
  "hsl(280 65% 60%)",
  "hsl(48 96% 53%)",
  "hsl(340 75% 55%)",
];

export const chartColors = {
  grid: "hsl(var(--border))",
  axis: "hsl(var(--muted-foreground))",
  crosshair: "hsl(var(--muted-foreground))",
};

export function colorAt(index: number): string {
  return chartPalette[index % chartPalette.length];
}

// A single tooltip implementation shared by every chart.
export function ChartTooltip({ active, payload, label }: TooltipProps<number, string>) {
  if (!active || !payload || payload.length === 0) return null;
  return (
    <div className="rounded-md border border-border bg-popover px-3 py-2 text-xs shadow-md">
      {label !== undefined && label !== "" && (
        <p className="mb-1 font-medium text-popover-foreground">{String(label)}</p>
      )}
      <div className="space-y-1">
        {payload.map((entry, i) => (
          <div key={i} className="flex items-center gap-2">
            <span className="h-2 w-2 rounded-full" style={{ backgroundColor: entry.color }} />
            <span className="text-muted-foreground">{entry.name}</span>
            <span className="ml-auto font-medium tabular-nums text-popover-foreground">
              {typeof entry.value === "number" ? entry.value.toLocaleString("en-IN") : String(entry.value)}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
