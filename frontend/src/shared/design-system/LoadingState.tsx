import * as React from "react";
import { Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

export interface LoadingStateProps {
  label?: string;
  className?: string;
}

export function LoadingState({ label = "Loading…", className }: LoadingStateProps) {
  return (
    <div className={cn("flex flex-col items-center justify-center rounded-lg border border-border px-6 py-12 text-center", className)}>
      <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      <p className="mt-3 text-sm text-muted-foreground">{label}</p>
    </div>
  );
}
