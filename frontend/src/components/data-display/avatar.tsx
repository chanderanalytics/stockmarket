import * as React from "react";
import { cn } from "@/lib/utils";

// Avatar with initials fallback.
export function Avatar({
  name,
  src,
  className,
}: {
  name?: string;
  src?: string;
  className?: string;
}) {
  const initials = (name ?? "?")
    .split(" ")
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
  return (
    <span className={cn("inline-flex h-9 w-9 items-center justify-center overflow-hidden rounded-full bg-muted text-xs font-medium text-foreground", className)}>
      {src ? <img src={src} alt={name} className="h-full w-full object-cover" /> : initials}
    </span>
  );
}
