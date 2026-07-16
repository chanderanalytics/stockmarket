import type { ProbabilityAnalysis, ExpectedReturn } from "../models/probability";
import type { SignalRating } from "../models/signals";
import type { ProbabilityWideRow } from "../types";
import { clamp } from "../indicators/calculators/_utils";

// ProbabilityEngine — maps the hundreds-of-column wide probability table to a
// single, normalized business object. The DB row is normalized upstream into
// ProbabilityWideRow; nothing here references raw column names.
export class ProbabilityEngine {
  static compute(row: ProbabilityWideRow): ProbabilityAnalysis {
    const buckets = row.returnBuckets.filter((b) => b.probability > 0);
    const upsideProbability = clamp(buckets.reduce((s, b) => s + b.probability, 0), 0, 100);

    // Expected return: weighted midpoint of positive-return buckets.
    const expectedBase = buckets.reduce((s, b) => s + ((b.from + b.to) / 2) * (b.probability / 100), 0);
    const vol = row.volatility21d || 15;
    const expectedBull = expectedBase + vol * 0.5;
    const expectedBear = Math.max(-vol, expectedBase - vol * 0.8);

    const expectedReturn: ExpectedReturn[] = [
      { horizon: "21d", value: +expectedBase.toFixed(2), scenario: "base" },
      { horizon: "21d", value: +expectedBull.toFixed(2), scenario: "bull" },
      { horizon: "21d", value: +expectedBear.toFixed(2), scenario: "bear" },
    ];

    // Downside reflects the complementary mass, tilted by volatility (tail risk).
    const downsideProbability = clamp(100 - upsideProbability + (vol - 15) * 0.8, 0, 100);

    // Longer holding when trend is cleaner (lower vol); shorter when choppy.
    const expectedHoldingPeriod = Math.round(clamp(60 / (1 + vol / 20), 5, 120));

    const confidenceScore = clamp(upsideProbability * 0.6 + (100 - vol * 2) * 0.4, 0, 100);
    const volatilityExpectation = +vol.toFixed(2);
    const downsideMagnitude = Math.max(1, downsideProbability / 10);
    const rewardRiskRatio = expectedBase > 0 ? +(expectedBase / downsideMagnitude).toFixed(2) : 0;

    // Composite 0-100 normalized score.
    const normalizedScore = clamp(
      upsideProbability * 0.4 + clamp(expectedBase * 3, 0, 100) * 0.3 + confidenceScore * 0.2 + clamp(rewardRiskRatio * 20, 0, 100) * 0.1,
      0,
      100,
    );

    const recommendation = ProbabilityEngine.toRating(normalizedScore, downsideProbability);

    return {
      id: `probability-${row.symbol}`,
      timestamp: new Date().toISOString(),
      symbol: row.symbol,
      expectedReturn,
      upsideProbability: +upsideProbability.toFixed(1),
      downsideProbability: +downsideProbability.toFixed(1),
      expectedHoldingPeriod,
      confidenceScore: +confidenceScore.toFixed(1),
      volatilityExpectation,
      rewardRiskRatio,
      recommendation,
      normalizedScore: +normalizedScore.toFixed(1),
    };
  }

  private static toRating(score: number, downside: number): SignalRating {
    if (score >= 75 && downside < 45) return "strong_buy";
    if (score >= 60) return "buy";
    if (score >= 50) return "watch";
    if (score >= 42) return "neutral";
    if (score >= 30) return "weak";
    if (score >= 18) return "sell";
    return "avoid";
  }
}
