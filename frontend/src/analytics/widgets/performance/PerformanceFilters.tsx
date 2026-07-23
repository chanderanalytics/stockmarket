export function PerformanceFilters() {
  return (
    <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
      <span className="font-medium text-foreground">Date Range:</span>
      <button type="button" className="rounded-md px-2 py-1 hover:text-foreground">1M</button>
      <button type="button" className="rounded-md px-2 py-1 hover:text-foreground">3M</button>
      <button type="button" className="rounded-md px-2 py-1 hover:text-foreground">6M</button>
      <button type="button" className="rounded-md px-2 py-1 hover:text-foreground">1Y</button>
      <button type="button" className="rounded-md px-2 py-1 hover:text-foreground">All</button>
      <span className="mx-2 text-border">|</span>
      <span className="font-medium text-foreground">Status:</span>
      <button type="button" className="rounded-md px-2 py-1 hover:text-foreground">All</button>
      <button type="button" className="rounded-md px-2 py-1 hover:text-foreground">Open</button>
      <button type="button" className="rounded-md px-2 py-1 hover:text-foreground">Closed</button>
    </div>
  );
}
