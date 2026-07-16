import * as React from "react";
import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

export interface Crumb {
  label: React.ReactNode;
  href?: string;
}

// Breadcrumb trail. The last item is rendered as the current page (no link).
export function Breadcrumbs({ items, className }: { items: Crumb[]; className?: string }) {
  return (
    <nav aria-label="Breadcrumb" className={cn("flex items-center gap-1 text-sm text-muted-foreground", className)}>
      {items.map((item, i) => {
        const last = i === items.length - 1;
        return (
          <React.Fragment key={i}>
            {item.href && !last ? (
              <Link href={item.href} className="hover:text-foreground">
                {item.label}
              </Link>
            ) : (
              <span className={cn(last && "font-medium text-foreground")}>{item.label}</span>
            )}
            {!last && <ChevronRight className="h-3.5 w-3.5 opacity-60" />}
          </React.Fragment>
        );
      })}
    </nav>
  );
}
