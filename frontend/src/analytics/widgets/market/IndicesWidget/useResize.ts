import * as React from "react";

export function useDebouncedResize(ref: React.RefObject<HTMLElement | null>): number | undefined {
  const [width, setWidth] = React.useState<number | undefined>(undefined);
  const frame = React.useRef<number | null>(null);

  React.useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const update = (w: number) => {
      if (frame.current) cancelAnimationFrame(frame.current);
      frame.current = requestAnimationFrame(() => setWidth(w));
    };
    const ro = new ResizeObserver((entries) => {
      for (const entry of entries) update(entry.contentRect.width);
    });
    ro.observe(el);
    update(el.clientWidth || el.getBoundingClientRect().width);
    return () => {
      ro.disconnect();
      if (frame.current) cancelAnimationFrame(frame.current);
    };
  }, [ref]);

  return width;
}
