import * as React from "react";
import Link from "next/link";
import { cn } from "@/lib/utils";

export interface ListItem {
  id: string;
  title: React.ReactNode;
  description?: React.ReactNode;
  trailing?: React.ReactNode;
  avatar?: React.ReactNode;
  href?: string;
}

// Generic content list (news, watchlist summaries, activity, etc.).
export function List({
  items,
  className,
}: {
  items: ListItem[];
  className?: string;
}) {
  if (items.length === 0) {
    return <p className="py-6 text-center text-sm text-muted-foreground">Nothing here yet.</p>;
  }
  return (
    <ul className={cn("divide-y divide-border rounded-md border border-border bg-card", className)}>
      {items.map((item) => {
        const body = (
          <div className="flex items-center gap-3 px-3 py-2.5">
            {item.avatar && <span className="shrink-0">{item.avatar}</span>}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-foreground">{item.title}</p>
              {item.description && <p className="truncate text-xs text-muted-foreground">{item.description}</p>}
            </div>
            {item.trailing && <span className="shrink-0 text-sm text-muted-foreground">{item.trailing}</span>}
          </div>
        );
        return (
          <li key={item.id}>
            {item.href ? (
              <Link href={item.href} className="block transition-colors hover:bg-muted/40">
                {body}
              </Link>
            ) : (
              body
            )}
          </li>
        );
      })}
    </ul>
  );
}
