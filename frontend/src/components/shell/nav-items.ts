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
  { title: "Indices", href: "/indices", icon: BarChart3 },
  { title: "Volume Profile", href: "/volume-profile-v2", icon: BarChart3 },
  { title: "Price Trends", href: "/price-trends-v2", icon: LineChart },
  { title: "Settings", href: "/settings", icon: Settings },
];
