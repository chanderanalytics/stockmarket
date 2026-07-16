import * as React from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { cn } from "@/lib/utils";

export interface PanelProps {
  title?: React.ReactNode;
  description?: React.ReactNode;
  actions?: React.ReactNode;
  footer?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
  contentClassName?: string;
  noPadding?: boolean;
}

/** A titled, bordered container used to group related dashboard content. */
export function Panel({ title, description, actions, footer, children, className, contentClassName, noPadding }: PanelProps) {
  return (
    <Card className={cn("flex flex-col", className)}>
      {(title || actions) && (
        <CardHeader className="flex flex-row items-start justify-between space-y-0 pb-3">
          <div className="space-y-1">
            {title && <CardTitle className="text-base">{title}</CardTitle>}
            {description && <CardDescription>{description}</CardDescription>}
          </div>
          {actions && <div className="flex items-center gap-2">{actions}</div>}
        </CardHeader>
      )}
      <CardContent className={cn(noPadding ? "p-0" : "pt-0", contentClassName)}>{children}</CardContent>
      {footer && (
        <>
          <Separator />
          <div className="p-4 text-sm text-muted-foreground">{footer}</div>
        </>
      )}
    </Card>
  );
}
