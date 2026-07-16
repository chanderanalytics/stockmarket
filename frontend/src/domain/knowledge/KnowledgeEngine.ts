import type { Knowledge, KnowledgeContext } from "./models";
import { KnowledgeBuilder } from "./services/KnowledgeBuilder";
import { KnowledgeClassifier } from "./services/KnowledgeClassifier";
import { KnowledgeAggregator } from "./services/KnowledgeAggregator";
import { EvidenceBuilder } from "../evidence/EvidenceBuilder";
import { EvidenceEngine } from "../evidence/EvidenceEngine";
import type { Evidence } from "../evidence/Evidence";

// KnowledgeEngine — the central interpreter. Converts Market Intelligence
// Runtime outputs into reusable, human-readable Knowledge objects. Pure and
// rule-based: it explains WHY, it does not recalculate indicators.
export class KnowledgeEngine {
  static compute(ctx: KnowledgeContext): Knowledge[] {
    const evidence = EvidenceEngine.compute({
      breadth: ctx.breadth,
      probability: undefined,
      sectors: ctx.sectors,
      signals: ctx.signals,
    });

    const lists: Knowledge[][] = [
      this.fromPulse(ctx),
      this.fromBreadth(ctx),
      this.fromRegime(ctx),
      this.fromSectors(ctx),
      this.fromSignals(ctx),
      this.fromDecision(ctx),
      this.fromPortfolio(ctx),
      this.fromWatchlist(ctx),
      this.fromOpportunities(ctx),
    ];

    const knowledge = KnowledgeAggregator.aggregate(lists);
    // Attach the global evidence pool to knowledge that has none, so every
    // item remains explainable.
    return knowledge.map((k) =>
      k.supportingEvidence.length === 0 ? { ...k, supportingEvidence: evidence.slice(0, 3) } : k,
    );
  }

  private static fromPulse(ctx: KnowledgeContext): Knowledge[] {
    const p = ctx.pulse;
    const sentimentText =
      p.overallSentiment === "bullish" ? "Risk appetite is constructive" : p.overallSentiment === "bearish" ? "Risk appetite is defensive" : "Sentiment is balanced";
    return [
      KnowledgeBuilder.build({
        id: "knowledge-market-pulse",
        title: `Market sentiment: ${p.overallSentiment}`,
        summary: `${sentimentText}. ${p.outlook} Key drivers: ${p.keyDrivers.join("; ")}.`,
        category: "market",
        confidence: p.regimeConfidence === "high" ? 80 : p.regimeConfidence === "medium" ? 60 : 40,
        importance: 85,
        relatedObjects: [p.id],
        source: { engine: "knowledge-engine", objectType: "MarketPulse", objectId: p.id },
      }),
    ];
  }

  private static fromBreadth(ctx: KnowledgeContext): Knowledge[] {
    const b = ctx.breadth;
    const part = b.marketParticipationScore;
    const phrase =
      part >= 55
        ? "Market breadth is healthy, with the majority of stocks participating in the advance."
        : part <= 40
          ? "Market breadth is weak; the advance is narrow and vulnerable to a reversal."
          : "Market breadth is mixed, signalling a stock-picker's market.";
    const trendPhrase =
      b.breadthTrend === "up"
        ? "Breadth is improving."
        : b.breadthTrend === "down"
          ? "Breadth is deteriorating."
          : "Breadth is stable.";
    return [
      KnowledgeBuilder.build({
        id: "knowledge-market-breadth",
        title: `Breadth ${b.breadthTrend}`,
        summary: `${phrase} ${trendPhrase} ${Math.round(part)}% of stocks are above their 50-day average and net advances stand at ${b.netAdvances}.`,
        category: "breadth",
        confidence: 82,
        importance: KnowledgeClassifier.importanceFromParticipation(part),
        relatedObjects: [b.id],
        source: { engine: "knowledge-engine", objectType: "MarketBreadth", objectId: b.id },
      }),
    ];
  }

  private static fromRegime(ctx: KnowledgeContext): Knowledge[] {
    const r = ctx.regime;
    return [
      KnowledgeBuilder.build({
        id: "knowledge-market-regime",
        title: `Regime: ${r.regime}`,
        summary: r.historicalComparison,
        category: "market",
        confidence: r.confidenceScore,
        importance: 80,
        relatedObjects: [r.id],
        source: { engine: "knowledge-engine", objectType: "MarketRegime", objectId: r.id },
      }),
    ];
  }

  private static fromSectors(ctx: KnowledgeContext): Knowledge[] {
    return ctx.sectors
      .filter((s) => s.leadership)
      .map((s) =>
        KnowledgeBuilder.build({
          id: `knowledge-sector-${s.sector}`,
          title: `${s.sector} is leading`,
          summary: `${s.sector} shows leadership (rank #${s.rank}). Relative strength is ${s.relativeStrength} with ${Math.round(s.participation)}% of constituents advancing and ${s.momentum.toFixed(1)} momentum.`,
          category: "sector",
          confidence: Math.round(s.relativeStrength),
          importance: Math.round(s.relativeStrength),
          relatedObjects: [s.id],
          source: { engine: "knowledge-engine", objectType: "SectorSnapshot", objectId: s.id },
        }),
      );
  }

  private static fromSignals(ctx: KnowledgeContext): Knowledge[] {
    return ctx.signals.map((sig) => {
      const ev: Evidence[] = sig.evidence.map((se) => EvidenceBuilder.fromSignalEvidence(se, sig.symbol));
      const phrase =
        sig.rating.includes("buy")
          ? `The weight of evidence supports accumulation in ${sig.symbol}.`
          : sig.rating.includes("sell") || sig.rating === "avoid"
            ? `The weight of evidence argues caution on ${sig.symbol}.`
            : `The setup for ${sig.symbol} is balanced; wait for confirmation.`;
      return KnowledgeBuilder.build({
        id: `knowledge-signal-${sig.symbol}`,
        title: `${sig.symbol}: ${sig.rating.replace("_", " ")}`,
        summary: `${phrase} ${sig.reason}`,
        category: "signal",
        confidence: sig.confidenceScore,
        importance: KnowledgeClassifier.importanceFromRating(sig.rating),
        evidence: ev,
        relatedObjects: [sig.id],
        source: { engine: "knowledge-engine", objectType: "TradingSignal", objectId: sig.id },
      });
    });
  }

  private static fromDecision(ctx: KnowledgeContext): Knowledge[] {
    const d = ctx.decision;
    return [
      KnowledgeBuilder.build({
        id: "knowledge-decision",
        title: d.deployNewMoney ? "Deploy capital selectively" : "Hold cash, stay defensive",
        summary: d.summary,
        category: "decision",
        confidence: Math.round(d.marketQuality),
        importance: 88,
        relatedObjects: [d.id],
        source: { engine: "knowledge-engine", objectType: "DecisionSummary", objectId: d.id },
      }),
    ];
  }

  private static fromPortfolio(ctx: KnowledgeContext): Knowledge[] {
    if (!ctx.portfolio) return [];
    const p = ctx.portfolio;
    return [
      KnowledgeBuilder.build({
        id: `knowledge-portfolio-${p.portfolioId}`,
        title: `Portfolio: ${p.name}`,
        summary: `Portfolio value ${p.totalValue.toLocaleString("en-IN")} with ${p.exposure}% deployed and ${p.cash.toLocaleString("en-IN")} in cash. P&L is ${p.totalPnlPercent.toFixed(1)}%. Top sectors: ${p.topSectors.join(", ")}.`,
        category: "portfolio",
        confidence: 75,
        importance: 70,
        relatedObjects: [p.id],
        source: { engine: "knowledge-engine", objectType: "PortfolioSummary", objectId: p.id },
      }),
    ];
  }

  private static fromWatchlist(ctx: KnowledgeContext): Knowledge[] {
    if (!ctx.watchlist) return [];
    const w = ctx.watchlist;
    return [
      KnowledgeBuilder.build({
        id: `knowledge-watchlist-${w.watchlistId}`,
        title: `Watchlist: ${w.name}`,
        summary: `${w.itemCount} names; ${w.advancers} advancing, ${w.decliners} declining. Strongest: ${w.strongest}, weakest: ${w.weakest}. Average move ${w.avgChangePercent.toFixed(1)}%.`,
        category: "watchlist",
        confidence: 70,
        importance: 55,
        relatedObjects: [w.id],
        source: { engine: "knowledge-engine", objectType: "WatchlistSummary", objectId: w.id },
      }),
    ];
  }

  private static fromOpportunities(ctx: KnowledgeContext): Knowledge[] {
    return ctx.opportunities.map((o) =>
      KnowledgeBuilder.build({
        id: `knowledge-opportunity-${o.symbol}`,
        title: `Opportunity: ${o.symbol}`,
        summary: `${o.opportunityType} setup with entry near ${o.entryPrice}, target ${o.targetPrice}, stop ${o.stopLoss} (R:R ${o.riskRewardRatio}). Probability of success ${o.probabilityOfSuccess}%.`,
        category: "opportunity",
        confidence: Math.round(o.probabilityOfSuccess),
        importance: 72,
        relatedObjects: [o.id],
        source: { engine: "knowledge-engine", objectType: "TradingOpportunity", objectId: o.id },
      }),
    );
  }
}
