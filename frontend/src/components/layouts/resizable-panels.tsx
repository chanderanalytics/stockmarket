"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

// ResizablePanels: a draggable two-pane horizontal split.
// `defaultLeft` is the initial left-pane width as a percentage (0-100).
export function ResizablePanels({
  left,
  right,
  defaultLeft = 50,
  min = 20,
  max = 80,
  className,
}: {
  left: React.ReactNode;
  right: React.ReactNode;
  defaultLeft?: number;
  min?: number;
  max?: number;
  className?: string;
}) {
  const [leftPct, setLeftPct] = React.useState(defaultLeft);
  const containerRef = React.useRef<HTMLDivElement>(null);
  const dragging = React.useRef(false);

  React.useEffect(() => {
    const onMove = (e: MouseEvent) => {
      if (!dragging.current || !containerRef.current) return;
      const rect = containerRef.current.getBoundingClientRect();
      const pct = ((e.clientX - rect.left) / rect.width) * 100;
      setLeftPct(Math.min(max, Math.max(min, pct)));
    };
    const onUp = () => {
      dragging.current = false;
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
  }, [min, max]);

  const startDrag = () => {
    dragging.current = true;
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  };

  return (
    <div ref={containerRef} className={cn("flex h-full w-full", className)}>
      <div style={{ width: `${leftPct}%` }} className="min-w-0 overflow-auto scrollbar-thin">
        {left}
      </div>
      <div
        role="separator"
        aria-orientation="vertical"
        onMouseDown={startDrag}
        className="w-1 cursor-col-resize bg-border transition-colors hover:bg-primary/60"
      />
      <div style={{ width: `${100 - leftPct}%` }} className="min-w-0 overflow-auto scrollbar-thin">
        {right}
      </div>
    </div>
  );
}
