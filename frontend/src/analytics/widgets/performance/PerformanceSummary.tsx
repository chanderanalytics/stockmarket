export function PerformanceSummary() {
  return (
    <div className="rounded-md border border-border p-4">
      <div className="mb-3 text-sm font-medium text-foreground">Strategy Summary</div>
      <div className="grid grid-cols-2 gap-3">
        {[
          { label: "Total Trades", value: "—" },
          { label: "Win Rate", value: "—" },
          { label: "Avg P&L %", value: "—" },
          { label: "Profit Factor", value: "—" },
          { label: "Sharpe Ratio", value: "—" },
          { label: "Max Drawdown", value: "—" },
        ].map((item) => (
          <div key={item.label} className="rounded-md border border-border p-2">
            <div className="text-[11px] text-muted-foreground">{item.label}</div>
            <div className="text-sm font-medium tabular-nums">{item.value}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
