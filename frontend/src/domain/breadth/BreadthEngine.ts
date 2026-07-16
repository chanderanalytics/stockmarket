import type { MarketBreadth } from "../models/market";
import type { BreadthInput, BreadthMember } from "./types";
import { clamp } from "../indicators/calculators/_utils";

function pct(n: number, d: number): number {
  return d === 0 ? 0 : (n / d) * 100;
}

// BreadthEngine — centralizes every market-breadth calculation.
export class BreadthEngine {
  static compute(input: BreadthInput): MarketBreadth {
    const members = input.members;
    const total = members.length || 1;

    let advances = 0;
    let declines = 0;
    let unchanged = 0;
    let above20 = 0;
    let above50 = 0;
    let above100 = 0;
    let above200 = 0;
    let newHighs = 0;
    let newLows = 0;

    for (const m of members) {
      if (m.close > m.prevClose) advances++;
      else if (m.close < m.prevClose) declines++;
      else unchanged++;
      if (m.close > m.ma20) above20++;
      if (m.close > m.ma50) above50++;
      if (m.close > m.ma100) above100++;
      if (m.close > m.ma200) above200++;
      if (m.isNewHigh) newHighs++;
      if (m.isNewLow) newLows++;
    }

    const netAdvances = advances - declines;
    const advanceDeclineRatio = declines === 0 ? advances : advances / declines;
    const advanceDeclineLine = members.reduce((acc, m) => acc + (m.close > m.prevClose ? 1 : m.close < m.prevClose ? -1 : 0), 0);
    const highLowRatio = newLows === 0 ? newHighs : newHighs / newLows;

    const pctAbove20 = pct(above20, total);
    const pctAbove50 = pct(above50, total);
    const pctAbove100 = pct(above100, total);
    const pctAbove200 = pct(above200, total);

    // Participation score: composite of how many names are above key MAs and
    // the balance of advancing vs declining issues.
    const participation =
      pctAbove20 * 0.2 + pctAbove50 * 0.3 + pctAbove100 * 0.2 + pctAbove200 * 0.3;
    const netRatio = clamp(((netAdvances / total) + 1) * 50, 0, 100); // -1..1 -> 0..100
    const marketParticipationScore = clamp(participation * 0.7 + netRatio * 0.3, 0, 100);

    // Breadth thrust: share of names above BOTH 20 & 50 DMA (thrust proxy).
    const thrustCount = members.filter((m) => m.close > m.ma20 && m.close > m.ma50).length;
    const breadthThrust = pct(thrustCount, total);

    const breadthMomentumStrength =
      input.priorNetAdvances !== undefined
        ? clamp(((netAdvances - input.priorNetAdvances) / total) * 200 + 50, 0, 100)
        : clamp(netRatio, 0, 100);

    const trend: MarketBreadth["breadthTrend"] =
      pctAbove50 > 50 && netAdvances > 0 ? "up" : pctAbove50 < 50 && netAdvances < 0 ? "down" : "sideways";

    const trendConfirmation = pctAbove50 > 50 && pctAbove200 > 50;

    return {
      id: "market-breadth",
      timestamp: new Date().toISOString(),
      advanceDeclineRatio,
      advanceDeclineLine,
      netAdvances,
      percentageAbove20DMA: pctAbove20,
      percentageAbove50DMA: pctAbove50,
      percentageAbove100DMA: pctAbove100,
      percentageAbove200DMA: pctAbove200,
      newHighs,
      newLows,
      highLowRatio,
      breadthMomentum: netAdvances > 0 ? "strong" : netAdvances < 0 ? "weak" : "moderate",
      breadthTrend: trend,
      breadthThrust,
      marketParticipationScore,
      trendConfirmation,
    };
  }
}
