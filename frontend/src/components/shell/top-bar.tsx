"use client";

import * as React from "react";
import { Search, Bell } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "./theme-toggle";
import { MobileNav } from "./mobile-nav";
import { CommandPalette } from "@/components/layouts/navigation/command-palette";
import { useUiStore } from "@/state";

// Sticky top bar: brand, mobile menu, command palette trigger, theme + user.
export function TopBar() {
  const setCommandOpen = useUiStore((s) => s.setCommandOpen);

  return (
    <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-border bg-background/80 px-4 backdrop-blur">
      <MobileNav />

      <button
        onClick={() => setCommandOpen(true)}
        className="flex h-9 flex-1 items-center gap-2 rounded-md border border-input bg-muted/40 px-3 text-sm text-muted-foreground hover:bg-muted md:max-w-md"
      >
        <Search className="h-4 w-4" />
        <span>Search stocks…</span>
        <kbd className="ml-auto hidden rounded border border-border bg-background px-1.5 text-[10px] sm:inline">⌘K</kbd>
      </button>

      <div className="ml-auto flex items-center gap-1">
        <Button variant="ghost" size="icon" aria-label="Notifications">
          <Bell className="h-4 w-4" />
        </Button>
        <ThemeToggle />
        <div className="ml-1 h-8 w-8 rounded-full bg-primary/20" aria-hidden />
      </div>

      <CommandPalette />
    </header>
  );
}
