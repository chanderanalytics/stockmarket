import * as React from "react";
import { cn } from "@/lib/utils";
import { Card } from "@/components/ui/card";
import { TrendingUp, TrendingDown } from "lucide-react";

// KPI / metric card with optional trend indicator and icon.
export function StatCard({
  title,
  value,
  icon,
  trend,
  trendUp,
  hint,
  className,
}: {
  title: React.ReactNode;
  value: React.ReactNode;
  icon?: React.ReactNode;
  trend?: string;
  trendUp?: boolean;
  hint?: React.ReactNode;
  className?: string;
}) {
  return (
    <Card className={cn("p-4", className)}>
      <div className="flex items-center justify-between">
        <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{title}</p>
        {icon && <span className="text-muted-foreground">{icon}</span>}
      </div>
      <div className="mt-2 text-2xl font-semibold tabular-nums">{value}</div>
      <div className="mt-1 flex items-center gap-1 text-xs">
        {trend && (
          <span className={cn("inline-flex items-center gap-0.5 font-medium", trendUp ? "text-success" : "text-destructive")}>
            {trendUp ? <TrendingUp className="h-3 w-3" /> : <TrendingDown className="h-3 w-3" />}
            {trend}
          </span>
        )}
        {hint && <span className="text-muted-foreground">{hint}</span>}
      </div>
    </Card>
  );
}
