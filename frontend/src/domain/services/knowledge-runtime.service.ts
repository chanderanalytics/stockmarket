import { MarketRuntime } from "./market-runtime.service";
import type { KnowledgeContext } from "../knowledge/models/KnowledgeContext";
import { KnowledgeEngine } from "../knowledge/KnowledgeEngine";
import { NarrativeEngine } from "../narrative/NarrativeEngine";
import { InsightEngine } from "../insight/InsightEngine";
import { AlertEngine } from "../alert/AlertEngine";
import { ExplanationEngine } from "../explanation/ExplanationEngine";
import type { Explanation } from "../explanation/Explanation";
import { InvestmentThesisEngine } from "../thesis/InvestmentThesisEngine";
import type { InvestmentThesis } from "../thesis/InvestmentThesis";
import { KnowledgeGraph } from "../graph/KnowledgeGraph";
import type { Knowledge } from "../knowledge/models/Knowledge";
import type { Insight } from "../insight/Insight";
import type { Alert } from "../alert/Alert";
import type { Narrative } from "../narrative/Narrative";

// KnowledgeRuntime — orchestrates the Market Knowledge Runtime. It consumes
// Market Intelligence Runtime outputs (never raw data) and produces reusable,
// explainable knowledge objects for every consumer (frontend, AI, alerts).
export const KnowledgeRuntime = {
  context(): KnowledgeContext {
    const signals = MarketRuntime.signals();
    const stocks = signals.map((s) => MarketRuntime.stockSnapshot(s.symbol).snapshot);
    return {
      pulse: MarketRuntime.pulse(),
      breadth: MarketRuntime.breadth(),
      regime: MarketRuntime.regime(),
      sectors: MarketRuntime.sectors(),
      stocks,
      signals,
      decision: MarketRuntime.decision(),
      opportunities: MarketRuntime.opportunities(),
      portfolio: MarketRuntime.portfolioSummary(),
      watchlist: MarketRuntime.watchlistSummary(),
    };
  },

  knowledge(): Knowledge[] {
    return KnowledgeEngine.compute(this.context());
  },

  marketView() {
    const ctx = this.context();
    return {
      pulse: ctx.pulse,
      breadth: ctx.breadth,
      regime: ctx.regime,
      decision: ctx.decision,
      knowledge: KnowledgeEngine.compute(ctx),
      narrative: NarrativeEngine.dailyMarket(ctx),
      insights: InsightEngine.compute(ctx),
      alerts: AlertEngine.compute(ctx),
    };
  },

  sectorView() {
    const ctx = this.context();
    return ctx.sectors.map((s) => ({
      snapshot: s,
      knowledge: KnowledgeEngine.compute(ctx).filter((k) => k.relatedObjects.includes(s.id)),
      narrative: NarrativeEngine.sector(s),
    }));
  },

  stockView(symbol: string) {
    const ctx = this.context();
    const snap = MarketRuntime.stockSnapshot(symbol.toUpperCase());
    const sector = ctx.sectors.find((s) => s.sector === snap.snapshot.sector);
    const thesis = InvestmentThesisEngine.build({
      snapshot: snap.snapshot,
      trend: snap.trend,
      momentum: snap.momentum,
      probability: snap.probability,
      signal: snap.signal,
      sector,
      regime: ctx.regime,
    });
    const knowledge = KnowledgeEngine.compute(ctx).filter((k) => k.relatedObjects.includes(snap.signal.id) || k.relatedObjects.includes(snap.snapshot.id));
    return {
      snapshot: snap.snapshot,
      trend: snap.trend,
      momentum: snap.momentum,
      probability: snap.probability,
      signal: snap.signal,
      thesis,
      knowledge,
      narrative: NarrativeEngine.stock(snap.snapshot, snap.trend, snap.momentum, snap.signal),
      explanation: ExplanationEngine.explainSignal(snap.signal),
    };
  },

  portfolioView() {
    const ctx = this.context();
    if (!ctx.portfolio) return null;
    return {
      summary: ctx.portfolio,
      knowledge: KnowledgeEngine.compute(ctx).filter((k) => k.relatedObjects.includes(ctx.portfolio!.id)),
      narrative: NarrativeEngine.portfolio(ctx.portfolio),
    };
  },

  opportunities() {
    const ctx = this.context();
    return {
      opportunities: ctx.opportunities,
      knowledge: KnowledgeEngine.compute(ctx).filter((k) => k.category === "opportunity"),
    };
  },

  insights(): Insight[] {
    return InsightEngine.compute(this.context());
  },

  alerts(): Alert[] {
    return AlertEngine.compute(this.context());
  },

  thesis(symbol: string): InvestmentThesis {
    return this.stockView(symbol).thesis;
  },

  graph(): KnowledgeGraph {
    const ctx = this.context();
    const theses = ctx.signals
      .filter((s) => s.rating === "strong_buy" || s.rating === "buy" || s.rating === "watch")
      .map((s) => {
        const snap = MarketRuntime.stockSnapshot(s.symbol);
        const sector = ctx.sectors.find((x) => x.sector === snap.snapshot.sector);
        return InvestmentThesisEngine.build({ snapshot: snap.snapshot, trend: snap.trend, momentum: snap.momentum, probability: snap.probability, signal: snap.signal, sector, regime: ctx.regime });
      });
    return KnowledgeGraph.build(ctx, theses);
  },

  explanationLookup(): Map<string, Explanation> {
    const ctx = this.context();
    const map = new Map<string, Explanation>();
    for (const s of ctx.signals) map.set(`explanation-${s.id}`, ExplanationEngine.explainSignal(s));
    map.set(`explanation-${ctx.decision.id}`, ExplanationEngine.explainDecision(ctx.decision));
    for (const k of KnowledgeEngine.compute(ctx)) map.set(`explanation-${k.id}`, ExplanationEngine.explainKnowledge(k));
    return map;
  },

  explanation(id: string): Explanation | null {
    return this.explanationLookup().get(id) ?? null;
  },
};

export type { Narrative };
