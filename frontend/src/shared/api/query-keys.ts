// Centralised react-query keys so services and components stay in sync.
export const queryKeys = {
  stocks: {
    all: ["stocks"] as const,
    list: (params?: Record<string, unknown>) => ["stocks", "list", params ?? {}] as const,
    search: (q: string) => ["stocks", "search", q] as const,
    detail: (symbol: string) => ["stocks", "detail", symbol] as const,
    snapshot: (symbol: string) => ["stocks", "snapshot", symbol] as const,
    candles: (symbol: string, range: string) => ["stocks", "candles", symbol, range] as const,
  },
  market: {
    indices: () => ["market", "indices"] as const,
    movers: () => ["market", "movers"] as const,
    status: () => ["market", "status"] as const,
    pulse: () => ["market", "pulse"] as const,
    breadth: () => ["market", "breadth"] as const,
    sectors: () => ["market", "sectors"] as const,
  },
  signals: {
    all: () => ["signals"] as const,
    opportunities: () => ["signals", "opportunities"] as const,
  },
  news: {
    all: (params?: Record<string, unknown>) => ["news", "list", params ?? {}] as const,
    bySymbol: (symbol: string) => ["news", "symbol", symbol] as const,
  },
  watchlist: {
    all: () => ["watchlist"] as const,
    detail: (id: string) => ["watchlist", "detail", id] as const,
  },
  screener: {
    saved: () => ["screener", "saved"] as const,
    run: (params: Record<string, unknown>) => ["screener", "run", params] as const,
  },
  portfolio: {
    summary: () => ["portfolio", "summary"] as const,
    holdings: (id: string) => ["portfolio", "holdings", id] as const,
    performance: (id: string, range: string) => ["portfolio", "performance", id, range] as const,
  },
  volumeProfile: {
    data: (params?: Record<string, unknown>) => ["volume-profile", "data", params ?? {}] as const,
    options: (level: string, parent?: string, companyName?: string) =>
      ["volume-profile", "options", level, parent ?? "", companyName ?? ""] as const,
    latestDate: () => ["volume-profile", "latest-date"] as const,
  },
  volumeProfileV2: {
    data: (params?: Record<string, unknown>) => ["volume-profile-v2", "data", params ?? {}] as const,
    options: (level: string, parent?: string, companyName?: string) =>
      ["volume-profile-v2", "options", level, parent ?? "", companyName ?? ""] as const,
    latestDate: () => ["volume-profile-v2", "latest-date"] as const,
  },
  priceTrend: {
    data: (params?: Record<string, unknown>) => ["price-trends", "data", params ?? {}] as const,
    latestDate: () => ["price-trends", "latest-date"] as const,
  },
  priceTrendV2: {
    data: (params?: Record<string, unknown>) => ["price-trends-v2", "data", params ?? {}] as const,
    latestDate: () => ["price-trends-v2", "latest-date"] as const,
  },
  marketBreadth: {
    summary: (params?: Record<string, unknown>) => ["market-breadth", "summary", params ?? {}] as const,
    distribution: (params?: Record<string, unknown>) => ["market-breadth", "distribution", params ?? {}] as const,
    sectors: (params?: Record<string, unknown>) => ["market-breadth", "sectors", params ?? {}] as const,
    industries: (params?: Record<string, unknown>) => ["market-breadth", "industries", params ?? {}] as const,
    companies: (params?: Record<string, unknown>) => ["market-breadth", "companies", params ?? {}] as const,
    subgroups: (params?: Record<string, unknown>) => ["market-breadth", "subgroups", params ?? {}] as const,
    history: (params?: Record<string, unknown>) => ["market-breadth", "history", params ?? {}] as const,
  },
  auth: {
    me: () => ["auth", "me"] as const,
  },
} as const;
