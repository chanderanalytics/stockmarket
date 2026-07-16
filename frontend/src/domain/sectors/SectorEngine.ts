import type { SectorSnapshot } from "../models/sectors";
import type { SectorEngineInput, SectorMember } from "./types";
import { clamp } from "../indicators/calculators/_utils";

interface SectorAgg {
  sector: string;
  members: SectorMember[];
  performance1D: number;
  performance1W: number;
  performance1M: number;
  performance3M: number;
  performanceYTD: number;
  relativeStrength: number;
  participation: number;
  volume: number;
  momentum: number;
}

// SectorEngine — determines sector leadership, rotation and ranking.
export class SectorEngine {
  static compute(input: SectorEngineInput): SectorSnapshot[] {
    const bySector = new Map<string, SectorMember[]>();
    for (const m of input.members) {
      const arr = bySector.get(m.sector) ?? [];
      arr.push(m);
      bySector.set(m.sector, arr);
    }

    const aggs: SectorAgg[] = [];
    for (const [sector, members] of bySector) {
      const n = members.length || 1;
      const avg = (f: (m: SectorMember) => number) => members.reduce((s, m) => s + f(m), 0) / n;
      const advancing = members.filter((m) => m.advancing).length;
      aggs.push({
        sector,
        members,
        performance1D: avg((m) => m.return1D),
        performance1W: avg((m) => m.return1W),
        performance1M: avg((m) => m.return1M),
        performance3M: avg((m) => m.return3M),
        performanceYTD: avg((m) => m.returnYTD),
        relativeStrength: avg((m) => m.relativeStrength),
        participation: (advancing / n) * 100,
        volume: members.reduce((s, m) => s + m.volume, 0),
        momentum: avg((m) => m.return1M) * 0.6 + avg((m) => m.return3M) * 0.4,
      });
    }

    // Rank sectors by composite score (momentum + relative strength + participation).
    const scored = aggs.map((a) => ({
      a,
      score: a.momentum * 0.45 + (a.relativeStrength - 50) * 0.35 + (a.participation - 50) * 0.2,
    }));
    scored.sort((x, y) => y.score - x.score);
    const rankOf = new Map(scored.map((s, i) => [s.a.sector, i + 1]));

    const top = scored.slice(0, 3).map((s) => s.a.sector);
    const leaders = top;
    const laggards = scored.slice(-3).map((s) => s.a.sector);

    return aggs.map((a) => {
      const rank = rankOf.get(a.sector)!;
      const isLeader = leaders.includes(a.sector);
      const isLaggard = laggards.includes(a.sector);
      const strength = clamp(50 + a.momentum * 1.5, 0, 100);
      const trend = a.momentum > 1 ? "up" : a.momentum < -1 ? "down" : "sideways";
      const sorted = [...a.members].sort((x, y) => y.return1M - x.return1M);
      return {
        id: `sector-${a.sector}`,
        timestamp: new Date().toISOString(),
        sector: a.sector,
        performance1D: +a.performance1D.toFixed(2),
        performance1W: +a.performance1W.toFixed(2),
        performance1M: +a.performance1M.toFixed(2),
        performance3M: +a.performance3M.toFixed(2),
        performanceYTD: +a.performanceYTD.toFixed(2),
        relativeStrength: +a.relativeStrength.toFixed(1),
        momentum: +a.momentum.toFixed(2),
        participation: +a.participation.toFixed(1),
        volume: a.volume,
        leadership: isLeader,
        improving: a.momentum > 0 && a.relativeStrength > 50,
        weakening: a.momentum < 0 && a.relativeStrength < 50,
        rank,
        trend,
        strength: strength > 66 ? "strong" : strength < 33 ? "weak" : "moderate",
        topStocks: sorted.slice(0, 3).map((m) => m.symbol),
        bottomStocks: sorted.slice(-3).map((m) => m.symbol),
      } as SectorSnapshot;
    });
  }

  // Rotation signal derived from current leaders vs a prior leader set.
  static rotation(current: SectorSnapshot[], priorLeaders: string[]): {
    leaders: string[];
    laggards: string[];
    rotatingTo: string[];
    rotatingFrom: string[];
    rotationSignal: "risk_on" | "risk_off" | "neutral";
  } {
    const leaders = current.filter((s) => s.leadership).map((s) => s.sector);
    const laggards = current
      .slice()
      .sort((a, b) => b.rank - a.rank)
      .slice(-3)
      .map((s) => s.sector);
    const rotatingTo = leaders.filter((s) => !priorLeaders.includes(s));
    const rotatingFrom = priorLeaders.filter((s) => !leaders.includes(s));
    const riskOn = leaders.some((s) => ["Technology", "Consumer", "Financials"].includes(s));
    const rotationSignal: "risk_on" | "risk_off" | "neutral" = rotatingTo.length > rotatingFrom.length ? (riskOn ? "risk_on" : "neutral") : rotatingFrom.length > rotatingTo.length ? "risk_off" : "neutral";
    return { leaders, laggards, rotatingTo, rotatingFrom, rotationSignal };
  }
}
