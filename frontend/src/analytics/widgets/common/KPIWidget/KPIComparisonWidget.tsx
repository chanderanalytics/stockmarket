"use client";

import * as React from "react";
import { ValueComparisonPrimitive } from "@/visualization/primitives";
import { ReactComponentsAdapter } from "@/visualization/adapters";
import type { VisualizationAdapter, VisualizationConfiguration } from "@/visualization/types";
import type { KPIComparisonWidgetProps } from "./KPIWidget.types";
import { toValueComparisonData } from "./KPIWidget.utils";
import { cn } from "@/lib/utils";

const defaultAdapter = new ReactComponentsAdapter();

export function KPIComparisonWidget({
  config,
  state,
  className,
  onRefresh,
  onNavigate,
  onContextMenu,
  adapter,
}: KPIComparisonWidgetProps) {
  const activeAdapter: VisualizationAdapter = adapter ?? defaultAdapter;
  const isLoading = Boolean(state?.loading);
  const isError = state?.error != null;
  const isEmpty = Boolean(state?.empty) || config.value === null;
  const isRefreshing = Boolean(state?.refreshing);
  const isDisabled = Boolean(state?.disabled);

  const interactionHandler = config.clickAction ?? onNavigate;

  const buildConfig = React.useCallback(
    (): VisualizationConfiguration => ({
      primitive: "value-comparison",
      adapter: activeAdapter.library,
      data: {},
      options: {
        title: config.title,
        subtitle: config.subtitle,
        height: 140,
        tooltip: config.tooltip,
        colorScheme: config.colorScheme,
      },
    }),
    [activeAdapter.library, config.title, config.subtitle, config.tooltip, config.colorScheme],
  );

  const wrapperProps: React.HTMLAttributes<HTMLDivElement> = {
    className: cn(
      "relative rounded-lg outline-none transition-colors",
      interactionHandler && !isDisabled ? "cursor-pointer hover:bg-accent/40 focus-visible:ring-2 focus-visible:ring-ring" : "",
      isDisabled && "opacity-60 pointer-events-none",
      isRefreshing && "animate-pulse",
      className,
    ),
    onContextMenu,
    onClick: interactionHandler,
    role: interactionHandler ? "button" : undefined,
    tabIndex: interactionHandler && !isDisabled ? 0 : undefined,
    "aria-disabled": isDisabled || undefined,
    "aria-busy": isRefreshing || undefined,
    "aria-label": config.ariaLabel ?? config.title,
    onKeyDown: interactionHandler
      ? (event: React.KeyboardEvent) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            interactionHandler();
          }
        }
      : undefined,
  };

  let content: React.ReactNode;
  if (isLoading) {
    content = (
      <ValueComparisonPrimitive loading error={null} data={null} config={buildConfig()} adapter={activeAdapter} />
    );
  } else if (isError) {
    content = (
      <ValueComparisonPrimitive
        loading={false}
        error={state?.error ?? "Error"}
        data={null}
        config={buildConfig()}
        adapter={activeAdapter}
      />
    );
  } else if (isEmpty) {
    content = <div className="p-4 text-sm text-muted-foreground">No data</div>;
  } else {
    content = (
      <ValueComparisonPrimitive
        loading={false}
        error={null}
        data={toValueComparisonData(config)}
        config={buildConfig()}
        adapter={activeAdapter}
      />
    );
  }

  return (
    <div {...wrapperProps}>
      {content}
      {onRefresh && !isDisabled && (
        <button
          type="button"
          aria-label="Refresh"
          onClick={(event) => {
            event.stopPropagation();
            onRefresh();
          }}
          className="absolute right-2 top-2 z-10 rounded-md p-1 text-muted-foreground transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <RefreshIcon spinning={isRefreshing} />
        </button>
      )}
    </div>
  );
}

function RefreshIcon({ spinning }: { spinning?: boolean }) {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={cn(spinning && "animate-spin")}
      aria-hidden="true"
    >
      <path d="M21 12a9 9 0 1 1-2.64-6.36" />
      <path d="M21 3v6h-6" />
    </svg>
  );
}
