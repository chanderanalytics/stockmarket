import * as React from "react";
import { cn } from "@/lib/utils";
import { Card } from "@/components/ui/card";

// ChartCard wraps a chart body with a titled, padded card surface.
export function ChartCard({
  title,
  action,
  className,
  children,
}: {
  title?: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <Card className={cn("p-4", className)}>
      {(title || action) && (
        <div className="mb-3 flex items-center justify-between">
          <h3 className="text-sm font-medium">{title}</h3>
          {action}
        </div>
      )}
      {children}
    </Card>
  );
}
