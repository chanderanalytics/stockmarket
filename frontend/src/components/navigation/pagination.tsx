import * as React from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

// Page pagination control for lists / tables.
export function Pagination({
  page,
  pageCount,
  onPageChange,
  className,
}: {
  page: number;
  pageCount: number;
  onPageChange: (page: number) => void;
  className?: string;
}) {
  const go = (p: number) => onPageChange(Math.min(pageCount - 1, Math.max(0, p)));
  return (
    <div className={cn("flex items-center gap-1 text-sm", className)}>
      <button className="rounded px-2 py-1 hover:bg-muted disabled:opacity-40" onClick={() => go(page - 1)} disabled={page === 0} aria-label="Previous page">
        <ChevronLeft className="h-4 w-4" />
      </button>
      <span className="px-2 tabular-nums">
        {pageCount === 0 ? 0 : page + 1}/{pageCount}
      </span>
      <button className="rounded px-2 py-1 hover:bg-muted disabled:opacity-40" onClick={() => go(page + 1)} disabled={page >= pageCount - 1} aria-label="Next page">
        <ChevronRight className="h-4 w-4" />
      </button>
    </div>
  );
}
