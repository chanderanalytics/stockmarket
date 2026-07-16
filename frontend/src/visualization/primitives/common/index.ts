import type { PrimitiveType, VisualizationConfiguration, VisualizationAdapter } from "../../types";

export interface PrimitiveProps<T = unknown> {
  data: T;
  config: VisualizationConfiguration;
  loading: boolean;
  error: string | null;
  adapter: VisualizationAdapter;
}

export function buildPrimitiveRef(
  config: VisualizationConfiguration,
): {
  type: PrimitiveType;
  config: VisualizationConfiguration;
  render: () => null;
  update: () => void;
  destroy: () => void;
} {
  return {
    type: config.primitive,
    config,
    render: () => null,
    update: () => {},
    destroy: () => {},
  };
}
