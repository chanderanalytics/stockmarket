"use client";

import * as React from "react";
import { SidebarLayout } from "@/components/layouts";
import { AppSidebar } from "./sidebar-nav";
import { AppHeader } from "./app-header";

// RootLayout (app shell): fixed sidebar on desktop, top bar + scrollable main.
export function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <SidebarLayout
      sidebar={<AppSidebar />}
      header={<AppHeader />}
      className="min-h-screen"
    >
      <main className="mx-auto w-full max-w-7xl flex-1 p-4 md:p-6">{children}</main>
    </SidebarLayout>
  );
}
