import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const typographyVariants = cva("", {
  variants: {
    variant: {
      h1: "text-2xl font-bold tracking-tight",
      h2: "text-xl font-semibold tracking-tight",
      h3: "text-base font-semibold",
      h4: "text-sm font-semibold",
      body: "text-sm",
      small: "text-xs",
      muted: "text-sm text-muted-foreground",
      caption: "text-xs text-muted-foreground",
    },
  },
  defaultVariants: { variant: "body" },
});

export interface TypographyProps
  extends React.HTMLAttributes<HTMLParagraphElement>,
    VariantProps<typeof typographyVariants> {
  as?: React.ElementType;
}

export function Typography({ variant, as, className, ...props }: TypographyProps) {
  const Comp = as || "p";
  return <Comp className={cn(typographyVariants({ variant }), className)} {...props} />;
}
