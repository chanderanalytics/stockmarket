import type { MarketRegime, MarketBreadth } from "../models/market";
import type { SectorSnapshot } from "../models/sectors";
import type { TradingSignal } from "../models/signals";
import type { DecisionSummary } from "../models/decision";
import type { RiskLevel } from "../models/common";
import { clamp } from "../indicators/calculators/_utils";

export interface DecisionInput {
  regime: MarketRegime;
  breadth: MarketBreadth;
  sectors: SectorSnapshot[];
  signals: TradingSignal[];
  watchlistSymbols?: string[];
}

const EXPOSURE_BY_REGIME: Record<MarketRegime["regime"], number> = {
  "Strong Bull": 90,
  Bull: 75,
  Recovering: 55,
  Sideways: 50,
  Weak: 30,
  Bear: 15,
  Correction: 10,
  "High Risk": 20,
  Capitulation: 25,
};

// DecisionEngine — the top of the stack: turns market intelligence into a plan.
export class DecisionEngine {
  static compute(input: DecisionInput): DecisionSummary {
    const { regime, breadth, sectors, signals } = input;

    const exposure = EXPOSURE_BY_REGIME[regime.regime];
    const cashAllocation = 100 - exposure;

    const marketQuality = clamp(
      breadth.marketParticipationScore * 0.4 + regime.confidenceScore * 0.3 + breadth.percentageAbove200DMA * 0.3,
      0,
      100,
    );

    const preferredSectors = sectors
      .filter((s) => s.leadership)
      .sort((a, b) => a.rank - b.rank)
      .slice(0, 3)
      .map((s) => s.sector);

    const actionable = signals.filter((s) => s.rating === "buy" || s.rating === "strong_buy");
    const watchlistActions = (input.watchlistSymbols ?? [])
      .map((sym) => signals.find((s) => s.symbol === sym))
      .filter((s): s is TradingSignal => Boolean(s))
      .map((s) => ({ symbol: s.symbol, action: s.rating }));

    const deployNewMoney = exposure >= 50 && marketQuality >= 50;

    const overallRisk: RiskLevel = marketQuality >= 60 ? "low" : marketQuality >= 40 ? "medium" : "high";

    const thesis: string[] = [
      `Regime is ${regime.regime} (confidence ${regime.confidence}).`,
      `Market quality ${Math.round(marketQuality)}/100 with ${Math.round(breadth.marketParticipationScore)}% participation.`,
      preferredSectors.length
        ? `Leadership in ${preferredSectors.join(", ")}.`
        : "No clear sector leadership — stay selective.",
      `${actionable.length} actionable buy signals identified.`,
    ];

    const summary =
      deployNewMoney
        ? `Constructive environment: deploy gradually toward ${exposure}% exposure, keep ${cashAllocation}% cash.`
        : `Defensive stance: hold ${cashAllocation}% cash, deploy only on confirmation.`;

    return {
      id: "decision-summary",
      timestamp: new Date().toISOString(),
      deployNewMoney,
      recommendedExposure: exposure,
      cashAllocation,
      preferredSectors,
      watchlistActions,
      overallRisk,
      opportunityCount: actionable.length,
      marketQuality: +marketQuality.toFixed(1),
      summary,
      thesis,
    };
  }
}
