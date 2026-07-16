"use client";

import * as React from "react";
import { SummaryStripPrimitive } from "@/visualization/primitives";
import { ReactComponentsAdapter } from "@/visualization/adapters";
import type { VisualizationAdapter, VisualizationConfiguration } from "@/visualization/types";
import { KPIWidget } from "./KPIWidget";
import type { KPIStripWidgetProps } from "./KPIWidget.types";
import { toSummaryStripData } from "./KPIWidget.utils";
import { cn } from "@/lib/utils";

const defaultAdapter = new ReactComponentsAdapter();

export function KPIStripWidget({
  items,
  variant = "summary",
  state,
  className,
  onRefresh,
  onNavigate,
  onContextMenu,
  adapter,
}: KPIStripWidgetProps) {
  const activeAdapter: VisualizationAdapter = adapter ?? defaultAdapter;
  const isLoading = Boolean(state?.loading);
  const isError = state?.error != null;
  const isEmpty = Boolean(state?.empty) || items.length === 0;

  if (variant === "cards") {
    return (
      <div className={cn("flex flex-wrap gap-3", className)}>
        {items.map((config) => (
          <div key={config.id} className="min-w-[200px] flex-1">
            <KPIWidget
              config={config}
              state={state}
              onRefresh={onRefresh}
              onNavigate={onNavigate}
              onContextMenu={onContextMenu}
              adapter={adapter}
            />
          </div>
        ))}
      </div>
    );
  }

  const buildConfig = React.useCallback(
    (): VisualizationConfiguration => ({
      primitive: "summary-strip",
      adapter: activeAdapter.library,
      data: {},
      options: { height: 72 },
    }),
    [activeAdapter.library],
  );

  let content: React.ReactNode;
  if (isLoading) {
    content = <SummaryStripPrimitive loading error={null} data={null} config={buildConfig()} adapter={activeAdapter} />;
  } else if (isError) {
    content = (
      <SummaryStripPrimitive
        loading={false}
        error={state?.error ?? "Error"}
        data={null}
        config={buildConfig()}
        adapter={activeAdapter}
      />
    );
  } else if (isEmpty) {
    content = <div className="py-2 text-sm text-muted-foreground">No data</div>;
  } else {
    content = (
      <SummaryStripPrimitive
        loading={false}
        error={null}
        data={toSummaryStripData(items)}
        config={buildConfig()}
        adapter={activeAdapter}
      />
    );
  }

  return (
    <div className={cn("rounded-lg border border-border bg-card px-4 py-2", className)}>{content}</div>
  );
}
