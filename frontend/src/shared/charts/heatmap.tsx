"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

// Heatmap: a CSS-grid based color matrix (recharts has no native heatmap).
// `values[row][col]` drives fill intensity between min and max.
export function Heatmap({
  rows,
  cols,
  values,
  className,
  formatValue,
  cellLabel,
}: {
  rows: string[];
  cols: string[];
  values: number[][];
  className?: string;
  formatValue?: (v: number) => string;
  cellLabel?: (row: string, col: string, v: number) => string;
}) {
  const all = values.flat().filter((v) => Number.isFinite(v));
  const min = all.length ? Math.min(...all) : 0;
  const max = all.length ? Math.max(...all) : 1;
  const range = max - min || 1;

  const intensity = (v: number) => {
    const t = (v - min) / range;
    return `hsl(var(--primary) / ${0.12 + t * 0.78})`;
  };

  return (
    <div className={cn("overflow-auto", className)}>
      <div
        className="grid gap-px bg-border text-xs"
        style={{ gridTemplateColumns: `minmax(64px, auto) repeat(${cols.length}, minmax(36px, 1fr))` }}
      >
        <div className="bg-card" />
        {cols.map((c) => (
          <div key={c} className="bg-card px-1 py-1 text-center font-medium text-muted-foreground">
            {c}
          </div>
        ))}
        {rows.map((r, ri) => (
          <React.Fragment key={r}>
            <div className="bg-card px-2 py-1 font-medium text-muted-foreground">{r}</div>
            {cols.map((c, ci) => {
              const v = values[ri]?.[ci];
              if (v === undefined || !Number.isFinite(v)) {
                return <div key={c} className="bg-card" />;
              }
              return (
                <div
                  key={c}
                  title={cellLabel ? cellLabel(r, c, v) : `${r} / ${c}: ${v}`}
                  className="flex h-8 items-center justify-center tabular-nums text-primary-foreground/90"
                  style={{ backgroundColor: intensity(v) }}
                >
                  {formatValue ? formatValue(v) : null}
                </div>
              );
            })}
          </React.Fragment>
        ))}
      </div>
    </div>
  );
}
