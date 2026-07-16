import * as React from "react";
import { Check } from "lucide-react";
import { cn } from "@/lib/utils";

export interface Step {
  label: React.ReactNode;
  description?: React.ReactNode;
}

// Horizontal stepper for multi-step flows.
export function Steps({
  steps,
  current,
  className,
}: {
  steps: Step[];
  current: number;
  className?: string;
}) {
  return (
    <ol className={cn("flex items-center", className)}>
      {steps.map((step, i) => {
        const done = i < current;
        const active = i === current;
        return (
          <li key={i} className={cn("flex items-center", i < steps.length - 1 && "flex-1")}>
            <div className="flex items-center gap-2">
              <span
                className={cn(
                  "flex h-7 w-7 items-center justify-center rounded-full border text-xs font-medium",
                  done && "border-primary bg-primary text-primary-foreground",
                  active && "border-primary text-primary",
                  !done && !active && "border-border text-muted-foreground",
                )}
              >
                {done ? <Check className="h-3.5 w-3.5" /> : i + 1}
              </span>
              <div className="hidden sm:block">
                <p className={cn("text-sm font-medium", active || done ? "text-foreground" : "text-muted-foreground")}>{step.label}</p>
                {step.description && <p className="text-xs text-muted-foreground">{step.description}</p>}
              </div>
            </div>
            {i < steps.length - 1 && <div className={cn("mx-3 h-px flex-1", done ? "bg-primary" : "bg-border")} />}
          </li>
        );
      })}
    </ol>
  );
}
