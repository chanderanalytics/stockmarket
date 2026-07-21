import * as React from "react";
import type { BreadthSummary } from "./types";

interface MarketHealthCardsProps {
  summary?: BreadthSummary;
  isLoading: boolean;
}

const CARD_CLASS = "flex flex-col gap-1 rounded-md border border-border p-3";

export function MarketHealthCards({ summary, isLoading }: MarketHealthCardsProps) {
  if (isLoading || !summary) {
    return (
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
        {Array.from({ length: 7 }).map((_, i) => (
          <div key={i} className={CARD_CLASS}>
            <div className="h-3 w-20 animate-pulse rounded bg-muted" />
            <div className="h-5 w-12 animate-pulse rounded bg-muted" />
          </div>
        ))}
      </div>
    );
  }

  const cards = [
    { label: "Total Companies", value: summary.totalCompanies.toLocaleString() },
    { label: "Composite Breadth", value: `${summary.compositeBreadth.toFixed(1)}%` },
    { label: "Trend Strength", value: `${summary.trendStrength.toFixed(1)}` },
    { label: "A/D Ratio", value: summary.advanceDeclineRatio.toFixed(2) },
    { label: "New High/Low %", value: `${summary.newHighPct.toFixed(1)}% / ${summary.newLowPct.toFixed(1)}%` },
    { label: "Relative Volume", value: `${summary.relativeVolume.toFixed(2)}x` },
    { label: "Weighted Return", value: `${summary.weightedReturn.toFixed(2)}%` },
  ];

  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
      {cards.map((card) => (
        <div key={card.label} className={CARD_CLASS}>
          <span className="text-[11px] font-medium uppercase text-muted-foreground">{card.label}</span>
          <span className="text-lg font-semibold">{card.value}</span>
        </div>
      ))}
    </div>
  );
}
