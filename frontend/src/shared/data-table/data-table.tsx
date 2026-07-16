"use client";

import * as React from "react";
import { useVirtualizer } from "@tanstack/react-virtual";
import { ChevronUp, ChevronDown, ChevronsUpDown, Search } from "lucide-react";
import { cn } from "@/lib/utils";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { Spinner } from "@/components/feedback/spinner";
import type { ColumnDef } from "./types";

export type { ColumnDef } from "./types";

type SortDir = "asc" | "desc" | null;

export function DataTable<T>({
  data,
  columns,
  rowKey,
  searchable = true,
  pageSize = 10,
  selectable = false,
  selectedIds,
  onSelectedChange,
  virtualized = false,
  maxHeight = 480,
  loading = false,
  emptyMessage = "No results.",
  onRowClick,
  className,
  title,
}: {
  data: T[];
  columns: ColumnDef<T>[];
  rowKey: (row: T) => string;
  searchable?: boolean;
  pageSize?: number;
  selectable?: boolean;
  selectedIds?: string[];
  onSelectedChange?: (ids: string[]) => void;
  virtualized?: boolean;
  maxHeight?: number;
  loading?: boolean;
  emptyMessage?: React.ReactNode;
  onRowClick?: (row: T) => void;
  className?: string;
  title?: React.ReactNode;
}) {
  const [sortKey, setSortKey] = React.useState<string | null>(null);
  const [sortDir, setSortDir] = React.useState<SortDir>(null);
  const [query, setQuery] = React.useState("");
  const [page, setPage] = React.useState(0);
  const selection = React.useState<string[]>([]);
  const selected = selectedIds ?? selection[0];
  const setSelected = onSelectedChange ?? selection[1];

  const filtered = React.useMemo(() => {
    if (!query.trim()) return data;
    const q = query.toLowerCase();
    return data.filter((row) =>
      columns.some((c) => {
        const v = c.filterValue ? c.filterValue(row) : c.accessor ? String(c.accessor(row) ?? "") : "";
        return v.toLowerCase().includes(q);
      }),
    );
  }, [data, query, columns]);

  const sorted = React.useMemo(() => {
    if (!sortKey || !sortDir) return filtered;
    const col = columns.find((c) => c.key === sortKey);
    if (!col) return filtered;
    const acc = col.accessor ?? ((r: T) => (col.filterValue ? col.filterValue(r) : r));
    const arr = [...filtered].sort((a, b) => {
      const av = acc(a);
      const bv = acc(b);
      if (av == null) return 1;
      if (bv == null) return -1;
      if (typeof av === "number" && typeof bv === "number") return sortDir === "asc" ? av - bv : bv - av;
      return sortDir === "asc"
        ? String(av).localeCompare(String(bv))
        : String(bv).localeCompare(String(av));
    });
    return arr;
  }, [filtered, sortKey, sortDir, columns]);

  const pageCount = Math.max(1, Math.ceil(sorted.length / pageSize));
  const safePage = Math.min(page, pageCount - 1);
  const paged = virtualized ? sorted : sorted.slice(safePage * pageSize, safePage * pageSize + pageSize);

  React.useEffect(() => {
    setPage(0);
  }, [query, sortKey, sortDir, pageSize]);

  const toggleSort = (key: string) => {
    if (sortKey !== key) {
      setSortKey(key);
      setSortDir("asc");
      return;
    }
    setSortDir((d) => (d === "asc" ? "desc" : d === "desc" ? null : "asc"));
    if (sortDir === "desc") setSortKey(null);
  };

  const allVisibleSelected = paged.length > 0 && paged.every((r) => selected.includes(rowKey(r)));
  const toggleAll = () => {
    if (allVisibleSelected) {
      setSelected(selected.filter((id) => !paged.some((r) => rowKey(r) === id)));
    } else {
      setSelected(Array.from(new Set([...selected, ...paged.map(rowKey)])));
    }
  };
  const toggleRow = (id: string) =>
    setSelected(selected.includes(id) ? selected.filter((x) => x !== id) : [...selected, id]);

  const renderHeader = () => (
    <thead className="sticky top-0 z-10 bg-card">
      <tr className="border-b border-border">
        {selectable && (
          <th className="w-10 px-3 py-2">
            <Checkbox checked={allVisibleSelected} onCheckedChange={toggleAll} aria-label="Select all" />
          </th>
        )}
        {columns.map((c) => (
          <th
            key={c.key}
            onClick={c.sortable ? () => toggleSort(c.key) : undefined}
            className={cn(
              "px-3 py-2 text-xs font-medium text-muted-foreground",
              c.align === "right" ? "text-right" : c.align === "center" ? "text-center" : "text-left",
              c.sortable && "cursor-pointer select-none hover:text-foreground",
              c.className,
            )}
          >
            <span className={cn("inline-flex items-center gap-1", c.align === "right" && "flex-row-reverse")}>
              {c.header}
              {c.sortable &&
                (sortKey === c.key && sortDir === "asc" ? (
                  <ChevronUp className="h-3 w-3" />
                ) : sortKey === c.key && sortDir === "desc" ? (
                  <ChevronDown className="h-3 w-3" />
                ) : (
                  <ChevronsUpDown className="h-3 w-3 opacity-40" />
                ))}
            </span>
          </th>
        ))}
      </tr>
    </thead>
  );

  const renderRow = (row: T, virtualStyle?: React.CSSProperties) => {
    const id = rowKey(row);
    return (
      <tr
        style={virtualStyle}
        key={id}
        onClick={onRowClick ? () => onRowClick(row) : undefined}
        className={cn(
          "border-b border-border/60 transition-colors hover:bg-muted/40",
          onRowClick && "cursor-pointer",
          selected.includes(id) && "bg-primary/5",
        )}
      >
        {selectable && (
          <td className="w-10 px-3 py-2" onClick={(e) => e.stopPropagation()}>
            <Checkbox checked={selected.includes(id)} onCheckedChange={() => toggleRow(id)} aria-label="Select row" />
          </td>
        )}
        {columns.map((c) => (
          <td
            key={c.key}
            className={cn(
              "px-3 py-2 text-sm text-foreground",
              c.align === "right" ? "text-right tabular-nums" : c.align === "center" ? "text-center" : "text-left",
              c.className,
            )}
          >
            {c.cell ? c.cell(row) : c.accessor ? String(c.accessor(row) ?? "") : null}
          </td>
        ))}
      </tr>
    );
  };

  const parentRef = React.useRef<HTMLDivElement>(null);
  const rows = paged;
  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 40,
    overscan: 10,
    enabled: virtualized,
  });

  return (
    <div className={cn("rounded-lg border border-border bg-card", className)}>
      {title && <div className="border-b border-border px-3 py-2 text-sm font-medium">{title}</div>}
      {title && <div className="border-b border-border px-3 py-2 text-sm font-medium">{title}</div>}
      {searchable && (
        <div className="flex items-center gap-2 border-b border-border p-3">
          <Search className="h-4 w-4 text-muted-foreground" />
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search…"
            className="h-8"
          />
          {selectable && selected.length > 0 && (
            <span className="ml-auto text-xs text-muted-foreground">{selected.length} selected</span>
          )}
        </div>
      )}
      {virtualized ? (
        <div ref={parentRef} style={{ height: maxHeight }} className="overflow-auto scrollbar-thin">
          <table className="w-full border-collapse">
            {renderHeader()}
            <tbody style={{ height: virtualizer.getTotalSize(), display: "relative" }}>
              {virtualizer.getVirtualItems().map((vi) => (
                <React.Fragment key={vi.key}>
                  {renderRow(rows[vi.index], { position: "absolute", top: 0, transform: `translateY(${vi.start}px)`, width: "100%" })}
                </React.Fragment>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="overflow-x-auto scrollbar-thin">
          <table className="w-full border-collapse">
            {renderHeader()}
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={columns.length + (selectable ? 1 : 0)} className="py-10">
                    <div className="flex justify-center">
                      <Spinner />
                    </div>
                  </td>
                </tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td colSpan={columns.length + (selectable ? 1 : 0)} className="py-10 text-center text-sm text-muted-foreground">
                    {emptyMessage}
                  </td>
                </tr>
              ) : (
                rows.map((row) => renderRow(row))
              )}
            </tbody>
          </table>
        </div>
      )}
      {!virtualized && (
        <div className="flex items-center justify-between border-t border-border px-3 py-2 text-xs text-muted-foreground">
          <span>
            {sorted.length === 0 ? 0 : safePage * pageSize + 1}–{Math.min((safePage + 1) * pageSize, sorted.length)} of {sorted.length}
          </span>
          <div className="flex items-center gap-1">
            <button
              className="rounded px-2 py-1 hover:bg-muted disabled:opacity-40"
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              disabled={safePage === 0}
            >
              Prev
            </button>
            <span className="px-1">
              {safePage + 1}/{pageCount}
            </span>
            <button
              className="rounded px-2 py-1 hover:bg-muted disabled:opacity-40"
              onClick={() => setPage((p) => Math.min(pageCount - 1, p + 1))}
              disabled={safePage >= pageCount - 1}
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
