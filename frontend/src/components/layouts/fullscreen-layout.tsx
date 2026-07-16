import * as React from "react";
import { cn } from "@/lib/utils";

// FullscreenLayout: minimal chrome (no sidebar) for embeds / focused views.
export function FullscreenLayout({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return <div className={cn("min-h-screen bg-background", className)}>{children}</div>;
}
