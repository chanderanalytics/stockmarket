import * as React from "react";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export interface ErrorStateProps {
  title?: string;
  error?: unknown;
  onRetry?: () => void;
  className?: string;
}

function messageFrom(error: unknown): string | null {
  if (!error) return null;
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  return null;
}

export function ErrorState({ title = "Something went wrong", error, onRetry, className }: ErrorStateProps) {
  const msg = messageFrom(error);
  return (
    <div className={cn("flex flex-col items-center justify-center rounded-lg border border-destructive/40 bg-destructive/5 px-6 py-12 text-center", className)}>
      <AlertTriangle className="h-10 w-10 text-destructive" />
      <p className="mt-4 text-sm font-medium text-foreground">{title}</p>
      {msg && <p className="mt-1 max-w-sm text-sm text-muted-foreground">{msg}</p>}
      {onRetry && (
        <Button variant="outline" size="sm" className="mt-4" onClick={onRetry}>
          Retry
        </Button>
      )}
    </div>
  );
}
