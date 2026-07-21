import * as React from "react";
import { ReturnBar } from "@/analytics/widgets/market/PriceTrendWidget/ReturnBar";

export interface RelativeBarCellProps {
  value: number | null | undefined;
  label: string;
  maxAbs: number;
  row: {
    name: string;
    sector: string;
    industry: string;
    industrySubGroup: string;
    relative1W: number | null | undefined;
    relative1M: number | null | undefined;
    relative1Y: number | null | undefined;
  };
  metric: "relative1W" | "relative1M" | "relative1Y";
  onHover?: (payload: { x: number; y: number; content: React.ReactNode } | null) => void;
}

const METRIC_LABEL: Record<string, string> = {
  relative1W: "Relative (1 Week)",
  relative1M: "Relative (1 Month)",
  relative1Y: "Relative (1 Year)",
};

function barColor(v: number, maxAbs: number): string {
  if (!Number.isFinite(v) || !Number.isFinite(maxAbs) || maxAbs <= 0) return "#e2e8f0";
  if (v < 1) {
    const t = Math.min(1, (1 - v) / Math.max(0.01, maxAbs - 1));
    const r = Math.round(224 - 100 * t);
    const g = Math.round(242 - 80 * t);
    const b = Math.round(250 - 40 * t);
    return `rgb(${r}, ${g}, ${b})`;
  }
  const t = Math.min(1, (v - 1) / Math.max(0.01, maxAbs - 1));
  const r = Math.round(240 - 130 * t);
  const g = Math.round(253 - 90 * t);
  const b = Math.round(244 - 200 * t);
  return `rgb(${r}, ${g}, ${b})`;
}

export function RelativeBarCell({ value, label, maxAbs, row, metric, onHover }: RelativeBarCellProps) {
  const color = barColor(typeof value === "number" ? value : NaN, maxAbs);

  const handleEnter = (e: React.MouseEvent) => {
    if (!onHover) return;
    const metricLabel = METRIC_LABEL[metric] || metric;
    const rawValue = row[metric];
    const displayValue = typeof rawValue === "number" ? `${rawValue.toFixed(2)}×` : "—";
    onHover({
      x: e.clientX,
      y: e.clientY,
      content: (
        <div style={{ minWidth: 200 }}>
          <div style={{ fontWeight: 600, marginBottom: 4 }}>{row.name}</div>
          <div style={{ color: "#94a3b8", marginBottom: 6 }}>{row.sector} · {row.industry}</div>
          {(["relative1W", "relative1M", "relative1Y"] as const).map((m) => {
            const rv = row[m];
            const dv = typeof rv === "number" ? `${rv.toFixed(2)}×` : "—";
            return (
              <div key={m} style={{ display: "flex", justifyContent: "space-between", gap: 20, lineHeight: 1.6 }}>
                <span>{METRIC_LABEL[m]}</span>
                <span style={{ fontVariantNumeric: "tabular-nums" }}>{dv}</span>
              </div>
            );
          })}
        </div>
      ),
    });
  };

  const handleLeave = () => onHover?.(null);

  return (
    <div className="relative flex h-full w-full flex-row items-center" style={{ backgroundColor: color }} onMouseEnter={handleEnter} onMouseMove={handleEnter} onMouseLeave={handleLeave}>
      {label && (
        <span className="truncate pl-1.5  text-[11px] font-bold tabular-nums text-black">{label}</span>
      )}
    </div>
  );
}
