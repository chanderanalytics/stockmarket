"use client";

import * as React from "react";
import { User, Settings, LogOut, Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { usePreferencesStore } from "@/state/preferences-store";

// User menu (Milestone 1, Task 10). Auth-ready stub.
export function UserMenu() {
  const favorites = usePreferencesStore((s) => s.favorites);
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" aria-label="User menu" className="rounded-full">
          <span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary/15 text-primary">
            <User className="h-4 w-4" />
          </span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56">
        <DropdownMenuLabel>
          <div className="flex flex-col">
            <span className="text-sm font-medium">Analyst</span>
            <span className="text-xs text-muted-foreground">analyst@stockintel.io</span>
          </div>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem>
          <Star className="h-4 w-4" /> Favorites ({favorites.length})
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <a href="/settings">
            <Settings className="h-4 w-4" /> Settings
          </a>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem className="text-destructive">
          <LogOut className="h-4 w-4" /> Sign out
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
