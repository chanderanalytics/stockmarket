/**
 * Common interfaces for visualization adapters and widgets.
 */

import type { PrimitiveType, AdapterLibrary, ChartData, HierarchyData, TableData, WidgetConfiguration, VisualizationConfiguration, VisualizationAdapter } from "../types";

export interface VisualizationAdapterFactory {
  create(library: AdapterLibrary): VisualizationAdapter;
}

export interface WidgetDefinition {
  readonly id: string;
  readonly config: WidgetConfiguration;
  readonly visualization: VisualizationConfiguration;
  mount(container: HTMLElement): void;
  unmount(): void;
  update(data: unknown): void;
}

export interface PrimitiveRenderer {
  render(
    primitive: PrimitiveType,
    data: ChartData | HierarchyData | TableData | Record<string, unknown>,
    config: Record<string, unknown>,
  ): React.ReactNode;
}
