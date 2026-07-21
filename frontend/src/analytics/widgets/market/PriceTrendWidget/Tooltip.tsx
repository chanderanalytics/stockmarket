import * as React from "react";
import type { TooltipPayload } from "./ReturnBarCell";

export interface TooltipProps {
  payload: TooltipPayload | null;
}

/**
 * Lightweight cursor-following tooltip. Renders nothing when there is no
 * payload. Avoids extra dependencies (no floating-ui / popper).
 */
export function Tooltip({ payload }: TooltipProps) {
  const ref = React.useRef<HTMLDivElement>(null);

  React.useLayoutEffect(() => {
    if (!ref.current || !payload) return;
    const pad = 14;
    const rect = ref.current.getBoundingClientRect();
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    let x = payload.x + pad;
    let y = payload.y + pad;
    if (x + rect.width > vw) x = payload.x - rect.width - pad;
    if (y + rect.height > vh) y = payload.y - rect.height - pad;
    ref.current.style.transform = `translate(${Math.max(4, x)}px, ${Math.max(4, y)}px)`;
  }, [payload]);

  if (!payload) return null;

  const positive = payload.value.startsWith("+");
  const valueColor = payload.value === "—" ? "#94a3b8" : positive ? "#16a34a" : "#dc2626";

  return (
    <div
      ref={ref}
      className="pointer-events-none fixed left-0 top-0 z-[10000] min-w-[180px] rounded-md border border-border bg-popover px-3 py-2 text-xs text-popover-foreground shadow-lg"
      style={{ willChange: "transform" }}
    >
      <div className="mb-1 font-semibold">{payload.company}</div>
      <div className="flex items-center justify-between gap-6">
        <span className="text-muted-foreground">{payload.period}</span>
        <span className="tabular-nums font-medium" style={{ color: valueColor }}>
          {payload.value}
        </span>
      </div>
      <div className="mt-1 flex items-center justify-between gap-6 text-muted-foreground">
        <span>Rank</span>
        <span className="tabular-nums">{payload.rank}</span>
      </div>
    </div>
  );
}
