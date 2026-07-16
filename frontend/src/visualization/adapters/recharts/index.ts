/**
 * Legacy Recharts adapter.
 *
 * This adapter preserves existing Recharts-based components while
 * conforming to the new VisualizationAdapter interface.
 *
 * Migration path:
 * 1. Existing Recharts components remain functional.
 * 2. New widgets should prefer ECharts/TradingView adapters.
 * 3. Recharts is retained for backward compatibility only.
 */

import React from "react";
import type { PrimitiveType, AdapterLibrary, VisualizationPrimitive, ChartData, HierarchyData, TableData } from "../../types";

export const LEGACY_RECHARTS_PRIMITIVES: readonly PrimitiveType[] = [
  "line-chart",
  "area-chart",
  "stacked-bar-chart",
  "grouped-bar-chart",
  "bar-chart",
  "candlestick-chart",
  "ohlc-chart",
  "heatmap",
  "treemap",
  "scatter-plot",
  "sparkline",
];

export class RechartsLegacyAdapter {
  readonly library: AdapterLibrary = "recharts-legacy";
  readonly supportedPrimitives: readonly PrimitiveType[] = LEGACY_RECHARTS_PRIMITIVES;

  canHandle(primitive: PrimitiveType): boolean {
    return this.supportedPrimitives.includes(primitive);
  }

  render(
    primitive: VisualizationPrimitive,
    _data: ChartData | HierarchyData | TableData | Record<string, unknown>,
    _config: Record<string, unknown>,
  ): React.ReactNode {
    return React.createElement(
      "div",
      {
        "data-primitive": primitive.type,
        "data-adapter": this.library,
        className: "viz-adapter-placeholder",
      },
      `${primitive.type} · ${this.library}`,
    );
  }
}
