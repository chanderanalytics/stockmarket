import * as React from "react";
import { ArrowDownRight, ArrowUpRight } from "lucide-react";
import { cn } from "@/lib/utils";

export interface TrendChipProps {
  value: number;
  suffix?: string;
  showIcon?: boolean;
  className?: string;
  /** Invert coloring (e.g. for a metric where down is good). */
  invert?: boolean;
}

export function TrendChip({ value, suffix = "%", showIcon = true, className, invert = false }: TrendChipProps) {
  const positive = value >= 0;
  const good = invert ? !positive : positive;
  return (
    <span
      className={cn(
        "inline-flex items-center gap-0.5 rounded-md px-1.5 py-0.5 text-xs font-medium tabular-nums",
        good ? "bg-success/10 text-success" : "bg-destructive/10 text-destructive",
        className
      )}
    >
      {showIcon && (positive ? <ArrowUpRight className="h-3 w-3" /> : <ArrowDownRight className="h-3 w-3" />)}
      {positive ? "+" : ""}
      {value.toFixed(2)}
      {suffix}
    </span>
  );
}
