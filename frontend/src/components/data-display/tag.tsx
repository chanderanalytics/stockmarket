import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const tagVariants = cva(
  "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium",
  {
    variants: {
      tone: {
        default: "bg-muted text-muted-foreground",
        primary: "bg-primary/10 text-primary",
        success: "bg-success/15 text-success",
        warning: "bg-warning/15 text-warning",
        destructive: "bg-destructive/15 text-destructive",
        outline: "border border-border text-foreground",
      },
    },
    defaultVariants: { tone: "default" },
  },
);

export interface TagProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof tagVariants> {}

export function Tag({ tone, className, ...props }: TagProps) {
  return <span className={cn(tagVariants({ tone }), className)} {...props} />;
}
