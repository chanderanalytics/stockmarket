import * as React from "react";
import Link from "next/link";
import { cn } from "@/lib/utils";

export interface NavLink {
  label: React.ReactNode;
  href: string;
  active?: boolean;
}

// Generic top navbar (marketing / standalone pages).
export function Navbar({
  brand,
  links = [],
  actions,
  className,
}: {
  brand?: React.ReactNode;
  links?: NavLink[];
  actions?: React.ReactNode;
  className?: string;
}) {
  return (
    <header className={cn("flex h-14 items-center gap-4 border-b border-border bg-background px-4", className)}>
      {brand && <div className="font-semibold tracking-tight">{brand}</div>}
      <nav className="flex items-center gap-1">
        {links.map((l) => (
          <Link
            key={l.href}
            href={l.href}
            className={cn(
              "rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
              l.active ? "bg-muted text-foreground" : "text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            {l.label}
          </Link>
        ))}
      </nav>
      {actions && <div className="ml-auto flex items-center gap-2">{actions}</div>}
    </header>
  );
}
