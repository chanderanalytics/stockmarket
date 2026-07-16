"use client";

import * as React from "react";
import { Menu, Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Breadcrumbs } from "./breadcrumbs";
import { ThemeToggle } from "./theme-toggle";
import { Notifications } from "./notifications";
import { UserMenu } from "./user-menu";
import { Sidebar } from "./sidebar";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import { useUiStore } from "@/state/ui-store";

// Sticky top bar (Milestone 1, Task 4 + Task 10).
export function Topbar() {
  const setCommandOpen = useUiStore((s) => s.setCommandOpen);
  const mobileNavOpen = useUiStore((s) => s.mobileNavOpen);
  const setMobileNavOpen = useUiStore((s) => s.setMobileNavOpen);

  return (
    <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-border bg-background/80 px-4 backdrop-blur">
      <Button
        variant="ghost"
        size="icon"
        className="md:hidden"
        aria-label="Open navigation"
        onClick={() => setMobileNavOpen(true)}
      >
        <Menu className="h-5 w-5" />
      </Button>

      <div className="hidden md:block">
        <Breadcrumbs />
      </div>

      <div className="ml-auto flex items-center gap-1">
        <Button
          variant="outline"
          size="sm"
          onClick={() => setCommandOpen(true)}
          className="h-9 gap-2 text-muted-foreground"
        >
          <Search className="h-4 w-4" />
          <span className="hidden sm:inline">Search</span>
          <kbd className="hidden rounded border border-border bg-muted px-1.5 text-[10px] font-medium sm:inline">
            ⌘K
          </kbd>
        </Button>
        <Notifications />
        <ThemeToggle />
        <UserMenu />
      </div>

      {/* Mobile navigation */}
      <Sheet open={mobileNavOpen} onOpenChange={setMobileNavOpen}>
        <SheetContent side="left" className="w-72 p-0">
          <SheetTitle className="sr-only">Navigation</SheetTitle>
          <Sidebar />
        </SheetContent>
      </Sheet>
    </header>
  );
}
