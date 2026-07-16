import Link from "next/link";
import { TrendingUp, Star, Filter, Briefcase } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

export default function HomePage() {
  return (
    <div className="mx-auto flex min-h-screen max-w-5xl flex-col items-center justify-center px-4 py-16 text-center">
      <span className="mb-4 rounded-full border border-border bg-muted/40 px-3 py-1 text-xs text-muted-foreground">
        Next.js · Tailwind · Recharts · React Query
      </span>
      <h1 className="text-balance text-4xl font-bold tracking-tight sm:text-5xl">
        Your market data, beautifully organized.
      </h1>
      <p className="mt-4 max-w-2xl text-balance text-muted-foreground">
        Watchlists, screeners, portfolios and live charts in one fast dashboard — built on a reusable UI
        component library.
      </p>
      <div className="mt-8 flex gap-3">
        <Button asChild size="lg">
          <Link href="/dashboard">Open Dashboard</Link>
        </Button>
        <Button asChild size="lg" variant="outline">
          <Link href="/auth/login">Sign in</Link>
        </Button>
      </div>

      <div className="mt-16 grid w-full grid-cols-2 gap-4 sm:grid-cols-4">
        {[
          { icon: TrendingUp, title: "Markets", desc: "Track indices & movers" },
          { icon: Star, title: "Watchlists", desc: "Curate your tickers" },
          { icon: Filter, title: "Screener", desc: "Filter the universe" },
          { icon: Briefcase, title: "Portfolio", desc: "Measure performance" },
        ].map((f) => (
          <Card key={f.title} className="space-y-2 p-4 text-left">
            <f.icon className="h-5 w-5 text-primary" />
            <p className="text-sm font-medium">{f.title}</p>
            <p className="text-xs text-muted-foreground">{f.desc}</p>
          </Card>
        ))}
      </div>
    </div>
  );
}
