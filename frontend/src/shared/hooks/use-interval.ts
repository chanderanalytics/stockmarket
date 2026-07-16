"use client";

import * as React from "react";

// Calls `callback` every `delay` ms. Pass `delay = null` to pause.
export function useInterval(callback: () => void, delay: number | null) {
  const saved = React.useRef(callback);
  React.useEffect(() => {
    saved.current = callback;
  }, [callback]);

  React.useEffect(() => {
    if (delay === null) return;
    const id = setInterval(() => saved.current(), delay);
    return () => clearInterval(id);
  }, [delay]);
}
