import * as React from "react";
import { cn } from "@/lib/utils";

export interface TimelineItem {
  id: string;
  title: React.ReactNode;
  description?: React.ReactNode;
  time?: React.ReactNode;
  icon?: React.ReactNode;
}

// Vertical timeline / activity feed.
export function Timeline({ items, className }: { items: TimelineItem[]; className?: string }) {
  return (
    <ol className={cn("relative space-y-4", className)}>
      {items.map((item) => (
        <li key={item.id} className="flex gap-3">
          <div className="mt-1 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-muted text-muted-foreground">
            {item.icon ?? <span className="h-1.5 w-1.5 rounded-full bg-primary" />}
          </div>
          <div className="min-w-0 flex-1 pb-4">
            <div className="flex items-center justify-between gap-2">
              <p className="text-sm font-medium text-foreground">{item.title}</p>
              {item.time && <span className="text-xs text-muted-foreground">{item.time}</span>}
            </div>
            {item.description && <p className="text-xs text-muted-foreground">{item.description}</p>}
          </div>
        </li>
      ))}
    </ol>
  );
}
