import type { Insight, InsightCategory, InsightPriority } from "./Insight";
import type { KnowledgeContext } from "../knowledge/models/KnowledgeContext";

function priorityFromConfidence(c: number): InsightPriority {
  return c >= 75 ? "high" : c >= 50 ? "medium" : "low";
}

// InsightEngine — derives independent insights across categories from the
// structured knowledge context. Deterministic.
export class InsightEngine {
  static compute(ctx: KnowledgeContext): Insight[] {
    const out: Insight[] = [];
    const ts = new Date().toISOString();
    const push = (i: Omit<Insight, "id" | "timestamp">) =>
      out.push({ id: `insight-${out.length}-${i.category}`, timestamp: ts, ...i });

    const part = ctx.breadth.marketParticipationScore;

    // Breadth
    push({
      title: `Breadth is ${ctx.breadth.breadthTrend}`,
      description: `${Math.round(part)}% of stocks are above their 50-day average; net advances ${ctx.breadth.netAdvances}.`,
      category: "breadth",
      priority: priorityFromConfidence(Math.abs(part - 50) + 40),
      confidence: 84,
      relatedObjects: [ctx.breadth.id],
    });

    // Bullish / Bearish / Neutral from regime + breadth
    if (ctx.decision.deployNewMoney) {
      push({
        title: "Constructive backdrop for deployment",
        description: `Regime ${ctx.regime.regime} with ${Math.round(ctx.decision.marketQuality)}/100 market quality supports selective buying.`,
        category: "bullish",
        priority: "high",
        confidence: Math.round(ctx.decision.marketQuality),
        relatedObjects: [ctx.regime.id, ctx.decision.id],
      });
    } else if (["Bear", "Correction", "Capitulation", "Weak"].includes(ctx.regime.regime)) {
      push({
        title: "Defensive posture warranted",
        description: `Regime ${ctx.regime.regime} with deteriorating breadth argues for caution and higher cash.`,
        category: "bearish",
        priority: "high",
        confidence: Math.round(ctx.decision.marketQuality),
        relatedObjects: [ctx.regime.id, ctx.decision.id],
      });
    } else {
      push({
        title: "Selective, range-bound tape",
        description: "No decisive trend; focus on relative strength and stock-specific setups.",
        category: "neutral",
        priority: "medium",
        confidence: 55,
        relatedObjects: [ctx.regime.id],
      });
    }

    // Sector leadership
    const leaders = ctx.sectors.filter((s) => s.leadership);
    if (leaders.length) {
      push({
        title: `${leaders.map((s) => s.sector).join(", ")} leading`,
        description: `${leaders.length} sector(s) show leadership; rotate exposure toward them.`,
        category: "sector",
        priority: "high",
        confidence: Math.round(leaders[0].relativeStrength),
        relatedObjects: leaders.map((s) => s.id),
      });
    }

    // Momentum
    const avgMom = ctx.sectors.reduce((a, s) => a + s.momentum, 0) / (ctx.sectors.length || 1);
    push({
      title: `Sector momentum ${avgMom > 0 ? "positive" : "negative"}`,
      description: `Average sector momentum reads ${avgMom.toFixed(1)}.`,
      category: "momentum",
      priority: priorityFromConfidence(Math.abs(avgMom) + 45),
      confidence: 70,
      relatedObjects: ctx.sectors.map((s) => s.id),
    });

    // Opportunity
    for (const sig of ctx.signals.filter((s) => s.rating === "strong_buy" || s.rating === "buy")) {
      push({
        title: `Opportunity: ${sig.symbol}`,
        description: `${sig.rating.replace("_", " ")} signal with ${sig.confidenceScore.toFixed(0)}% confidence.`,
        category: "opportunity",
        priority: priorityFromConfidence(sig.confidenceScore),
        confidence: Math.round(sig.confidenceScore),
        relatedObjects: [sig.id],
      });
    }

    // Warning / Risk
    if (part <= 40) {
      push({
        title: "Breadth warning",
        description: "Participation is thin; the advance is narrow and prone to reversal.",
        category: "warning",
        priority: "high",
        confidence: 80,
        relatedObjects: [ctx.breadth.id],
      });
    }
    if (ctx.decision.overallRisk === "high") {
      push({
        title: "Elevated portfolio risk",
        description: `Overall risk reads high; consider trimming exposure toward ${ctx.decision.recommendedExposure}%%.`,
        category: "risk",
        priority: "high",
        confidence: 78,
        relatedObjects: [ctx.decision.id],
      });
    }

    // Portfolio
    if (ctx.portfolio) {
      push({
        title: "Portfolio concentration",
        description: `Top sectors: ${ctx.portfolio.topSectors.join(", ")}; diversification ${ctx.portfolio.diversificationScore}/100.`,
        category: "portfolio",
        priority: "medium",
        confidence: 72,
        relatedObjects: [ctx.portfolio.id],
      });
    }

    // Research
    const top = [...ctx.signals].sort((a, b) => b.confidenceScore - a.confidenceScore)[0];
    if (top) {
      push({
        title: `Research focus: ${top.symbol}`,
        description: `Highest-conviction name is ${top.symbol} (${top.rating.replace("_", " ")}).`,
        category: "research",
        priority: "medium",
        confidence: Math.round(top.confidenceScore),
        relatedObjects: [top.id],
      });
    }

    return out;
  }
}
