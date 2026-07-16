"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { navItems } from "./nav-items";

// Desktop sidebar navigation. Highlights the active route.
export function AppSidebar({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();
  return (
    <nav className="flex h-full flex-col gap-1 p-3">
      <Link href="/" className="mb-4 flex items-center gap-2 px-2 py-2">
        <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-primary-foreground font-bold">
          S
        </span>
        <span className="text-base font-semibold tracking-tight">StockMkt</span>
      </Link>
      {navItems.map((item) => {
        const active = pathname === item.href || pathname.startsWith(item.href + "/");
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            onClick={onNavigate}
            className={cn(
              "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
              active ? "bg-primary/10 text-primary" : "text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            <Icon className="h-4 w-4" />
            <span>{item.title}</span>
            {item.badge && (
              <span className="ml-auto rounded-full bg-primary px-1.5 text-[10px] text-primary-foreground">{item.badge}</span>
            )}
          </Link>
        );
      })}
    </nav>
  );
}
