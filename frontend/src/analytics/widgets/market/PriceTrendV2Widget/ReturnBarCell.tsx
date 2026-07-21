import * as React from "react";
import { ReturnBar } from "./ReturnBar";
import type { PeriodScale } from "./calculatePeriodScales";
import type { PriceTrendV2GridRow } from "./buildRows";
import type { PriceTrendV2Period } from "./PriceTrendV2.types";

export interface ReturnBarCellProps {
  row: PriceTrendV2GridRow;
  period: PriceTrendV2Period;
  scale: PeriodScale;
  onHover?: (payload: TooltipPayload | null) => void;
}

export interface TooltipPayload {
  company: string;
  period: string;
  periodKey: PriceTrendV2Period;
  value: string;
  rank: string;
  x: number;
  y: number;
}

export function ReturnBarCell({ row, period, scale, onHover }: ReturnBarCellProps) {
  const value = row.values.get(period) ?? NaN;
  const normalized = Number.isFinite(value) ? value / scale.maxAbs : NaN;
  const formatted = row.formatted.get(period) ?? "—";
  const rank = scale.ranks[row.index] ?? NaN;
  const isMissing = !Number.isFinite(value);

  const roundedLabel = isMissing ? "" : `${value >= 0 ? "+" : ""}${Math.round(value)}%`;
  const tooltipValue = formatted;

  const barColor = (v: number): string => {
    if (!Number.isFinite(v)) return "#cbd5e1";
    const extent = scale.maxAbs || 1;
    const t = Math.min(1, Math.abs(v) / extent);
    if (v >= 0) {
      const r = Math.round(235 - 235 * t);
      const g = Math.round(250 - 190 * t);
      const b = Math.round(240 - 240 * t);
      return `rgb(${r}, ${g}, ${b})`;
    }
    const r = Math.round(255 - 115 * t);
    const g = Math.round(235 - 235 * t);
    const b = Math.round(235 - 235 * t);
    return `rgb(${r}, ${g}, ${b})`;
  };
  const cellColor = barColor(value);

  const handleEnter = (e: React.MouseEvent) => {
    if (!onHover) return;
    onHover({
      company: row.name,
      period: period,
      periodKey: period,
      value: tooltipValue,
      rank: isMissing ? "—" : `#${rank}`,
      x: e.clientX,
      y: e.clientY,
    });
  };

  return (
    <div
      className="flex h-full w-full items-center"
      onMouseEnter={handleEnter}
      onMouseMove={handleEnter}
      onMouseLeave={() => onHover?.(null)}
    >
      <ReturnBar normalized={normalized} label={roundedLabel} color={cellColor} />
    </div>
  );
}
