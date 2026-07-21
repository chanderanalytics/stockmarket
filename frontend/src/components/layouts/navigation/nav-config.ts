import type { LucideIcon } from "lucide-react";
import { Activity, Filter, LineChart, Wallet, BookOpen, Settings, Gauge, Layers } from "lucide-react";

// Data-driven navigation (Milestone 1, Task 5).
// Adding a new page requires ONLY adding an entry here — the sidebar, top bar,
// breadcrumbs, command palette and recent/favorites all derive from this config.

export interface NavItem {
  title: string;
  href: string;
  icon: LucideIcon;
  description?: string;
  /** Optional short label e.g. "soon", "beta". */
  badge?: string;
}

export interface NavGroup {
  title: string;
  items: NavItem[];
}

export const navGroups: NavGroup[] = [
  {
    title: "Markets",
    items: [
      {
        title: "Market Pulse",
        href: "/market-pulse",
        icon: Activity,
        description: "Live market overview, movers and breadth at a glance.",
      },
      {
        title: "Market Breadth",
        href: "/market-breadth",
        icon: Gauge,
        description: "Advance/decline, market breadth and momentum indicators.",
      },
      {
        title: "Sectors",
        href: "/sectors",
        icon: Layers,
        description: "Sector and industry rotation and performance.",
        badge: "soon",
      },
      {
        title: "Screeners",
        href: "/screeners",
        icon: Filter,
        description: "Build and save filters across fundamentals and price.",
        badge: "soon",
      },
      {
        title: "Stocks",
        href: "/stocks",
        icon: LineChart,
        description: "Per-stock drilldown, charts and probability metrics.",
        badge: "soon",
      },
      {
        title: "Research",
        href: "/research",
        icon: BookOpen,
        description: "Notes, signals and AI-generated summaries.",
        badge: "soon",
      },
    ],
  },
  {
    title: "Portfolio",
    items: [
      {
        title: "Portfolio",
        href: "/portfolio",
        icon: Wallet,
        description: "Track holdings, P&L and allocations.",
        badge: "soon",
      },
    ],
  },
  {
    title: "System",
    items: [
      {
        title: "Settings",
        href: "/settings",
        icon: Settings,
        description: "Preferences, theme and data sources.",
      },
    ],
  },
];

// Flat list derived for search/breadcrumbs.
export const allNavItems: NavItem[] = navGroups.flatMap((g) => g.items);

export function findNavItem(href: string): NavItem | undefined {
  return allNavItems.find((i) => i.href === href);
}
