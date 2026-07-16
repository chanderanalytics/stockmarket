import type { Narrative, NarrativeKind } from "./Narrative";
import { NarrativeBuilder } from "./NarrativeBuilder";
import type { KnowledgeContext } from "../knowledge/models/KnowledgeContext";
import type { SectorSnapshot } from "../models/sectors";
import type { StockSnapshot } from "../models/stocks";
import type { StockTrend } from "../models/stocks";
import type { StockMomentum } from "../models/stocks";
import type { TradingSignal } from "../models/signals";
import type { PortfolioSummary } from "../models/portfolio";
import type { InvestmentThesis } from "../thesis/InvestmentThesis";

// NarrativeEngine — converts structured knowledge into reusable narratives.
// Each narrative is composed deterministically from domain objects.
export class NarrativeEngine {
  static dailyMarket(ctx: KnowledgeContext): Narrative {
    const { pulse, breadth, regime, sectors } = ctx;
    const leaders = sectors.filter((s) => s.leadership).map((s) => s.sector);
    const weak = sectors.filter((s) => s.weakening).map((s) => s.sector);
    const sentences: string[] = [];
    sentences.push(
      pulse.overallSentiment === "bullish"
        ? "The market remains in a healthy uptrend."
        : pulse.overallSentiment === "bearish"
          ? "The market is under pressure and risk is elevated."
          : "The market is range-bound and selective.",
    );
    sentences.push(
      breadth.breadthTrend === "up"
        ? `Breadth ${breadth.breadthMomentum === "strong" ? "strengthened" : "improved"}, with ${Math.round(breadth.marketParticipationScore)}% participation.`
        : breadth.breadthTrend === "down"
          ? `Breadth deteriorated, with only ${Math.round(breadth.marketParticipationScore)}% participation.`
          : `Breadth is steady at ${Math.round(breadth.marketParticipationScore)}% participation.`,
    );
    if (leaders.length) sentences.push(`${leaders.join(", ")} ${leaders.length > 1 ? "continue" : "continues"} to lead.`);
    if (weak.length) sentences.push(`${weak.join(", ")} ${weak.length > 1 ? "have" : "has"} weakened slightly.`);
    sentences.push(`Overall risk is ${ctx.decision.overallRisk} and market quality reads ${Math.round(ctx.decision.marketQuality)}/100.`);
    return NarrativeBuilder.build({
      id: "narrative-market-daily",
      kind: "market",
      title: `Daily Market Summary — ${regime.regime}`,
      body: sentences.join(" "),
      relatedObjects: [pulse.id, breadth.id, regime.id],
    });
  }

  static sector(s: SectorSnapshot): Narrative {
    const sentences: string[] = [];
    sentences.push(
      `${s.sector} is ${s.leadership ? "a leadership sector" : "not leading"}, ranked #${s.rank} by strength.`,
    );
    sentences.push(
      `It is up ${s.performance1M.toFixed(1)}% over one month and ${s.performanceYTD.toFixed(1)}% YTD, with relative strength of ${s.relativeStrength}.`,
    );
    sentences.push(
      `${Math.round(s.participation)}% of constituents are advancing; momentum is ${s.momentum.toFixed(1)}.`,
    );
    if (s.topStocks.length) sentences.push(`Top names: ${s.topStocks.join(", ")}.`);
    return NarrativeBuilder.build({
      id: `narrative-sector-${s.sector}`,
      kind: "sector",
      title: `${s.sector} Summary`,
      body: sentences.join(" "),
      relatedObjects: [s.id],
    });
  }

  static stock(s: StockSnapshot, trend: StockTrend, momentum: StockMomentum, signal: TradingSignal): Narrative {
    const sentences: string[] = [];
    sentences.push(
      `${s.name} (${s.symbol}) trades at ${s.currentPrice}, ${s.priceChangePercent >= 0 ? "up" : "down"} ${Math.abs(s.priceChangePercent).toFixed(1)}% on the session.`,
    );
    sentences.push(
      `Price is ${trend.movingAverages.priceVsMA50 >= 0 ? "above" : "below"} its 50-day average by ${Math.abs(trend.movingAverages.priceVsMA50).toFixed(1)}%; the trend reads ${trend.priceTrend}.`,
    );
    sentences.push(
      `Momentum is ${momentum.momentumScore.toFixed(0)}/100 with relative strength ${momentum.relativeStrength} versus the market.`,
    );
    sentences.push(`Our framework rates it ${signal.rating.replace("_", " ")} (confidence ${signal.confidenceScore.toFixed(0)}%).`);
    return NarrativeBuilder.build({
      id: `narrative-stock-${s.symbol}`,
      kind: "stock",
      title: `${s.symbol} Summary`,
      body: sentences.join(" "),
      relatedObjects: [s.id, trend.id, momentum.id, signal.id],
    });
  }

  static portfolio(p: PortfolioSummary): Narrative {
    const sentences: string[] = [];
    sentences.push(
      `The ${p.name} is valued at ${p.totalValue.toLocaleString("en-IN")}, with ${p.exposure}% deployed and ${p.cash.toLocaleString("en-IN")} in cash.`,
    );
    sentences.push(`Total P&L is ${p.totalPnlPercent.toFixed(1)}% and the book holds ${p.holdingsCount} positions.`);
    if (p.topSectors.length) sentences.push(`Concentration is in ${p.topSectors.join(", ")}; diversification scores ${p.diversificationScore}/100.`);
    return NarrativeBuilder.build({
      id: `narrative-portfolio-${p.portfolioId}`,
      kind: "portfolio",
      title: `${p.name} Summary`,
      body: sentences.join(" "),
      relatedObjects: [p.id],
    });
  }

  static research(s: StockSnapshot, thesis: InvestmentThesis): Narrative {
    const sentences: string[] = [];
    sentences.push(`${s.name} — ${thesis.suggestedAction} (confidence ${thesis.confidence}%).`);
    sentences.push(`Thesis: ${thesis.marketContext} ${thesis.sectorContext}`);
    if (thesis.catalysts.length) sentences.push(`Catalysts: ${thesis.catalysts.join("; ")}.`);
    if (thesis.warnings.length) sentences.push(`Warnings: ${thesis.warnings.join("; ")}.`);
    return NarrativeBuilder.build({
      id: `narrative-research-${s.symbol}`,
      kind: "research",
      title: `Research Note — ${s.symbol}`,
      body: sentences.join(" "),
      relatedObjects: [s.id, thesis.id],
    });
  }
}
