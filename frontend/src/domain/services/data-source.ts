import { stocks, makeCandles, makeQuote } from "@/shared/mock/data";
import type { OHLC, ProbabilityWideRow } from "../types";
import type { BreadthMember } from "../breadth/types";
import type { SectorMember } from "../sectors/types";
import type { IndicatorContext } from "../indicators/types";
import { mean } from "../indicators/calculators/_utils";

// ---- Data source -----------------------------------------------------------
// In production these functions query the backend / database. Here they derive
// engine inputs from the mock dataset so the runtime is fully runnable and the
// domain models can be exercised end-to-end. No raw SQL column names leak out.

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

function toOHLC(candles: ReturnType<typeof makeCandles>): OHLC[] {
  return candles.map((c) => ({ time: c.time, open: c.open, high: c.high, low: c.low, close: c.close, volume: c.volume }));
}

function ma(closes: number[], period: number): number {
  if (closes.length === 0) return 0;
  const slice = closes.slice(-Math.min(period, closes.length));
  return mean(slice);
}

export function getCandles(symbol: string, points = 252): OHLC[] {
  return toOHLC(makeCandles(symbol, points));
}

export function getIndicatorContext(symbol: string, points = 252): IndicatorContext {
  const ohlc = getCandles(symbol, points);
  return {
    closes: ohlc.map((o) => o.close),
    highs: ohlc.map((o) => o.high),
    lows: ohlc.map((o) => o.low),
    volumes: ohlc.map((o) => o.volume),
    times: ohlc.map((o) => o.time),
  };
}

export function getBreadthMembers(): BreadthMember[] {
  return stocks.map((s) => {
    const ohlc = getCandles(s.symbol, 252);
    const closes = ohlc.map((o) => o.close);
    const high = Math.max(...ohlc.map((o) => o.high));
    const low = Math.min(...ohlc.map((o) => o.low));
    const close = closes[closes.length - 1];
    const prev = closes[closes.length - 2] ?? close;
    return {
      symbol: s.symbol,
      close,
      prevClose: prev,
      ma20: ma(closes, 20),
      ma50: ma(closes, 50),
      ma100: ma(closes, 100),
      ma200: ma(closes, 200),
      isNewHigh: close >= high * 0.98,
      isNewLow: close <= low * 1.02,
    };
  });
}

export function getSectorMembers(): SectorMember[] {
  return stocks.map((s) => {
    const rnd = seeded(hash(s.symbol));
    const q = makeQuote(s);
    return {
      symbol: s.symbol,
      sector: s.sector ?? "Other",
      return1D: q.changePct,
      return1W: +(q.changePct * 1.4 + (rnd() - 0.5) * 4).toFixed(2),
      return1M: +(q.changePct * 2.2 + (rnd() - 0.5) * 10).toFixed(2),
      return3M: +(q.changePct * 3 + (rnd() - 0.5) * 18).toFixed(2),
      returnYTD: +(q.changePct * 4 + (rnd() - 0.5) * 24).toFixed(2),
      relativeStrength: +(45 + rnd() * 55).toFixed(1),
      advancing: q.changePct >= 0,
      volume: q.volume,
    };
  });
}

export function getProbabilityRow(symbol: string): ProbabilityWideRow {
  const rnd = seeded(hash(symbol) + 7);
  const ohlc = getCandles(symbol, 60);
  const closes = ohlc.map((o) => o.close);
  const rets: number[] = [];
  for (let i = 1; i < closes.length; i++) rets.push((closes[i] - closes[i - 1]) / closes[i - 1]);
  const vol = Math.sqrt(mean(rets.map((r) => r * r))) * Math.sqrt(252) * 100;
  // Synthesize a smooth return-probability distribution peaking around +5%.
  const buckets: ProbabilityWideRow["returnBuckets"] = [];
  for (let from = 1; from < 100; from += 5) {
    const mid = (from + from + 5) / 2;
    const prob = Math.max(0, 14 * Math.exp(-((mid - 6) ** 2) / 120) + rnd() * 2);
    buckets.push({ from, to: from + 5, probability: +prob.toFixed(2) });
  }
  return {
    symbol,
    returnBuckets: buckets,
    volatility21d: +vol.toFixed(2),
    volatility63d: +(vol * 1.1).toFixed(2),
    pvol21d: +vol.toFixed(2),
    pvol252d: +(vol * 0.9).toFixed(2),
    volumeTrend: +(rnd() - 0.5).toFixed(2),
  };
}
