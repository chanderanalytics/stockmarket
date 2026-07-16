import type { IndicatorOutput } from "../indicators/types";
import type { ProbabilityAnalysis } from "../models/probability";
import type { SectorSnapshot } from "../models/sectors";
import type { MarketBreadth } from "../models/market";
import type { TradingSignal, SignalRating, SignalEvidence } from "../models/signals";
import { clamp } from "../indicators/calculators/_utils";

export interface SignalInput {
  symbol: string;
  indicators: IndicatorOutput[];
  probability?: ProbabilityAnalysis;
  sector?: SectorSnapshot;
  breadth?: MarketBreadth;
  priceChangePercent: number;
  volatility: number; // annualized %
}

const RATING_THRESHOLDS: { min: number; rating: SignalRating }[] = [
  { min: 78, rating: "strong_buy" },
  { min: 62, rating: "buy" },
  { min: 52, rating: "watch" },
  { min: 44, rating: "neutral" },
  { min: 32, rating: "weak" },
  { min: 18, rating: "sell" },
  { min: 0, rating: "avoid" },
];

function ratingFromScore(score: number): SignalRating {
  return (RATING_THRESHOLDS.find((t) => score >= t.min) ?? RATING_THRESHOLDS[RATING_THRESHOLDS.length - 1]).rating;
}

// SignalEngine — combines every input into a single actionable TradingSignal.
export class SignalEngine {
  static compute(input: SignalInput): TradingSignal {
    const evidence: SignalEvidence[] = [];
    let bull = 0;
    let bear = 0;
    let agree = 0;
    let total = 0;

    for (const ind of input.indicators) {
      const w = (ind.signal === "buy" ? 1 : ind.signal === "sell" ? -1 : 0) * (0.5 + ind.strength / 100);
      if (ind.signal === "buy") {
        bull += w;
        agree++;
      } else if (ind.signal === "sell") {
        bear += Math.abs(w);
        agree++;
      }
      total++;
      evidence.push({
        label: ind.name.toUpperCase(),
        detail: `${ind.signal} · strength ${Math.round(ind.strength)}`,
        weight: +w.toFixed(2),
      });
    }

    // Probability contribution (0-100 => -50..+50).
    if (input.probability) {
      const p = input.probability.normalizedScore;
      const w = (p - 50) / 2;
      evidence.push({
        label: "PROBABILITY MODEL",
        detail: `score ${p} · upside ${input.probability.upsideProbability}%`,
        weight: +w.toFixed(2),
      });
      if (w >= 0) bull += w;
      else bear += Math.abs(w);
    }

    // Sector relative strength (0-100 => -50..+50).
    if (input.sector) {
      const w = (input.sector.relativeStrength - 50) / 2;
      evidence.push({
        label: "SECTOR",
        detail: `${input.sector.sector} rank #${input.sector.rank} · RS ${input.sector.relativeStrength}`,
        weight: +w.toFixed(2),
      });
      if (w >= 0) bull += w;
      else bear += Math.abs(w);
    }

    // Market breadth participation.
    if (input.breadth) {
      const w = (input.breadth.marketParticipationScore - 50) / 4;
      evidence.push({
        label: "MARKET BREADTH",
        detail: `participation ${Math.round(input.breadth.marketParticipationScore)}% · A/D ${input.breadth.netAdvances}`,
        weight: +w.toFixed(2),
      });
      if (w >= 0) bull += w;
      else bear += Math.abs(w);
    }

    const totalScore = bull - bear; // roughly -100..100
    const scoreNorm = clamp(50 + totalScore / 2, 0, 100);
    const rating = ratingFromScore(scoreNorm);

    const agreement = total === 0 ? 0 : agree / total;
    const probConf = input.probability?.confidenceScore ?? 50;
    const confidenceScore = clamp(agreement * 60 + probConf * 0.4, 0, 100);
    const confidence: TradingSignal["confidence"] =
      confidenceScore >= 66 ? "high" : confidenceScore >= 40 ? "medium" : "low";

    const downside = input.probability?.downsideProbability ?? 50;
    const riskScore = clamp(input.volatility * 1.5 + downside * 0.3, 0, 100);
    const risk: TradingSignal["risk"] = riskScore >= 66 ? "high" : riskScore >= 40 ? "medium" : "low";

    const reason = SignalEngine.buildReason(rating, scoreNorm, input);

    return {
      id: `signal-${input.symbol}`,
      timestamp: new Date().toISOString(),
      symbol: input.symbol,
      rating,
      confidence,
      confidenceScore: +confidenceScore.toFixed(1),
      risk,
      riskScore: +riskScore.toFixed(1),
      reason,
      evidence,
    };
  }

  private static buildReason(rating: SignalRating, score: number, input: SignalInput): string {
    const dir = rating.includes("buy") ? "bullish" : rating.includes("sell") || rating === "avoid" ? "bearish" : "neutral";
    const parts: string[] = [];
    parts.push(`Composite score ${Math.round(score)}/100 (${dir}).`);
    if (input.probability) parts.push(`Probability model favours ${input.probability.upsideProbability}% upside.`);
    if (input.sector) parts.push(`Sector ${input.sector.sector} ranks #${input.sector.rank} in leadership.`);
    if (input.breadth) parts.push(`Market participation at ${Math.round(input.breadth.marketParticipationScore)}%.`);
    return parts.join(" ");
  }
}
