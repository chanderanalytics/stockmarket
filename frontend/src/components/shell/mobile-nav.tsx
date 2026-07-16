"use client";

import * as React from "react";
import { Menu } from "lucide-react";
import { Button } from "@/components/ui/button";
import { navItems } from "./nav-items";
import { AppSidebar } from "./sidebar-nav";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";

// Mobile-only slide-in navigation (hidden on md+).
export function MobileNav() {
  const [open, setOpen] = React.useState(false);
  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="ghost" size="icon" className="md:hidden" aria-label="Open menu">
          <Menu className="h-5 w-5" />
        </Button>
      </SheetTrigger>
      <SheetContent side="left" className="w-64 p-0">
        <AppSidebar onNavigate={() => setOpen(false)} />
      </SheetContent>
    </Sheet>
  );
}
