import { stocks, makeQuote, watchlist, portfolio } from "@/shared/mock/data";
import type {
  MarketPulse,
  MarketBreadth,
  MarketHealth,
  MarketInternals,
  MarketRegime,
  SectorSnapshot,
  TradingSignal,
  TradingOpportunity,
  WatchlistSummary,
  PortfolioSummary,
  PortfolioRisk,
  StockSnapshot,
  StockTrend,
  StockMomentum,
  ProbabilityAnalysis,
  DecisionSummary,
} from "../models";
import { BreadthEngine } from "../breadth/BreadthEngine";
import { SectorEngine } from "../sectors/SectorEngine";
import { ProbabilityEngine } from "../probability/ProbabilityEngine";
import { SignalEngine } from "../signals/SignalEngine";
import { MarketRegimeEngine } from "../regime/MarketRegimeEngine";
import { DecisionEngine } from "../decision/DecisionEngine";
import { IndicatorEngine } from "../indicators/IndicatorEngine";
import type { IndicatorName } from "../indicators/types";
import {
  getBreadthMembers,
  getSectorMembers,
  getProbabilityRow,
  getIndicatorContext,
} from "./data-source";

const SIGNAL_INDICATORS: { name: IndicatorName; params?: Record<string, number> }[] = [
  { name: "sma", params: { period: 50 } },
  { name: "ema", params: { period: 50 } },
  { name: "macd" },
  { name: "rsi" },
  { name: "adx" },
  { name: "bollinger_bands" },
  { name: "super_trend" },
  { name: "momentum", params: { period: 20 } },
  { name: "roc", params: { period: 10 } },
  { name: "volume" },
];

function avg(nums: number[]): number {
  return nums.length ? nums.reduce((a, b) => a + b, 0) / nums.length : 0;
}

export const MarketRuntime = {
  breadth(): MarketBreadth {
    return BreadthEngine.compute({ members: getBreadthMembers() });
  },

  sectors(): SectorSnapshot[] {
    const list = SectorEngine.compute({ members: getSectorMembers() });
    return list.sort((a, b) => a.rank - b.rank);
  },

  regime(): MarketRegime {
    const breadth = this.breadth();
    const sectorMembers = getSectorMembers();
    const indexReturn1M = avg(sectorMembers.map((m) => m.return1M));
    const momentum = breadth.marketParticipationScore - 50;
    const volatility = 14 + (50 - breadth.marketParticipationScore) * 0.2;
    return MarketRegimeEngine.compute({ breadth, indexReturn1M, volatility, momentum });
  },

  pulse(): MarketPulse {
    const breadth = this.breadth();
    const regime = this.regime();
    const sentiment: MarketPulse["overallSentiment"] =
      ["Strong Bull", "Bull", "Recovering"].includes(regime.regime)
        ? "bullish"
        : ["Bear", "Correction", "Capitulation", "Weak"].includes(regime.regime)
          ? "bearish"
          : "neutral";
    return {
      id: "market-pulse",
      timestamp: new Date().toISOString(),
      overallSentiment: sentiment,
      marketRegime: regime.regime,
      regimeConfidence: regime.confidence,
      keyDrivers: [
        `${Math.round(breadth.marketParticipationScore)}% market participation`,
        `Net advances ${breadth.netAdvances}`,
        `${breadth.percentageAbove200DMA.toFixed(0)}% of stocks above 200 DMA`,
      ],
      risks: [
        breadth.breadthTrend === "down" ? "Breadth deteriorating" : "Breadth constructive",
        regime.regime === "High Risk" || regime.regime === "Capitulation" ? "Elevated volatility regime" : "Volatility contained",
      ],
      outlook: regime.historicalComparison,
    };
  },

  health(): MarketHealth {
    const breadth = this.breadth();
    const volatility = 14 + (50 - breadth.marketParticipationScore) * 0.2;
    return {
      id: "market-health",
      timestamp: new Date().toISOString(),
      volatilityIndex: +volatility.toFixed(1),
      marketVolatility: volatility > 22 ? "high" : volatility > 16 ? "moderate" : "low",
      liquidityCondition: "normal",
      creditSpreads: 120,
      yieldCurveSlope: -0.2,
      dollarStrength: "neutral",
      commodityPrices: "stable",
    };
  },

  internals(): MarketInternals {
    const breadth = this.breadth();
    return {
      id: "market-internals",
      timestamp: new Date().toISOString(),
      putCallRatio: +(0.9 + (50 - breadth.marketParticipationScore) / 100).toFixed(2),
      volatilityTermStructure: "contango",
      marketDepth: Math.round(breadth.marketParticipationScore * 10),
      orderFlowImbalance: +((breadth.netAdvances / (stocks.length || 1)) * 0.1).toFixed(2),
      institutionalFlow: +((breadth.marketParticipationScore - 50) / 10).toFixed(1),
      retailSentiment: breadth.breadthTrend === "up" ? "bullish" : breadth.breadthTrend === "down" ? "bearish" : "neutral",
    };
  },

  signals(): TradingSignal[] {
    const sectors = this.sectors();
    const breadth = this.breadth();
    const bySector = new Map(sectors.map((s) => [s.sector, s]));
    return stocks.map((s) => {
      const ctx = getIndicatorContext(s.symbol, 252);
      const indicators = IndicatorEngine.batch(SIGNAL_INDICATORS, ctx);
      const probability = ProbabilityEngine.compute(getProbabilityRow(s.symbol));
      const q = makeQuote(s);
      return SignalEngine.compute({
        symbol: s.symbol,
        indicators,
        probability,
        sector: bySector.get(s.sector ?? ""),
        breadth,
        priceChangePercent: q.changePct,
        volatility: probability.volatilityExpectation,
      });
    });
  },

  opportunities(): TradingOpportunity[] {
    return this.signals()
      .filter((s) => s.rating === "strong_buy" || s.rating === "buy")
      .map((s) => {
        const q = makeQuote(stocks.find((x) => x.symbol === s.symbol)!);
        const entry = q.lastPrice;
        return {
          id: `opp-${s.symbol}`,
          timestamp: new Date().toISOString(),
          symbol: s.symbol,
          opportunityType: "breakout",
          entryPrice: +entry.toFixed(2),
          targetPrice: +(entry * 1.08).toFixed(2),
          stopLoss: +(entry * 0.95).toFixed(2),
          riskRewardRatio: +((entry * 1.08 - entry) / (entry - entry * 0.95)).toFixed(2),
          probabilityOfSuccess: s.confidenceScore,
          horizon: "medium",
          catalyst: s.reason,
        };
      });
  },

  decision(): DecisionSummary {
    const breadth = this.breadth();
    const regime = this.regime();
    const sectors = this.sectors();
    const signals = this.signals();
    return DecisionEngine.compute({ regime, breadth, sectors, signals, watchlistSymbols: watchlist.items.map((i) => i.symbol) });
  },

  watchlistSummary(): WatchlistSummary {
    const items = watchlist.items.map((it) => {
      const stock = stocks.find((s) => s.symbol === it.symbol)!;
      return { stock, q: makeQuote(stock) };
    });
    const changes = items.map((i) => i.q.changePct);
    const advancers = items.filter((i) => i.q.changePct >= 0).length;
    const sorted = [...items].sort((a, b) => b.q.changePct - a.q.changePct);
    return {
      id: watchlist.id,
      timestamp: new Date().toISOString(),
      watchlistId: watchlist.id,
      name: watchlist.name,
      itemCount: items.length,
      overallTrend: avg(changes) >= 0 ? "up" : "down",
      advancers,
      decliners: items.length - advancers,
      strongest: sorted[0].stock.symbol,
      weakest: sorted[sorted.length - 1].stock.symbol,
      avgChangePercent: +avg(changes).toFixed(2),
      alerts: [],
    };
  },

  portfolioSummary(): PortfolioSummary {
    const pf = portfolio;
    const total = pf.totalValue;
    const invested = pf.invested;
    const cash = pf.cash;
    const bySector: Record<string, number> = {};
    const sorted = Object.entries(bySector).sort((a, b) => b[1] - a[1]);
    return {
      id: pf.id,
      timestamp: new Date().toISOString(),
      portfolioId: pf.portfolioId,
      name: pf.name,
      totalValue: +total.toFixed(2),
      dayChange: +pf.dayChange.toFixed(2),
      dayChangePercent: +pf.dayChangePercent.toFixed(2),
      totalPnl: +pf.totalPnl.toFixed(2),
      totalPnlPercent: +pf.totalPnlPercent.toFixed(2),
      cash: +cash.toFixed(2),
      invested: +invested.toFixed(2),
      exposure: +pf.exposure.toFixed(1),
      holdingsCount: pf.holdingsCount,
      beta: pf.beta,
      sharpeRatio: pf.sharpeRatio,
      maxDrawdown: pf.maxDrawdown,
      diversificationScore: pf.diversificationScore,
      topSectors: pf.topSectors,
      worstSectors: pf.worstSectors,
    };
  },

  portfolioRisk(): PortfolioRisk {
    const summary = this.portfolioSummary();
    return {
      id: summary.portfolioId,
      timestamp: new Date().toISOString(),
      portfolioId: summary.portfolioId,
      overallRisk: summary.exposure > 80 ? "high" : summary.exposure > 60 ? "medium" : "low",
      riskScore: Math.round(summary.exposure * 0.8),
      volatility: 16.5,
      valueAtRisk: +(summary.totalValue * 0.02).toFixed(2),
      concentrationRisk: 35,
      sectorExposure: { Technology: 30, Financials: 25, Energy: 15 },
      correlationRisk: 40,
      liquidityRisk: 20,
      stressScenario: {
        marketDrop10: +(summary.totalValue * -0.1).toFixed(0),
        marketDrop20: +(summary.totalValue * -0.2).toFixed(0),
        rateUp100bps: +(summary.totalValue * -0.03).toFixed(0),
      },
      hedgeRecommendation: "Add index hedges if exposure exceeds 80%.",
    };
  },

  stockSnapshot(symbol: string): {
    snapshot: StockSnapshot;
    trend: StockTrend;
    momentum: StockMomentum;
    probability: ProbabilityAnalysis;
    signal: TradingSignal;
  } {
    const stock = stocks.find((s) => s.symbol === symbol) ?? stocks[0];
    const q = makeQuote(stock);
    const ohlc = getIndicatorContext(symbol, 252);
    const closes = ohlc.closes;
    const ma = (p: number) => (closes.length ? avg(closes.slice(-Math.min(p, closes.length))) : 0);
    const ma20 = ma(20);
    const ma50 = ma(50);
    const ma100 = ma(100);
    const ma200 = ma(200);
    const indicators = IndicatorEngine.batch(SIGNAL_INDICATORS, ohlc);
    const probability = ProbabilityEngine.compute(getProbabilityRow(symbol));
    const sectors = this.sectors();
    const signal = SignalEngine.compute({
      symbol,
      indicators,
      probability,
      sector: sectors.find((s) => s.sector === stock.sector),
      breadth: this.breadth(),
      priceChangePercent: q.changePct,
      volatility: probability.volatilityExpectation,
    });

    const snapshot: StockSnapshot = {
      id: `stock-${symbol}`,
      timestamp: new Date().toISOString(),
      symbol: stock.symbol,
      name: stock.name,
      exchange: stock.exchange,
      sector: stock.sector ?? "Other",
      industry: stock.industry ?? "",
      currentPrice: q.lastPrice,
      priceChange: q.change,
      priceChangePercent: q.changePct,
      marketCap: stock.marketCap ?? 0,
      volume: q.volume,
      avgVolume: Math.round(q.volume * 0.8),
      dayHigh: q.high,
      dayLow: q.low,
      week52High: Math.max(...ohlc.highs),
      week52Low: Math.min(...ohlc.lows),
    };

    const trend: StockTrend = {
      id: `trend-${symbol}`,
      timestamp: new Date().toISOString(),
      symbol,
      priceTrend: q.changePct >= 0 ? "up" : "down",
      trendStrength: Math.abs(q.changePct) > 2 ? "strong" : "moderate",
      movingAverages: {
        ma20: +ma20.toFixed(2),
        ma50: +ma50.toFixed(2),
        ma100: +ma100.toFixed(2),
        ma200: +ma200.toFixed(2),
        priceVsMA20: +(((q.lastPrice - ma20) / ma20) * 100).toFixed(2),
        priceVsMA50: +(((q.lastPrice - ma50) / ma50) * 100).toFixed(2),
        priceVsMA100: +(((q.lastPrice - ma100) / ma100) * 100).toFixed(2),
        priceVsMA200: +(((q.lastPrice - ma200) / ma200) * 100).toFixed(2),
      },
      momentum: indicators.find((i) => i.name === "rsi")?.value ?? 50,
      volatility: probability.volatilityExpectation,
      supportLevel: +(q.lastPrice * 0.95).toFixed(2),
      resistanceLevel: +(q.lastPrice * 1.05).toFixed(2),
    };

    const momentum: StockMomentum = {
      id: `momentum-${symbol}`,
      timestamp: new Date().toISOString(),
      symbol,
      momentumScore: +(indicators.find((i) => i.name === "momentum")?.strength.toFixed(1) ?? "50"),
      relativeStrength: +((sectors.find((s) => s.sector === stock.sector)?.relativeStrength) ?? 50).toFixed(1),
      earningsMomentum: 0,
      priceMomentum: q.changePct,
      volumeTrend: q.volume > q.volume * 0.8 ? "increasing" : "stable",
      institutionalInterest: signal.rating.includes("buy") ? "accumulation" : "neutral",
    };

    return { snapshot, trend, momentum, probability, signal };
  },
};
