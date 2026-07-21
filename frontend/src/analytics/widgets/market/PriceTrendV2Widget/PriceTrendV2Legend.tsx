"use client";

import * as React from "react";
import { PERIOD_LABELS } from "./PriceTrendV2.columns";
import { getPeriodColor } from "./PriceTrendV2.utils";

export interface PriceTrendV2LegendProps {
  periods: string[];
}

export function PriceTrendV2Legend({ periods }: PriceTrendV2LegendProps) {
  if (!periods.length) return null;
  return (
    <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
      {periods.map((period) => (
        <span key={period} className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <span className="h-2.5 w-2.5 rounded-sm" style={{ backgroundColor: getPeriodColor(period as any) }} />
          {PERIOD_LABELS[period as keyof typeof PERIOD_LABELS] ?? period.toUpperCase()}
        </span>
      ))}
    </div>
  );
}
