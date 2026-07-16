/**
 * TanStack Table adapter stub.
 *
 * Use for data-heavy tables with sorting, filtering,
 * pagination, and row virtualization.
 */

import React from "react";
import type { PrimitiveType, AdapterLibrary, VisualizationPrimitive, ChartData, HierarchyData, TableData } from "../../types";

export const TANSTACK_PRIMITIVES: readonly PrimitiveType[] = [
  "data-table",
  "ranked-table",
  "hierarchy-table",
  "tree-table",
  "matrix-table",
];

export class TanStackAdapter {
  readonly library: AdapterLibrary = "tanstack";
  readonly supportedPrimitives: readonly PrimitiveType[] = TANSTACK_PRIMITIVES;

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
