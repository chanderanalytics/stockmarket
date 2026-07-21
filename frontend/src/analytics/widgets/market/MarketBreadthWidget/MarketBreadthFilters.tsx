"use client";

import * as React from "react";

export interface MarketBreadthFiltersProps {
  sector: string;
  industry: string;
  industrySubGroup: string;
  marketCap: string;
  marketCapBucket: string;
  limit: number;
  sectorOptions: string[];
  industryOptions: string[];
  subGroupOptions: string[];
  onSectorChange: (value: string) => void;
  onIndustryChange: (value: string) => void;
  onSubGroupChange: (value: string) => void;
  onMarketCapChange: (value: string) => void;
  onMarketCapBucketChange: (value: string) => void;
  onLimitChange: (value: number) => void;
  onReset: () => void;
  disabled?: boolean;
}

const selectClass =
  "h-9 w-full rounded-md border border-border bg-background px-2 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring";

function HierarchySelect({
  label,
  value,
  options,
  onChange,
  disabled,
}: {
  label: string;
  value: string;
  options: string[];
  onChange: (value: string) => void;
  disabled?: boolean;
}) {
  return (
    <label className="flex flex-col gap-1 text-xs text-muted-foreground">
      {label}
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled}
        className={selectClass}
      >
        <option value="">All</option>
        {options.map((opt) => (
          <option key={opt} value={opt}>
            {opt}
          </option>
        ))}
      </select>
    </label>
  );
}

export function MarketBreadthFilters({
  sector,
  industry,
  industrySubGroup,
  marketCap,
  marketCapBucket,
  limit,
  sectorOptions,
  industryOptions,
  subGroupOptions,
  onSectorChange,
  onIndustryChange,
  onSubGroupChange,
  onMarketCapChange,
  onMarketCapBucketChange,
  onLimitChange,
  onReset,
  disabled,
}: MarketBreadthFiltersProps) {
  const marketCapOptions = [
    { value: "", label: "All" },
    { value: "large", label: "Large Cap" },
    { value: "mid", label: "Mid Cap" },
    { value: "small", label: "Small Cap" },
  ] as const;

  const bucketOptions = [
    { value: "", label: "All" },
    { value: "top 10perc by mcap", label: "Top 10%" },
    { value: "50-90% by mcap", label: "50-90%" },
    { value: "bottom 50% by mcap", label: "Bottom 50%" },
  ] as const;

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7">
      <HierarchySelect
        label="Sector"
        value={sector}
        options={sectorOptions}
        onChange={onSectorChange}
        disabled={disabled}
      />
      <HierarchySelect
        label="Industry"
        value={industry}
        options={industryOptions}
        onChange={onIndustryChange}
        disabled={disabled || !sector}
      />
      <HierarchySelect
        label="Sub-Group"
        value={industrySubGroup}
        options={subGroupOptions}
        onChange={onSubGroupChange}
        disabled={disabled || !industry}
      />
      <HierarchySelect
        label="Market Cap"
        value={marketCap}
        options={marketCapOptions.map((o) => o.value)}
        onChange={(v) => onMarketCapChange(v)}
        disabled={disabled}
      />
      <HierarchySelect
        label="Cap Bucket"
        value={marketCapBucket}
        options={bucketOptions.map((o) => o.value)}
        onChange={(v) => onMarketCapBucketChange(v)}
        disabled={disabled}
      />
      <HierarchySelect
        label="Rows"
        value={String(limit)}
        options={["12", "25", "50", "100", "250", "500"]}
        onChange={(v) => {
          const n = Number(v);
          onLimitChange(Number.isFinite(n) ? Math.min(n, 500) : 500);
        }}
        disabled={disabled}
      />
      <div className="flex justify-end">
        <button
          type="button"
          onClick={onReset}
          disabled={disabled}
          className="h-8 rounded-md border border-border px-3 text-xs hover:bg-accent disabled:opacity-50"
        >
          Reset
        </button>
      </div>
    </div>
  );
}
