import * as React from "react";
import { Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

export function Spinner({ className, size = 16 }: { className?: string; size?: number }) {
  return <Loader2 style={{ width: size, height: size }} className={cn("animate-spin text-muted-foreground", className)} />;
}
