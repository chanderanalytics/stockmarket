import * as React from "react";
import { cn } from "@/lib/utils";

// SidebarLayout: fixed sidebar + flexible content column with a sticky header.
export function SidebarLayout({
  children,
  sidebar,
  header,
  className,
}: {
  children: React.ReactNode;
  sidebar?: React.ReactNode;
  header?: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex h-screen overflow-hidden bg-background", className)}>
      {sidebar && <div className="hidden md:block">{sidebar}</div>}
      <div className="flex flex-1 flex-col overflow-hidden">
        {header}
        <main className="flex-1 overflow-y-auto scrollbar-thin">{children}</main>
      </div>
    </div>
  );
}
