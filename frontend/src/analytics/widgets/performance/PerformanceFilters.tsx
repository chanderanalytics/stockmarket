import * as React from "react";

export type DateRange = "1M" | "3M" | "6M" | "1Y" | "ALL";
export type StatusFilter = "ALL" | "WIN" | "LOSS" | "OPEN";

export interface PerformanceFiltersProps {
  filters: {
    dateRange: DateRange;
    status: StatusFilter;
  };
  onFiltersChange: (filters: { dateRange: DateRange; status: StatusFilter }) => void;
  companySearch: string;
  onCompanySearchChange: (value: string) => void;
}

export function PerformanceFilters({
  filters,
  onFiltersChange,
  companySearch,
  onCompanySearchChange,
}: PerformanceFiltersProps) {
  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
        <span className="font-medium text-foreground">Date Range:</span>
        {(["1M", "3M", "6M", "1Y", "ALL"] as DateRange[]).map((range) => (
          <button
            key={range}
            type="button"
            onClick={() => onFiltersChange({ ...filters, dateRange: range })}
            className={`rounded-md px-2 py-1 ${
              filters.dateRange === range ? "bg-accent text-accent-foreground" : "hover:text-foreground"
            }`}
          >
            {range === "ALL" ? "All" : range}
          </button>
        ))}
        <span className="mx-2 text-border">|</span>
        <span className="font-medium text-foreground">Status:</span>
        {(["ALL", "WIN", "LOSS", "OPEN"] as StatusFilter[]).map((status) => (
          <button
            key={status}
            type="button"
            onClick={() => onFiltersChange({ ...filters, status })}
            className={`rounded-md px-2 py-1 ${
              filters.status === status ? "bg-accent text-accent-foreground" : "hover:text-foreground"
            }`}
          >
            {status === "ALL" ? "All" : status}
          </button>
        ))}
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="text"
          placeholder="Search companies..."
          value={companySearch}
          onChange={(e) => onCompanySearchChange(e.target.value)}
          className="h-8 rounded-md border border-border bg-background px-2 text-sm"
        />
      </div>
    </div>
  );
}
