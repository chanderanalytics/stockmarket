/**
 * TradingView Lightweight Charts adapter stub.
 *
 * Use for price/volume financial charts where performance
 * and native TradingView interaction matter most.
 */

import React from "react";
import type { PrimitiveType, AdapterLibrary, VisualizationPrimitive, ChartData, HierarchyData, TableData } from "../../types";

export const TRADINGVIEW_PRIMITIVES: readonly PrimitiveType[] = [
  "line-chart",
  "area-chart",
  "candlestick-chart",
  "ohlc-chart",
  "sparkline",
];

export class TradingViewAdapter {
  readonly library: AdapterLibrary = "tradingview";
  readonly supportedPrimitives: readonly PrimitiveType[] = TRADINGVIEW_PRIMITIVES;

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
