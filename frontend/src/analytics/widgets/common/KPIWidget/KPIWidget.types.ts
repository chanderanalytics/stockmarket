import type * as React from "react";
import type { VisualizationAdapter } from "@/visualization/types";

export type KPIValueFormat =
  | "currency"
  | "percent"
  | "integer"
  | "decimal"
  | "ratio"
  | "largeNumber"
  | "indianNumber"
  | "custom";

export type KPIStatus = "ok" | "warning" | "error" | "info" | "neutral";
export type KPISeverity = "low" | "medium" | "high" | "critical" | "none";
export type KPITrend = "up" | "down" | "flat" | "none";

export type KPIColorScheme =
  | "auto"
  | "primary"
  | "success"
  | "warning"
  | "destructive"
  | "muted";

export type KPIFormatOptions = {
  currency?: string;
  locale?: string;
  decimals?: number;
  notation?: "standard" | "compact";
  prefix?: string;
  suffix?: string;
  custom?: (value: number | string | null) => string;
};

export interface KPIWidgetConfig {
  id: string;
  title: string;
  subtitle?: string;
  icon?: React.ReactNode;
  value: number | string | null;
  formattedValue?: string;
  previousValue?: number | null;
  change?: number | null;
  changePercent?: number | null;
  trend?: KPITrend;
  status?: KPIStatus;
  severity?: KPISeverity;
  tooltip?: string;
  colorScheme?: KPIColorScheme;
  clickAction?: () => void;
  format?: KPIValueFormat;
  formatOptions?: KPIFormatOptions;
  ariaLabel?: string;
}

export interface KPIWidgetState {
  loading?: boolean;
  error?: string | null;
  empty?: boolean;
  refreshing?: boolean;
  disabled?: boolean;
}

export interface KPIWidgetBaseProps {
  state?: KPIWidgetState;
  className?: string;
  onRefresh?: () => void;
  onNavigate?: () => void;
  onContextMenu?: (event: React.MouseEvent) => void;
  adapter?: VisualizationAdapter;
}

export interface KPIWidgetProps extends KPIWidgetBaseProps {
  config: KPIWidgetConfig;
  display?: "metric" | "status";
}

export interface KPIComparisonWidgetProps extends KPIWidgetBaseProps {
  config: KPIWidgetConfig;
}

export interface KPIGridWidgetProps extends KPIWidgetBaseProps {
  items: KPIWidgetConfig[];
  columns?: { base?: number; sm?: number; md?: number; lg?: number; xl?: number };
}

export interface KPIStripWidgetProps extends KPIWidgetBaseProps {
  items: KPIWidgetConfig[];
  variant?: "summary" | "cards";
}
