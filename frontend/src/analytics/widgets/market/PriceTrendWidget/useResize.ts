import * as React from "react";

/**
 * Observe an element's width with a ResizeObserver and return a debounced
 * pixel width. Used by the grid to recompute column distribution on resize
 * without thrashing layout. Returns undefined until first measured.
 */
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
