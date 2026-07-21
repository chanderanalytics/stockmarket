import {
  LayoutDashboard,
  Star,
  Filter,
  Briefcase,
  TrendingUp,
  Settings,
  BarChart3,
  LineChart,
  Gauge,
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
  { title: "Market Breadth", href: "/market-breadth", icon: Gauge },
  { title: "Volume Profile", href: "/volume-profile", icon: BarChart3 },
  { title: "Vol V2", href: "/volume-profile-v2", icon: BarChart3 },
  { title: "Price Trends", href: "/price-trends", icon: LineChart },
  { title: "Price V2", href: "/price-trends-v2", icon: LineChart },
  { title: "Settings", href: "/settings", icon: Settings },
];
