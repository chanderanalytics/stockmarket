import * as React from "react";
import { SidebarLayout } from "./sidebar-layout";
import { Sidebar } from "./navigation/sidebar";
import { Topbar } from "./navigation/topbar";

// DashboardLayout: the permanent application shell for authenticated pages.
// Stays constant as features are added — only `children` change.
export function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <SidebarLayout sidebar={<Sidebar />} header={<Topbar />}>
      <div className="mx-auto w-full max-w-[1600px] p-4 md:p-6">{children}</div>
    </SidebarLayout>
  );
}
