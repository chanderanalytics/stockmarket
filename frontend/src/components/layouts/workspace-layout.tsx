import * as React from "react";
import { cn } from "@/lib/utils";

// WorkspaceLayout: a master/detail two-pane layout (e.g. list + drilldown).
export function WorkspaceLayout({
  aside,
  children,
  asideClassName,
  className,
}: {
  aside?: React.ReactNode;
  children: React.ReactNode;
  asideClassName?: string;
  className?: string;
}) {
  return (
    <div className={cn("flex flex-col gap-4 lg:flex-row", className)}>
      {aside && <div className={cn("lg:w-80 lg:shrink-0", asideClassName)}>{aside}</div>}
      <div className="min-w-0 flex-1">{children}</div>
    </div>
  );
}
