import type {
  Candle,
  Holding,
  MarketIndex,
  Mover,
  NewsItem,
  Portfolio,
  Quote,
  Stock,
  Watchlist,
} from "@/shared/api/types";

// Deterministic pseudo-random so charts are stable between renders.
function seeded(seed: number) {
  let s = seed % 2147483647;
  if (s <= 0) s += 2147483646;
  return () => (s = (s * 16807) % 2147483647) / 2147483647;
}

function hash(str: string): number {
  let h = 0;
  for (let i = 0; i < str.length; i++) h = (h * 31 + str.charCodeAt(i)) | 0;
  return Math.abs(h);
}

export const stocks: Stock[] = [
  { symbol: "RELIANCE", name: "Reliance Industries", exchange: "NSE", sector: "Energy", industry: "Oil & Gas", marketCap: 18_200_000 },
  { symbol: "TCS", name: "Tata Consultancy Services", exchange: "NSE", sector: "Technology", industry: "IT Services", marketCap: 14_900_000 },
  { symbol: "INFY", name: "Infosys", exchange: "NSE", sector: "Technology", industry: "IT Services", marketCap: 7_400_000 },
  { symbol: "HDFCBANK", name: "HDFC Bank", exchange: "NSE", sector: "Financials", industry: "Banks", marketCap: 12_100_000 },
  { symbol: "ICICIBANK", name: "ICICI Bank", exchange: "NSE", sector: "Financials", industry: "Banks", marketCap: 8_300_000 },
  { symbol: "TATAMOTORS", name: "Tata Motors", exchange: "NSE", sector: "Automotive", industry: "Cars", marketCap: 3_200_000 },
  { symbol: "SUNPHARMA", name: "Sun Pharmaceutical", exchange: "NSE", sector: "Healthcare", industry: "Pharma", marketCap: 3_600_000 },
  { symbol: "BHARTIARTL", name: "Bharti Airtel", exchange: "NSE", sector: "Telecom", industry: "Telecom", marketCap: 9_100_000 },
  { symbol: "ITC", name: "ITC", exchange: "NSE", sector: "Consumer", industry: "FMCG", marketCap: 5_800_000 },
  { symbol: "WIPRO", name: "Wipro", exchange: "NSE", sector: "Technology", industry: "IT Services", marketCap: 2_900_000 },
  { symbol: "AXISBANK", name: "Axis Bank", exchange: "NSE", sector: "Financials", industry: "Banks", marketCap: 3_500_000 },
  { symbol: "MARUTI", name: "Maruti Suzuki", exchange: "NSE", sector: "Automotive", industry: "Cars", marketCap: 3_900_000 },
];

export function makeQuote(s: Stock): Quote {
  const rnd = seeded(hash(s.symbol));
  const last = +((s.marketCap ?? 0) % 3000) / 10 + 100;
  const changePct = +((rnd() - 0.45) * 4).toFixed(2);
  const change = +((last * changePct) / 100).toFixed(2);
  return {
    symbol: s.symbol,
    lastPrice: +last.toFixed(2),
    change,
    changePct,
    open: +(last - change).toFixed(2),
    high: +(last + rnd() * 20).toFixed(2),
    low: +(last - rnd() * 20).toFixed(2),
    close: +last.toFixed(2),
    volume: Math.round(rnd() * 5_000_000 + 200_000),
    updatedAt: new Date().toISOString(),
  };
}

export function makeCandles(symbol: string, points = 60): Candle[] {
  const rnd = seeded(hash(symbol));
  let price = 100 + (hash(symbol) % 200);
  const out: Candle[] = [];
  const now = Date.now();
  for (let i = points - 1; i >= 0; i--) {
    const open = price;
    const drift = (rnd() - 0.48) * 6;
    price = Math.max(10, price + drift);
    const high = Math.max(open, price) + rnd() * 3;
    const low = Math.min(open, price) - rnd() * 3;
    out.push({
      time: new Date(now - i * 86_400_000).toISOString().slice(0, 10),
      open: +open.toFixed(2),
      high: +high.toFixed(2),
      low: +low.toFixed(2),
      close: +price.toFixed(2),
      volume: Math.round(rnd() * 1_000_000 + 50_000),
    });
  }
  return out;
}

export const indices: MarketIndex[] = [
  { name: "NIFTY 50", value: 22458.32, change: 142.1, changePct: 0.64 },
  { name: "SENSEX", value: 73890.4, change: 410.5, changePct: 0.56 },
  { name: "BANK NIFTY", value: 48120.7, change: -98.3, changePct: -0.2 },
  { name: "NIFTY IT", value: 38740.2, change: 312.0, changePct: 0.81 },
  { name: "NIFTY PHARMA", value: 19210.5, change: 55.2, changePct: 0.29 },
];

export const gainers: Mover[] = stocks
  .map((s) => ({ symbol: s.symbol, name: s.name, lastPrice: makeQuote(s).lastPrice, changePct: makeQuote(s).changePct }))
  .sort((a, b) => b.changePct - a.changePct)
  .slice(0, 6);

export const losers: Mover[] = [...gainers].reverse().slice(0, 6).map((m) => ({ ...m, changePct: -Math.abs(m.changePct) }));

export const watchlist: Watchlist = {
  id: "wl1",
  watchlistId: "wl1",
  name: "My Watchlist",
  itemCount: 8,
  overallTrend: "up",
  advancers: 5,
  decliners: 3,
  strongest: "RELIANCE",
  weakest: "WIPRO",
  avgChangePercent: 1.2,
  alerts: [],
  items: stocks.slice(0, 8).map((s) => ({ symbol: s.symbol, addedAt: new Date().toISOString() })),
};

export const portfolio: Portfolio = (() => {
  const holdings: Holding[] = stocks.slice(0, 6).map((s) => {
    const q = makeQuote(s);
    const avg = +(q.lastPrice * (0.8 + Math.random() * 0.3)).toFixed(2);
    const pnl = +((q.lastPrice - avg) * 10).toFixed(2);
    const pnlPct = +((pnl / (avg * 10)) * 100).toFixed(2);
    return { symbol: s.symbol, quantity: 10, avgPrice: avg, lastPrice: q.lastPrice, pnl, pnlPct };
  });
  const totalValue = holdings.reduce((a, h) => a + h.lastPrice * h.quantity, 0);
  const totalPnl = holdings.reduce((a, h) => a + h.pnl, 0);
  const totalPnlPercent = +((totalPnl / (totalValue - totalPnl)) * 100).toFixed(2);
  return {
    id: "pf1",
    portfolioId: "pf1",
    name: "Growth Portfolio",
    totalValue: +totalValue.toFixed(2),
    dayChange: +totalPnl.toFixed(2),
    dayChangePercent: totalPnlPercent,
    totalPnl: +totalPnl.toFixed(2),
    totalPnlPercent,
    cash: 0,
    invested: +totalValue.toFixed(2),
    exposure: 100,
    holdingsCount: holdings.length,
    beta: 1.05,
    sharpeRatio: 1.4,
    maxDrawdown: -8.2,
    diversificationScore: 72,
    topSectors: ["Energy", "Technology"],
    worstSectors: ["Financials"],
  };
})();

export const news: NewsItem[] = [
  { id: "n1", title: "Reliance announces expansion into green energy", summary: "The conglomerate outlined a $10B plan...", source: "MarketWire", url: "#", publishedAt: new Date(Date.now() - 3600_000).toISOString(), symbols: ["RELIANCE"] },
  { id: "n2", title: "IT stocks rally on strong earnings", summary: "TCS and Infosys beat estimates...", source: "FinTimes", url: "#", publishedAt: new Date(Date.now() - 7200_000).toISOString(), symbols: ["TCS", "INFY"] },
  { id: "n3", title: "RBI keeps rates unchanged", summary: "Policy stance remains accommodative...", source: "EconDaily", url: "#", publishedAt: new Date(Date.now() - 10800_000).toISOString(), symbols: ["HDFCBANK", "ICICIBANK"] },
  { id: "n4", title: "Auto sales hit record high", summary: "Tata Motors reports 18% YoY growth...", source: "AutoBuzz", url: "#", publishedAt: new Date(Date.now() - 14400_000).toISOString(), symbols: ["TATAMOTORS"] },
];

export const sectors = ["Energy", "Technology", "Financials", "Automotive", "Healthcare", "Telecom", "Consumer"];

export function sectorHeatmap(): { rows: string[]; cols: string[]; values: number[][] } {
  const cols = ["Mon", "Tue", "Wed", "Thu", "Fri"];
  const values = sectors.map((sec) => cols.map(() => +(Math.random() * 4 - 1.5).toFixed(2)));
  return { rows: sectors, cols, values };
}
