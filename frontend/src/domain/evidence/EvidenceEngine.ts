import type { Evidence } from "./Evidence";
import { EvidenceBuilder } from "./EvidenceBuilder";
import type { MarketBreadth } from "../models/market";
import type { ProbabilityAnalysis } from "../models/probability";
import type { SectorSnapshot } from "../models/sectors";
import type { TradingSignal } from "../models/signals";

export interface EvidenceInput {
  breadth?: MarketBreadth;
  probability?: ProbabilityAnalysis[];
  sectors?: SectorSnapshot[];
  signals: TradingSignal[];
  volumeTrend?: number; // -1..1
}

// EvidenceEngine — turns indicator/breadth/probability/sector/signal outputs
// into a flat, explainable list of Evidence. Pure and deterministic.
export class EvidenceEngine {
  static compute(input: EvidenceInput): Evidence[] {
    const out: Evidence[] = [];

    if (input.breadth) {
      const b = input.breadth;
      const participation = b.marketParticipationScore;
      out.push(
        EvidenceBuilder.fromMetric({
          id: "ev-breadth-participation",
          metric: "Breadth",
          observation:
            participation >= 55
              ? "Broad participation; majority of stocks trending up"
              : participation <= 40
                ? "Narrow participation; weak internal strength"
                : "Mixed participation",
          weight: (participation - 50) / 50,
          confidence: Math.round(60 + Math.abs(participation - 50) * 0.4),
          reason: `${Math.round(participation)}% of stocks remain above key moving averages.`,
          importance: Math.round(participation),
          supportingData: { participationAbove50DMA: +b.percentageAbove50DMA.toFixed(1) },
        }),
      );
      out.push(
        EvidenceBuilder.fromMetric({
          id: "ev-breadth-adline",
          metric: "Advance/Decline",
          observation: b.netAdvances >= 0 ? "Advancers leading decliners" : "Decliners leading advancers",
          weight: Math.max(-1, Math.min(1, b.netAdvances / 20)),
          confidence: 80,
          reason: `Net advances of ${b.netAdvances} indicate ${b.breadthTrend} breadth.`,
          importance: 70,
        }),
      );
    }

    if (input.probability) {
      for (const p of input.probability) {
        out.push(
          EvidenceBuilder.fromMetric({
            id: `ev-prob-${p.symbol}`,
            metric: "Probability Model",
            observation: `Model favours ${p.upsideProbability}% upside over ${p.downsideProbability}% downside`,
            weight: (p.upsideProbability - p.downsideProbability) / 100,
            confidence: Math.round(p.confidenceScore),
            reason: `Expected return scenarios imply a reward/risk of ${p.rewardRiskRatio}.`,
            importance: Math.round(p.normalizedScore),
            supportingData: { upside: p.upsideProbability, downside: p.downsideProbability },
          }),
        );
      }
    }

    if (input.sectors) {
      for (const s of input.sectors.filter((x) => x.leadership)) {
        out.push(
          EvidenceBuilder.fromMetric({
            id: `ev-sector-${s.sector}`,
            metric: "Sector",
            observation: `${s.sector} is a leadership sector (rank #${s.rank})`,
            weight: (s.relativeStrength - 50) / 50,
            confidence: Math.round(s.relativeStrength),
            reason: `Relative strength ${s.relativeStrength} with ${Math.round(s.participation)}% participation.`,
            importance: Math.round(s.relativeStrength),
          }),
        );
      }
    }

    for (const sig of input.signals) {
      for (const se of sig.evidence) {
        out.push(EvidenceBuilder.fromSignalEvidence(se, sig.symbol));
      }
    }

    return out;
  }
}
