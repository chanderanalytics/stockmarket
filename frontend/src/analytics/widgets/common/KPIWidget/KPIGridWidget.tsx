"use client";

import * as React from "react";
import { KPIWidget } from "./KPIWidget";
import type { KPIGridWidgetProps } from "./KPIWidget.types";
import { cn } from "@/lib/utils";

const DEFAULT_COLUMNS = { base: 1, sm: 2, md: 3, lg: 4, xl: 4 } as const;

export function KPIGridWidget({
  items,
  columns,
  state,
  className,
  onRefresh,
  onNavigate,
  onContextMenu,
  adapter,
}: KPIGridWidgetProps) {
  const cols = { ...DEFAULT_COLUMNS, ...columns };
  const gridClass = cn(
    "grid gap-3",
    `grid-cols-${cols.base}`,
    `sm:grid-cols-${cols.sm}`,
    `md:grid-cols-${cols.md}`,
    `lg:grid-cols-${cols.lg}`,
    `xl:grid-cols-${cols.xl}`,
  );

  return (
    <div className={cn(gridClass, className)}>
      {items.map((config) => (
        <KPIWidget
          key={config.id}
          config={config}
          state={state}
          onRefresh={onRefresh}
          onNavigate={onNavigate}
          onContextMenu={onContextMenu}
          adapter={adapter}
        />
      ))}
    </div>
  );
}
