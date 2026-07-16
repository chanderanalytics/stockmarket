"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command";
import { allNavItems } from "./nav-config";
import { useUiStore } from "@/state/ui-store";
import { usePreferencesStore } from "@/state/preferences-store";

// Command palette (⌘K): global search across navigation + recent pages.
export function CommandPalette() {
  const router = useRouter();
  const open = useUiStore((s) => s.commandOpen);
  const setOpen = useUiStore((s) => s.setCommandOpen);
  const recent = usePreferencesStore((s) => s.recent);
  const pushRecent = usePreferencesStore((s) => s.pushRecent);

  React.useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen(!open);
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, setOpen]);

  const go = (href: string) => {
    pushRecent(href);
    setOpen(false);
    router.push(href);
  };

  const recentItems = recent
    .map((href) => allNavItems.find((i) => i.href === href))
    .filter(Boolean) as typeof allNavItems;

  return (
    <CommandDialog open={open} onOpenChange={setOpen}>
      <CommandInput placeholder="Search pages, screens, actions…" />
      <CommandList>
        <CommandEmpty>No results found.</CommandEmpty>
        {recentItems.length > 0 && (
          <CommandGroup heading="Recent">
            {recentItems.map((item) => {
              const Icon = item.icon;
              return (
                <CommandItem key={`recent-${item.href}`} value={`recent ${item.title}`} onSelect={() => go(item.href)}>
                  <Icon className="h-4 w-4" />
                  {item.title}
                </CommandItem>
              );
            })}
          </CommandGroup>
        )}
        <CommandGroup heading="Navigation">
          {allNavItems.map((item) => {
            const Icon = item.icon;
            return (
              <CommandItem key={item.href} value={item.title} onSelect={() => go(item.href)}>
                <Icon className="h-4 w-4" />
                <span>{item.title}</span>
                {item.description && <span className="ml-2 text-xs text-muted-foreground">{item.description}</span>}
              </CommandItem>
            );
          })}
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  );
}
