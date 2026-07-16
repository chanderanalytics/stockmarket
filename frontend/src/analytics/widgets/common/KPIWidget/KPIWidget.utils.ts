import type {
  KPIValueFormat,
  KPIFormatOptions,
  KPIWidgetConfig,
  KPITrend,
  KPIStatus,
  KPISeverity,
  KPIColorScheme,
} from "./KPIWidget.types";
import type {
  MetricCardData,
  StatusCardData,
  ValueComparisonData,
  SummaryStripData,
} from "@/visualization/primitives/cards/types";

const DEFAULT_LOCALE = "en-IN";
const DEFAULT_CURRENCY = "INR";

export function formatValue(
  value: number | string | null,
  format: KPIValueFormat = "integer",
  options: KPIFormatOptions = {},
): string {
  if (value === null || value === undefined || value === "") return "—";

  if (format === "custom" && options.custom) {
    return options.custom(value);
  }

  let numeric = typeof value === "string" ? Number(value.replace(/,/g, "")) : value;
  if (typeof value === "string" && Number.isNaN(numeric)) return value;

  const locale = options.locale ?? DEFAULT_LOCALE;
  const decimals = options.decimals ?? 2;

  switch (format) {
    case "currency": {
      const currency = options.currency ?? DEFAULT_CURRENCY;
      try {
        return new Intl.NumberFormat(locale, {
          style: "currency",
          currency,
          maximumFractionDigits: decimals,
        }).format(numeric as number);
      } catch {
        return `${options.prefix ?? ""}${(numeric as number).toFixed(decimals)}${options.suffix ?? ""}`;
      }
    }
    case "percent":
      return `${options.prefix ?? ""}${(numeric as number).toFixed(decimals)}%${options.suffix ?? ""}`;
    case "integer":
      return new Intl.NumberFormat(locale, { maximumFractionDigits: 0 }).format(numeric as number);
    case "decimal":
      return new Intl.NumberFormat(locale, {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals,
      }).format(numeric as number);
    case "ratio":
      return `${options.prefix ?? ""}${(numeric as number).toFixed(decimals)}${options.suffix ?? "x"}`;
    case "largeNumber":
      return new Intl.NumberFormat(locale, {
        notation: "compact",
        maximumFractionDigits: 1,
      }).format(numeric as number);
    case "indianNumber":
      return new Intl.NumberFormat("en-IN", { maximumFractionDigits: decimals }).format(numeric as number);
    default:
      return String(value);
  }
}

export function formatChange(
  change: number | null | undefined,
  format: KPIValueFormat = "decimal",
  options: KPIFormatOptions = {},
): string {
  if (change === null || change === undefined) return "";
  const sign = change > 0 ? "+" : "";
  return `${sign}${formatValue(change, format, options)}`;
}

export function formatChangePercent(changePercent: number | null | undefined): string {
  if (changePercent === null || changePercent === undefined) return "";
  const sign = changePercent > 0 ? "+" : "";
  return `${sign}${formatValue(changePercent, "percent", { decimals: 1 })}`;
}

export function trendFromChange(change: number | null | undefined): KPITrend {
  if (change === null || change === undefined) return "none";
  if (change > 0) return "up";
  if (change < 0) return "down";
  return "flat";
}

export function statusFromSeverity(severity: KPISeverity | undefined): KPIStatus {
  if (severity === "critical" || severity === "high") return "error";
  if (severity === "medium") return "warning";
  return "ok";
}

export function statusTextClass(status?: KPIStatus): string {
  switch (status) {
    case "ok":
      return "text-success";
    case "warning":
      return "text-warning";
    case "error":
      return "text-destructive";
    case "info":
      return "text-primary";
    default:
      return "text-muted-foreground";
  }
}

export function trendTextClass(trend?: KPITrend): string {
  switch (trend) {
    case "up":
      return "text-success";
    case "down":
      return "text-destructive";
    case "flat":
      return "text-muted-foreground";
    default:
      return "text-muted-foreground";
  }
}

export function colorSchemeClass(scheme?: KPIColorScheme): string {
  switch (scheme) {
    case "primary":
      return "text-primary";
    case "success":
      return "text-success";
    case "warning":
      return "text-warning";
    case "destructive":
      return "text-destructive";
    case "muted":
      return "text-muted-foreground";
    default:
      return "";
  }
}

export function trendArrow(trend?: KPITrend): string {
  switch (trend) {
    case "up":
      return "▲";
    case "down":
      return "▼";
    case "flat":
      return "■";
    default:
      return "";
  }
}

function resolveValue(config: KPIWidgetConfig): string {
  const format = config.format ?? "integer";
  return config.formattedValue ?? formatValue(config.value, format, config.formatOptions);
}

export function toMetricCardData(config: KPIWidgetConfig): MetricCardData {
  let change: string | null = null;
  if (config.changePercent !== null && config.changePercent !== undefined) {
    change = formatChangePercent(config.changePercent);
  } else if (config.change !== null && config.change !== undefined) {
    change = formatChange(config.change, config.format ?? "decimal", config.formatOptions);
  }

  return {
    label: config.title,
    value: resolveValue(config),
    change,
    trend: config.trend ?? trendFromChange(config.change ?? config.changePercent ?? null),
    status: config.status,
    icon: config.icon,
    tooltip: config.tooltip,
  };
}

export function toStatusCardData(config: KPIWidgetConfig): StatusCardData {
  const status = config.status ?? statusFromSeverity(config.severity);
  return {
    status,
    label: config.title,
    detail: config.subtitle ?? config.tooltip,
    severity: config.severity,
  };
}

export function toValueComparisonData(config: KPIWidgetConfig): ValueComparisonData {
  const format = config.format ?? "integer";
  const current = resolveValue(config);
  const previous =
    config.previousValue !== null && config.previousValue !== undefined
      ? formatValue(config.previousValue, format, config.formatOptions)
      : "—";

  let change: string | null = null;
  let changePercent: string | null = null;
  if (config.changePercent !== null && config.changePercent !== undefined) {
    changePercent = formatChangePercent(config.changePercent);
  }
  if (config.change !== null && config.change !== undefined) {
    change = formatChange(config.change, format, config.formatOptions);
  }

  return {
    current,
    previous,
    change,
    changePercent,
    trend: config.trend ?? trendFromChange(config.change ?? config.changePercent ?? null),
  };
}

export function toSummaryStripData(items: KPIWidgetConfig[]): SummaryStripData {
  return {
    items: items.map((config) => ({
      label: config.title,
      value: resolveValue(config),
      status: config.status,
      trend: config.trend ?? trendFromChange(config.change ?? config.changePercent ?? null),
    })),
  };
}
