"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronLeft, Star } from "lucide-react";
import { navGroups } from "./nav-config";
import { useUiStore } from "@/state/ui-store";
import { usePreferencesStore } from "@/state/preferences-store";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

export function Sidebar() {
  const pathname = usePathname();
  const collapsed = useUiStore((s) => s.sidebarCollapsed);
  const toggleSidebar = useUiStore((s) => s.toggleSidebar);
  const favorites = usePreferencesStore((s) => s.favorites);
  const toggleFavorite = usePreferencesStore((s) => s.toggleFavorite);

  return (
    <TooltipProvider delayDuration={0}>
      <aside
        className={cn(
          "flex h-full flex-col border-r border-sidebar-border bg-sidebar text-sidebar-foreground transition-[width] duration-200",
          collapsed ? "w-[68px]" : "w-64"
        )}
      >
        <div className={cn("flex h-14 items-center border-b border-sidebar-border px-4", collapsed && "justify-center px-0")}>
          <Link href="/market-pulse" className="flex items-center gap-2 font-semibold">
            <span className="flex h-7 w-7 items-center justify-center rounded-md bg-primary text-primary-foreground text-sm font-bold">
              S
            </span>
            {!collapsed && <span className="text-sm">StockIntel</span>}
          </Link>
        </div>

        <nav className="flex-1 space-y-4 overflow-y-auto scrollbar-thin p-3">
          {favorites.length > 0 && !collapsed && (
            <div>
              <p className="px-2 pb-1 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                Favorites
              </p>
              <ul className="space-y-0.5">
                {favorites.map((href) => {
                  const item = navGroups.flatMap((g) => g.items).find((i) => i.href === href);
                  if (!item) return null;
                  const Icon = item.icon;
                  const active = pathname === href;
                  return (
                    <li key={href}>
                      <Link
                        href={href}
                        className={cn(
                          "flex items-center gap-2 rounded-md px-2 py-1.5 text-sm",
                          active ? "bg-sidebar-accent font-medium" : "hover:bg-sidebar-accent/60"
                        )}
                      >
                        <Icon className="h-4 w-4 shrink-0" />
                        <span className="truncate">{item.title}</span>
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          )}

          {navGroups.map((group) => (
            <div key={group.title}>
              {!collapsed && (
                <p className="px-2 pb-1 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                  {group.title}
                </p>
              )}
              <ul className="space-y-0.5">
                {group.items.map((item) => {
                  const Icon = item.icon;
                  const active = pathname === item.href || pathname.startsWith(item.href + "/");
                  const isFav = favorites.includes(item.href);
                  return (
                    <li key={item.href} className="group/item relative">
                      {collapsed ? (
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Link
                              href={item.href}
                              className={cn(
                                "flex h-10 items-center justify-center rounded-md",
                                active ? "bg-sidebar-accent font-medium" : "hover:bg-sidebar-accent/60"
                              )}
                            >
                              <Icon className="h-4 w-4" />
                            </Link>
                          </TooltipTrigger>
                          <TooltipContent side="right">{item.title}</TooltipContent>
                        </Tooltip>
                      ) : (
                        <Link
                          href={item.href}
                          className={cn(
                            "flex items-center gap-2 rounded-md px-2 py-1.5 text-sm",
                            active ? "bg-sidebar-accent font-medium" : "hover:bg-sidebar-accent/60"
                          )}
                        >
                          <Icon className="h-4 w-4 shrink-0" />
                          <span className="flex-1 truncate">{item.title}</span>
                          {item.badge && (
                            <span className="rounded bg-muted px-1.5 py-0.5 text-[10px] text-muted-foreground">
                              {item.badge}
                            </span>
                          )}
                          <button
                            type="button"
                            aria-label="Toggle favorite"
                            onClick={(e) => {
                              e.preventDefault();
                              toggleFavorite(item.href);
                            }}
                            className={cn(
                              "opacity-0 transition-opacity group-hover/item:opacity-100",
                              isFav && "opacity-100"
                            )}
                          >
                            <Star className={cn("h-3.5 w-3.5", isFav ? "fill-warning text-warning" : "text-muted-foreground")} />
                          </button>
                        </Link>
                      )}
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
        </nav>

        <div className="border-t border-sidebar-border p-2">
          <Button
            variant="ghost"
            size="sm"
            onClick={toggleSidebar}
            className="w-full justify-center text-muted-foreground"
          >
            <ChevronLeft className={cn("h-4 w-4 transition-transform", collapsed && "rotate-180")} />
            {!collapsed && <span>Collapse</span>}
          </Button>
        </div>
      </aside>
    </TooltipProvider>
  );
}
