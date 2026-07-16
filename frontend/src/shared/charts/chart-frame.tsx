"use client";

import * as React from "react";
import { cn } from "@/lib/utils";
import { exportChartAsPng } from "./export";
import { Button } from "@/components/ui/button";

type State = "loading" | "error" | "empty" | "ready";

// ChartFrame wraps any chart body and handles the shared loading / error /
// empty states, an optional title + export button, and a fixed-height
// container that the chart fills.
export const ChartFrame = React.forwardRef<HTMLDivElement, {
  title?: React.ReactNode;
  state?: State;
  error?: string;
  height?: number;
  className?: string;
  children: React.ReactNode;
  exportable?: boolean;
  exportName?: string;
}>(({ title, state = "ready", error, height = 320, className, children, exportable = true, exportName }, ref) => {
  const innerRef = React.useRef<HTMLDivElement>(null);
  React.useImperativeHandle(ref, () => innerRef.current as HTMLDivElement);

  return (
    <div className={cn("rounded-lg border border-border bg-card p-4", className)}>
      {(title || exportable) && (
        <div className="mb-3 flex items-center justify-between gap-2">
          <h3 className="text-sm font-medium text-card-foreground">{title}</h3>
          {exportable && state === "ready" && (
            <Button
              variant="ghost"
              size="sm"
              className="h-7 px-2 text-xs"
              onClick={() => exportChartAsPng(innerRef.current, exportName)}
            >
              Export
            </Button>
          )}
        </div>
      )}
      <div ref={innerRef} style={{ height }} className="w-full">
        {state === "loading" && (
          <div className="flex h-full w-full items-center justify-center text-sm text-muted-foreground">
            <span className="animate-pulse">Loading…</span>
          </div>
        )}
        {state === "error" && (
          <div className="flex h-full w-full items-center justify-center text-sm text-destructive">
            {error || "Failed to load chart"}
          </div>
        )}
        {state === "empty" && (
          <div className="flex h-full w-full items-center justify-center text-sm text-muted-foreground">
            No data available
          </div>
        )}
        {state === "ready" && children}
      </div>
    </div>
  );
});
ChartFrame.displayName = "ChartFrame";
