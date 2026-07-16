import type { Alert, AlertSeverity, AlertType } from "./Alert";
import type { KnowledgeContext } from "../knowledge/models/KnowledgeContext";

function severityFromImportance(i: number): AlertSeverity {
  return i >= 80 ? "critical" : i >= 55 ? "warning" : "info";
}

// AlertEngine — turns knowledge/threshold breaches into alert objects.
export class AlertEngine {
  static compute(ctx: KnowledgeContext): Alert[] {
    const out: Alert[] = [];
    const ts = new Date().toISOString();
    const push = (a: Omit<Alert, "id" | "timestamp" | "severity"> & { severity?: AlertSeverity }) => {
      const importance = a.importance;
      out.push({ id: `alert-${out.length}-${a.type}`, timestamp: ts, severity: a.severity ?? severityFromImportance(importance), ...a });
    };

    const part = ctx.breadth.marketParticipationScore;

    // Market
    if (part < 40 || ctx.breadth.breadthTrend === "down") {
      push({
        type: "market",
        title: "Breadth deteriorated",
        message: `Participation fell to ${Math.round(part)}% and breadth is ${ctx.breadth.breadthTrend}.`,
        importance: 78,
        suggestedAction: "Reduce exposure and raise cash.",
        relatedObjects: [ctx.breadth.id],
      });
    }
    if (["Bear", "Correction", "Capitulation"].includes(ctx.regime.regime)) {
      push({
        type: "market",
        title: `Regime shifted to ${ctx.regime.regime}`,
        message: ctx.regime.historicalComparison,
        importance: 88,
        suggestedAction: "Shift to defensive positioning.",
        relatedObjects: [ctx.regime.id],
      });
    }

    // Sector
    for (const s of ctx.sectors.filter((x) => x.weakening && x.leadership)) {
      push({
        type: "sector",
        title: `${s.sector} leadership weakening`,
        message: `Relative strength slipped to ${s.relativeStrength} though still ranked #${s.rank}.`,
        importance: 65,
        suggestedAction: "Trim exposure to the sector.",
        relatedObjects: [s.id],
      });
    }

    // Stock / Opportunity
    for (const sig of ctx.signals) {
      if (sig.rating === "strong_buy" || sig.rating === "buy") {
        push({
          type: "opportunity",
          title: `Buy signal: ${sig.symbol}`,
          message: `${sig.rating.replace("_", " ")} with ${sig.confidenceScore.toFixed(0)}% confidence.`,
          importance: Math.round(sig.confidenceScore),
          suggestedAction: "Review for entry.",
          relatedObjects: [sig.id],
        });
      } else if (sig.rating === "sell" || sig.rating === "avoid") {
        push({
          type: "stock",
          title: `Exit signal: ${sig.symbol}`,
          message: `${sig.rating.replace("_", " ")} with ${sig.confidenceScore.toFixed(0)}% confidence.`,
          importance: Math.round(sig.confidenceScore),
          suggestedAction: "Consider trimming.",
          relatedObjects: [sig.id],
        });
      }
    }

    // Watchlist
    if (ctx.watchlist) {
      push({
        type: "watchlist",
        title: "Watchlist update",
        message: `${ctx.watchlist.advancers} up / ${ctx.watchlist.decliners} down; weakest ${ctx.watchlist.weakest}.`,
        importance: 50,
        suggestedAction: "Monitor weakest names.",
        relatedObjects: [ctx.watchlist.id],
      });
    }

    // Portfolio / Risk
    if (ctx.portfolio && ctx.decision.overallRisk === "high") {
      push({
        type: "portfolio",
        title: "Portfolio risk elevated",
        message: `Exposure ${ctx.portfolio.exposure}% with overall risk ${ctx.decision.overallRisk}.`,
        importance: 80,
        suggestedAction: "Hedge or reduce beta.",
        relatedObjects: [ctx.portfolio.id, ctx.decision.id],
      });
    }
    if (ctx.regime && ctx.regime.supportingMetrics.find((m) => m.label === "Volatility")?.value !== undefined) {
      const vol = Number(ctx.regime.supportingMetrics.find((m) => m.label === "Volatility")?.value);
      if (vol > 24) {
        push({
          type: "risk",
          title: "Volatility spike",
          message: `Implied volatility at ${vol} signals elevated tail risk.`,
          importance: 75,
          suggestedAction: "Size positions smaller.",
          relatedObjects: [ctx.regime.id],
        });
      }
    }

    return out.sort((a, b) => b.importance - a.importance);
  }
}
