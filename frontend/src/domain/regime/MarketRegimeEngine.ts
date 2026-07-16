import type { MarketBreadth } from "../models/market";
import type { MarketRegime } from "../models/market";
import { clamp } from "../indicators/calculators/_utils";

export interface RegimeInput {
  breadth: MarketBreadth;
  indexReturn1M: number; // percent
  volatility: number; // annualized %, e.g. VIX-equivalent
  momentum: number; // -100..100
  priorRegime?: MarketRegime["regime"];
}

type Regime = MarketRegime["regime"];

// MarketRegimeEngine — classifies the current market regime.
export class MarketRegimeEngine {
  static compute(input: RegimeInput): MarketRegime {
    const { breadth, indexReturn1M, volatility, momentum } = input;
    const above200 = breadth.percentageAbove200DMA;
    const net = breadth.netAdvances;
    const participation = breadth.marketParticipationScore;

    let regime: Regime;
    let score: number;

    if (volatility > 30 && participation < 30) {
      regime = "Capitulation";
      score = 12;
    } else if (volatility > 25 && indexReturn1M < -8) {
      regime = "Correction";
      score = 22;
    } else if (indexReturn1M < -4 && above200 < 45) {
      regime = "Bear";
      score = 28;
    } else if (participation < 40 && momentum < -20) {
      regime = "Weak";
      score = 36;
    } else if (volatility > 22 && participation < 50) {
      regime = "High Risk";
      score = 42;
    } else if (above200 < 50 && indexReturn1M > 0 && momentum > 0) {
      regime = "Recovering";
      score = 55;
    } else if (Math.abs(indexReturn1M) < 3 && Math.abs(momentum) < 15) {
      regime = "Sideways";
      score = 50;
    } else if (indexReturn1M > 4 && above200 > 55 && participation > 55) {
      regime = "Strong Bull";
      score = 85;
    } else if (indexReturn1M > 1 && above200 > 50) {
      regime = "Bull";
      score = 68;
    } else {
      regime = "Sideways";
      score = 50;
    }

    // Confidence: how decisively metrics agree with the regime direction.
    const confidenceScore = clamp(score + (participation - 50) * 0.2, 0, 100);
    const confidence: MarketRegime["confidence"] =
      confidenceScore >= 66 ? "high" : confidenceScore >= 40 ? "medium" : "low";

    const supportingMetrics = [
      { label: "1M Index Return", value: `${indexReturn1M.toFixed(2)}%` },
      { label: "Net Advances", value: String(net) },
      { label: "% Above 200 DMA", value: `${above200.toFixed(1)}%` },
      { label: "Participation", value: `${participation.toFixed(1)}%` },
      { label: "Volatility", value: volatility.toFixed(1) },
      { label: "Momentum", value: momentum.toFixed(1) },
    ];

    const historicalComparison = MarketRegimeEngine.compare(regime, score);

    return {
      id: "market-regime",
      timestamp: new Date().toISOString(),
      regime,
      confidence,
      confidenceScore: +confidenceScore.toFixed(1),
      supportingMetrics,
      historicalComparison,
    };
  }

  private static compare(regime: Regime, score: number): string {
    const text: Record<Regime, string> = {
      "Strong Bull": "Broad participation and price above long-term averages — historically the most durable uptrend.",
      Bull: "Constructive trend with healthy breadth; pullbacks tend to be buyable.",
      Recovering: "Early-stage improvement off lows; leadership still being established.",
      Sideways: "Range-bound market; stock selection matters more than direction.",
      Weak: "Deteriorating breadth; defensive posture preferred.",
      Bear: "Sustained downtrend with majority of names below key averages.",
      Correction: "Sharp drawdown underway; volatility elevated.",
      "High Risk": "Fragile tape — reduced exposure warranted.",
      Capitulation: "Panic selling; often a washout that precedes a bottom.",
    };
    return text[regime];
  }
}
