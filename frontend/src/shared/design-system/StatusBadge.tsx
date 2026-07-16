import * as React from "react";
import { Badge, type BadgeProps } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

export type StatusTone = "success" | "warning" | "destructive" | "neutral" | "info";

const toneMap: Record<StatusTone, BadgeProps["variant"]> = {
  success: "success",
  warning: "warning",
  destructive: "destructive",
  neutral: "secondary",
  info: "default",
};

const dotColor: Record<StatusTone, string> = {
  success: "bg-success",
  warning: "bg-warning",
  destructive: "bg-destructive",
  neutral: "bg-muted-foreground",
  info: "bg-primary",
};

export interface StatusBadgeProps {
  status: StatusTone;
  children: React.ReactNode;
  dot?: boolean;
  className?: string;
}

export function StatusBadge({ status, children, dot = true, className }: StatusBadgeProps) {
  return (
    <Badge variant={toneMap[status]} className={cn("gap-1.5", className)}>
      {dot && <span className={cn("h-1.5 w-1.5 rounded-full", dotColor[status])} />}
      {children}
    </Badge>
  );
}
