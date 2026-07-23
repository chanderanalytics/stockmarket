export interface CompanyPerformance {
  company_id: number;
  company_name: string;
  total_trades: number;
  winning_trades: number;
  losing_trades: number;
  open_trades: number;
  win_rate: number;
  avg_pnl: number;
  avg_win: number;
  avg_loss: number;
  win_loss_ratio: number;
  profit_factor: number;
  max_drawdown: number;
  recovery_factor: number;
  sharpe_ratio: number;
  sortino_ratio: number;
  best_trade: number;
  worst_trade: number;
  avg_days_held: number;
}

export interface TradePerformance {
  company_name: string;
  company_id: number;
  entry_date: string;
  entry_price: number;
  entry_stop_loss: number | null;
  exit_date: string | null;
  exit_price: number | null;
  exit_stop_loss: number | null;
  pnl_pct: number;
  days_held: number;
  status: "WIN" | "LOSS" | "OPEN";
  day_return: number;
  annualized_return: number;
  AbsolutePL: number | null;
  AbsolutePL_cum: number | null;
  PercCumulativePL: number | null;
  high_water_mark: number | null;
  max_drawdown: number;
  price_range_pct: number;
  running_max: number;
  drawdown: number;
  entry_trade_summary?: string | null;
  entry_status?: string | null;
  exit_trade_summary?: string | null;
  exit_status?: string | null;
}

export interface PerformanceSummary {
  total_companies: number;
  total_trades: number;
  win_rate: number;
  avg_pnl: number;
  avg_sharpe: number;
  avg_max_drawdown: number;
  profit_factor: number;
}

export interface PerformanceFilters {
  dateRange: "1M" | "3M" | "6M" | "1Y" | "ALL";
  status: "ALL" | "WIN" | "LOSS" | "OPEN";
  companyId?: number;
  companyName?: string;
}
