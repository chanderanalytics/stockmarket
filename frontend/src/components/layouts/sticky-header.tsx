import * as React from "react";
import { cn } from "@/lib/utils";

// StickyHeader: a sticky sub-header used inside a page (title + actions).
export function StickyHeader({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "sticky top-0 z-20 -mx-4 mb-4 border-b border-border bg-background/80 px-4 py-3 backdrop-blur md:-mx-6 md:px-6",
        className
      )}
    >
      {children}
    </div>
  );
}
