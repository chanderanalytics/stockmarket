import {
  LayoutDashboard,
  Star,
  Filter,
  Briefcase,
  TrendingUp,
  Settings,
  type LucideIcon,
} from "lucide-react";

export interface NavItem {
  title: string;
  href: string;
  icon: LucideIcon;
  badge?: string;
}

export const navItems: NavItem[] = [
  { title: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { title: "Watchlist", href: "/watchlist", icon: Star },
  { title: "Screener", href: "/screener", icon: Filter },
  { title: "Portfolio", href: "/portfolio", icon: Briefcase },
  { title: "Markets", href: "/markets", icon: TrendingUp },
  { title: "Settings", href: "/settings", icon: Settings },
];
