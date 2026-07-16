import * as React from "react";
import { Info } from "lucide-react";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";

export interface InfoTooltipProps {
  content: React.ReactNode;
  children?: React.ReactNode;
  className?: string;
}

export function InfoTooltip({ content, children, className }: InfoTooltipProps) {
  return (
    <TooltipProvider delayDuration={150}>
      <Tooltip>
        <TooltipTrigger asChild>
          <span className={cn("inline-flex cursor-help items-center text-muted-foreground", className)}>
            {children ?? <Info className="h-3.5 w-3.5" />}
          </span>
        </TooltipTrigger>
        <TooltipContent className="max-w-xs">{content}</TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}
