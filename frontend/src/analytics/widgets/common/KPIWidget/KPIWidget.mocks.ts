import type { KPIWidgetConfig } from "./KPIWidget.types";

export const marketStatusKPI: KPIWidgetConfig = {
  id: "market-status",
  title: "Market Status",
  subtitle: "NSE · Live",
  value: "Open",
  formattedValue: "Open",
  status: "ok",
  trend: "flat",
  tooltip: "Indian markets are currently open",
};

export const marketBreadthKPI: KPIWidgetConfig = {
  id: "market-breadth",
  title: "Breadth",
  subtitle: "Advances / Declines",
  value: 1.42,
  format: "decimal",
  formatOptions: { decimals: 2 },
  previousValue: 1.18,
  change: 0.24,
  changePercent: 20.3,
  trend: "up",
  status: "ok",
  tooltip: "Advance/Decline ratio across NSE 50",
};

export const opportunityCountKPI: KPIWidgetConfig = {
  id: "opportunity-count",
  title: "Opportunities",
  subtitle: "Open signals",
  value: 37,
  format: "integer",
  previousValue: 29,
  change: 8,
  changePercent: 27.6,
  trend: "up",
  status: "info",
  tooltip: "Number of active trading opportunities",
};

export const portfolioValueKPI: KPIWidgetConfig = {
  id: "portfolio-value",
  title: "Portfolio Value",
  subtitle: "Total holdings",
  value: 12845000,
  format: "currency",
  formatOptions: { currency: "INR", locale: "en-IN", decimals: 0 },
  previousValue: 12490000,
  change: 355000,
  changePercent: 2.84,
  trend: "up",
  status: "ok",
  tooltip: "Mark-to-market portfolio value",
};

export const riskScoreKPI: KPIWidgetConfig = {
  id: "risk-score",
  title: "Risk Score",
  subtitle: "Portfolio risk",
  value: 62,
  format: "integer",
  previousValue: 55,
  change: 7,
  changePercent: 12.7,
  trend: "up",
  severity: "high",
  status: "warning",
  tooltip: "Composite portfolio risk score (0-100)",
};

export const watchlistKPI: KPIWidgetConfig = {
  id: "watchlist-count",
  title: "Watchlist",
  subtitle: "Tracked symbols",
  value: 148,
  format: "integer",
  previousValue: 148,
  change: 0,
  changePercent: 0,
  trend: "flat",
  status: "neutral",
  tooltip: "Symbols on your watchlists",
};

export const signalCountKPI: KPIWidgetConfig = {
  id: "signal-count",
  title: "Signals",
  subtitle: "Last 24h",
  value: 12,
  format: "integer",
  previousValue: 19,
  change: -7,
  changePercent: -36.8,
  trend: "down",
  status: "warning",
  tooltip: "New signals generated in the last 24 hours",
};

export const mockKPIs: KPIWidgetConfig[] = [
  marketStatusKPI,
  marketBreadthKPI,
  opportunityCountKPI,
  portfolioValueKPI,
  riskScoreKPI,
  watchlistKPI,
  signalCountKPI,
];
