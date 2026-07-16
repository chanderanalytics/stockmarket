import type { InvestmentThesis, SuggestedAction } from "./InvestmentThesis";
import type { Evidence } from "../evidence/Evidence";
import { EvidenceBuilder } from "../evidence/EvidenceBuilder";
import type { StockSnapshot } from "../models/stocks";
import type { StockTrend } from "../models/stocks";
import type { StockMomentum } from "../models/stocks";
import type { ProbabilityAnalysis } from "../models/probability";
import type { TradingSignal } from "../models/signals";
import type { SectorSnapshot } from "../models/sectors";
import type { MarketRegime } from "../models/market";

const ACTION_BY_RATING: Record<string, SuggestedAction> = {
  strong_buy: "accumulate",
  buy: "accumulate",
  watch: "watch",
  neutral: "hold",
  weak: "reduce",
  sell: "reduce",
  avoid: "avoid",
};

export interface ThesisInput {
  snapshot: StockSnapshot;
  trend: StockTrend;
  momentum: StockMomentum;
  probability: ProbabilityAnalysis;
  signal: TradingSignal;
  sector?: SectorSnapshot;
  regime?: MarketRegime;
}

// InvestmentThesisEngine — assembles a full thesis from structured outputs.
export class InvestmentThesisEngine {
  static build(input: ThesisInput): InvestmentThesis {
    const { snapshot, trend, momentum, probability, signal, sector, regime } = input;
    const evidence: Evidence[] = signal.evidence.map((se) => EvidenceBuilder.fromSignalEvidence(se, snapshot.symbol));

    const marketContext =
      regime
        ? `Market is in a ${regime.regime} regime (${regime.confidence} confidence), which ${regime.regime.includes("Bull") || regime.regime === "Recovering" ? "supports risk-taking" : regime.regime.includes("Bear") || regime.regime === "Capitulation" ? "argues for caution" : "calls for selectivity"}.`
        : "Market context is neutral.";

    const sectorContext = sector
      ? `${snapshot.sector} is ${sector.leadership ? "a leadership sector" : "not leading"} (rank #${sector.rank}, relative strength ${sector.relativeStrength}).`
      : `${snapshot.sector} context unavailable.`;

    const trendText = `Price is ${trend.movingAverages.priceVsMA50 >= 0 ? "above" : "below"} its 50-day average by ${Math.abs(trend.movingAverages.priceVsMA50).toFixed(1)}%; structure is ${trend.priceTrend} and ${trend.trendStrength}.`;
    const momentumText = `Momentum reads ${momentum.momentumScore.toFixed(0)}/100 with relative strength ${momentum.relativeStrength} and ${momentum.volumeTrend} volume.`;
    const probText = `Probability model implies ${probability.upsideProbability}% upside vs ${probability.downsideProbability}% downside; expected holding ${probability.expectedHoldingPeriod} days, reward/risk ${probability.rewardRiskRatio}.`;
    const riskText = `Risk is ${signal.risk} (score ${signal.riskScore.toFixed(0)}); volatility expectation ${probability.volatilityExpectation}%.`;

    const catalysts: string[] = [];
    if (sector?.leadership) catalysts.push("Sector leadership");
    if (probability.upsideProbability >= 55) catalysts.push("Favourable probability distribution");
    if (trend.movingAverages.priceVsMA50 > 0) catalysts.push("Above 50 DMA");
    if (momentum.momentumScore >= 55) catalysts.push("Improving momentum");

    const warnings: string[] = [];
    if (signal.risk === "high") warnings.push("Elevated risk score");
    if (probability.downsideProbability >= 50) warnings.push("High downside probability");
    if (momentum.volumeTrend === "decreasing") warnings.push("Volume below average");
    if (trend.movingAverages.priceVsMA200 < 0) warnings.push("Below 200 DMA");

    const days = probability.expectedHoldingPeriod;
    const holdingPeriod = days <= 10 ? `${days} days` : days <= 45 ? `${Math.round(days / 7)} weeks` : `${Math.round(days / 30)} months`;

    const suggestedAction = ACTION_BY_RATING[signal.rating] ?? "hold";
    const entryBias =
      suggestedAction === "accumulate"
        ? "Accumulate on dips toward the 50 DMA; stagger entries."
        : suggestedAction === "reduce" || suggestedAction === "avoid"
          ? "Reduce or avoid; wait for a cleaner setup."
          : "Build on confirmation above resistance.";
    const exitConsiderations = `Exit if price loses the ${trend.supportLevel} support or the thesis evidence weakens; trail stops using the 20-day average.`;

    return {
      id: `thesis-${snapshot.symbol}`,
      timestamp: new Date().toISOString(),
      symbol: snapshot.symbol,
      marketContext,
      sectorContext,
      trend: trendText,
      momentum: momentumText,
      probability: probText,
      risk: riskText,
      holdingPeriod,
      catalysts,
      warnings,
      supportingEvidence: evidence,
      confidence: Math.round(signal.confidenceScore),
      suggestedAction,
      entryBias,
      exitConsiderations,
    };
  }
}
