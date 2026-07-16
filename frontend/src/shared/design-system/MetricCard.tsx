import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { Skeleton } from "@/components/ui/skeleton";

const valueVariants = cva("font-semibold tabular-nums tracking-tight", {
  variants: {
    size: {
      sm: "text-xl",
      md: "text-2xl",
      lg: "text-3xl",
    },
  },
  defaultVariants: { size: "md" },
});

export interface MetricCardProps extends VariantProps<typeof valueVariants> {
  label: string;
  value: React.ReactNode;
  description?: React.ReactNode;
  icon?: React.ReactNode;
  trend?: { value: number; label?: string } | null;
  loading?: boolean;
  className?: string;
  footer?: React.ReactNode;
}

export function MetricCard({
  label,
  value,
  description,
  icon,
  trend,
  loading,
  size,
  className,
  footer,
}: MetricCardProps) {
  if (loading) {
    return (
      <Card className={cn("p-5", className)}>
        <Skeleton className="h-4 w-24" />
        <Skeleton className="mt-3 h-8 w-32" />
        <Skeleton className="mt-3 h-3 w-20" />
      </Card>
    );
  }

  const trendPositive = (trend?.value ?? 0) >= 0;

  return (
    <Card className={cn("p-5", className)}>
      <div className="flex items-start justify-between">
        <p className="text-sm font-medium text-muted-foreground">{label}</p>
        {icon && <span className="text-muted-foreground">{icon}</span>}
      </div>
      <div className={cn(valueVariants({ size }), "mt-2")}>{value}</div>
      <div className="mt-1 flex items-center gap-2 text-xs">
        {trend && (
          <span className={trendPositive ? "text-success" : "text-destructive"}>
            {trendPositive ? "▲" : "▼"} {Math.abs(trend.value).toFixed(2)}%
            {trend.label ? ` ${trend.label}` : ""}
          </span>
        )}
        {description && !trend && <span className="text-muted-foreground">{description}</span>}
      </div>
      {footer && <div className="mt-3 border-t border-border pt-3">{footer}</div>}
    </Card>
  );
}
