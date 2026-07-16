import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";
import { AlertCircle, CheckCircle2, Info } from "lucide-react";

const alertVariants = cva("flex gap-3 rounded-lg border p-3 text-sm", {
  variants: {
    tone: {
      default: "border-border bg-card text-foreground",
      info: "border-primary/40 bg-primary/5 text-foreground",
      success: "border-success/40 bg-success/5 text-foreground",
      warning: "border-warning/40 bg-warning/5 text-foreground",
      error: "border-destructive/40 bg-destructive/5 text-foreground",
    },
  },
  defaultVariants: { tone: "default" },
});

const icons = {
  info: Info,
  success: CheckCircle2,
  warning: AlertCircle,
  error: AlertCircle,
  default: Info,
};

export interface AlertProps
  extends Omit<React.HTMLAttributes<HTMLDivElement>, "title">,
    VariantProps<typeof alertVariants> {
  title?: React.ReactNode;
}

export function Alert({ tone = "default", title, className, children, ...props }: AlertProps) {
  const Icon = icons[tone ?? "default"];
  return (
    <div className={cn(alertVariants({ tone }), className)} {...props}>
      <Icon className="mt-0.5 h-4 w-4 shrink-0" />
      <div className="flex-1">
        {title && <p className="font-medium">{title}</p>}
        {children && <div className="text-muted-foreground">{children}</div>}
      </div>
    </div>
  );
}
