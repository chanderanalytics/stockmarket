import * as React from "react";
import { RootLayout } from "@/components/shell";

// Layout for all authenticated app pages: sidebar + top bar shell.
export default function AppGroupLayout({ children }: { children: React.ReactNode }) {
  return <RootLayout>{children}</RootLayout>;
}
