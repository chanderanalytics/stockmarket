"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronRight, Home } from "lucide-react";
import { findNavItem } from "./nav-config";
import { cn } from "@/lib/utils";

// Derives breadcrumbs from the current path + nav config.
export function Breadcrumbs() {
  const pathname = usePathname();
  const segments = pathname.split("/").filter(Boolean);

  const crumbs: { label: string; href: string }[] = [];
  let acc = "";
  for (const seg of segments) {
    acc += `/${seg}`;
    const item = findNavItem(acc);
    crumbs.push({ label: item?.title ?? seg.replace(/-/g, " ").replace(/^\w/, (c) => c.toUpperCase()), href: acc });
  }

  return (
    <nav aria-label="Breadcrumb" className="flex items-center gap-1 text-sm text-muted-foreground">
      <Link href="/market-pulse" className="flex items-center hover:text-foreground">
        <Home className="h-3.5 w-3.5" />
      </Link>
      {crumbs.map((c, i) => (
        <React.Fragment key={c.href}>
          <ChevronRight className="h-3.5 w-3.5" />
          <Link
            href={c.href}
            className={cn(
              "hover:text-foreground",
              i === crumbs.length - 1 && "font-medium text-foreground"
            )}
          >
            {c.label}
          </Link>
        </React.Fragment>
      ))}
    </nav>
  );
}
