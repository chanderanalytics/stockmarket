import * as React from "react";

export interface TooltipProps {
  payload: { x: number; y: number; content: React.ReactNode } | null;
}

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

  return (
    <div
      ref={ref}
      className="pointer-events-none fixed left-0 top-0 z-[10000] min-w-[180px] rounded-md border border-border bg-popover px-3 py-2 text-xs text-popover-foreground shadow-lg"
      style={{ willChange: "transform" }}
    >
      {payload.content}
    </div>
  );
}
