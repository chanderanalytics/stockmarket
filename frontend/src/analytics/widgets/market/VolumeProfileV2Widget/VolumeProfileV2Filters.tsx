"use client";

import * as React from "react";
import type {
  CompanyOption,
  VolumeProfileV2MarketCap,
  VolumeProfileV2MarketCapBucket,
} from "./VolumeProfileV2.types";

interface VolumeProfileV2FiltersProps {
  sector: string;
  industry: string;
  industrySubGroup: string;
  sectorOptions: string[];
  industryOptions: string[];
  subGroupOptions: string[];
  marketCap: VolumeProfileV2MarketCap;
  marketCapBucket: VolumeProfileV2MarketCapBucket;
  limit: number;
  companyName: string;
  companyOptions: CompanyOption[];
  onSector: (value: string) => void;
  onIndustry: (value: string) => void;
  onIndustrySubGroup: (value: string) => void;
  onMarketCap: (value: VolumeProfileV2MarketCap) => void;
  onMarketCapBucket: (value: VolumeProfileV2MarketCapBucket) => void;
  onLimit: (value: number) => void;
  onCompanyName: (value: string) => void;
  onCompanySelect: (row: CompanyOption) => void;
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

function CompanyAutocomplete({
  value,
  options,
  onChange,
  onSelect,
  disabled,
}: {
  value: string;
  options: CompanyOption[];
  onChange: (value: string) => void;
  onSelect: (row: CompanyOption) => void;
  disabled?: boolean;
}) {
  const [query, setQuery] = React.useState(value);
  const [open, setOpen] = React.useState(false);
  const [highlighted, setHighlighted] = React.useState(0);
  const listRef = React.useRef<HTMLUListElement>(null);
  const inputRef = React.useRef<HTMLInputElement>(null);

  React.useEffect(() => { setQuery(value); }, [value]);

  const filtered = React.useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return options
      .filter((o) => o.name.toLowerCase().startsWith(q))
      .sort((a, b) => a.name.localeCompare(b.name))
      .slice(0, 30);
  }, [query, options]);

  const pick = (row: CompanyOption) => {
    setQuery(row.name);
    onChange(row.name);
    onSelect(row);
    setOpen(false);
    inputRef.current?.blur();
  };

  const clear = () => {
    setQuery("");
    onChange("");
    setOpen(false);
    setHighlighted(0);
    inputRef.current?.focus();
  };

  return (
    <label className="flex flex-col gap-1 text-xs text-muted-foreground relative">
      Company
      <div className="relative">
        <input
          ref={inputRef}
          value={query}
          placeholder="Search companies…"
          onChange={(e) => {
            setQuery(e.target.value);
            onChange(e.target.value);
            setOpen(true);
            setHighlighted(0);
          }}
          onFocus={() => setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 120)}
          onKeyDown={(e) => {
            if (!open || !filtered.length) return;
            if (e.key === "ArrowDown") {
              e.preventDefault();
              setHighlighted((h) => Math.min(h + 1, filtered.length - 1));
            } else if (e.key === "ArrowUp") {
              e.preventDefault();
              setHighlighted((h) => Math.max(h - 1, 0));
            } else if (e.key === "Enter") {
              e.preventDefault();
              const row = filtered[highlighted];
              if (row) pick(row);
              else {
                onChange(query);
                setOpen(false);
                inputRef.current?.blur();
              }
            } else if (e.key === "Escape") {
              setOpen(false);
            }
          }}
          disabled={disabled}
          className={selectClass}
          role="combobox"
          aria-expanded={open}
          aria-haspopup="listbox"
          autoComplete="off"
        />
        {query && !disabled && (
          <button
            type="button"
            onClick={clear}
            aria-label="Clear company search"
            className="absolute right-2 top-1/2 -translate-y-1/2 cursor-pointer rounded-sm px-1 text-base leading-none text-muted-foreground hover:text-foreground"
            tabIndex={-1}
          >
            ×
          </button>
        )}
      </div>
      {open && filtered.length > 0 && (
        <ul
          ref={listRef}
          className="absolute left-0 right-0 top-full z-50 mt-1 max-h-52 overflow-y-auto rounded-md border border-border bg-background shadow-lg"
          role="listbox"
        >
          {filtered.map((row, idx) => (
            <li
              key={row.id}
              role="option"
              aria-selected={idx === highlighted}
              onMouseDown={() => pick(row)}
              onMouseEnter={() => setHighlighted(idx)}
              className={`cursor-pointer px-2 py-1.5 text-sm ${
                idx === highlighted ? "bg-accent text-accent-foreground" : "text-foreground"
              }`}
            >
              {row.name}
            </li>
          ))}
        </ul>
      )}
    </label>
  );
}

export function VolumeProfileV2Filters({
  sector,
  industry,
  industrySubGroup,
  sectorOptions,
  industryOptions,
  subGroupOptions,
  marketCap,
  marketCapBucket,
  limit,
  companyName,
  companyOptions,
  onSector,
  onIndustry,
  onIndustrySubGroup,
  onMarketCap,
  onMarketCapBucket,
  onLimit,
  onCompanyName,
  onCompanySelect,
  disabled,
}: VolumeProfileV2FiltersProps) {
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
        onChange={onSector}
        disabled={disabled}
      />
      <HierarchySelect
        label="Industry"
        value={industry}
        options={industryOptions}
        onChange={onIndustry}
        disabled={disabled}
      />
      <HierarchySelect
        label="Sub-Group"
        value={industrySubGroup}
        options={subGroupOptions}
        onChange={onIndustrySubGroup}
        disabled={disabled}
      />
      <HierarchySelect
        label="Market Cap"
        value={marketCap}
        options={marketCapOptions.map((o) => o.value)}
        onChange={(v) => onMarketCap(v as VolumeProfileV2MarketCap)}
        disabled={disabled}
      />
      <HierarchySelect
        label="Cap Bucket"
        value={marketCapBucket}
        options={bucketOptions.map((o) => o.value)}
        onChange={(v) => onMarketCapBucket(v as VolumeProfileV2MarketCapBucket)}
        disabled={disabled}
      />
      <HierarchySelect
        label="Rows"
        value={String(limit)}
        options={["25", "50", "100", "250", "500"]}
        onChange={(v) => onLimit(Number(v))}
        disabled={disabled}
      />
      <CompanyAutocomplete
        value={companyName}
        options={companyOptions}
        onChange={onCompanyName}
        onSelect={onCompanySelect}
        disabled={disabled}
      />
    </div>
  );
}
