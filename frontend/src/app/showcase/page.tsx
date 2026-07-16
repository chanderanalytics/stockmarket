"use client";

import * as React from "react";

import {
  MetricCardPrimitive,
  KPIGridPrimitive,
  SummaryStripPrimitive,
  StatusCardPrimitive,
  ValueComparisonPrimitive,
  DataTablePrimitive,
  HierarchyTablePrimitive,
  TreeTablePrimitive,
  MatrixTablePrimitive,
  RankingTablePrimitive,
  LineChartPrimitive,
  AreaChartPrimitive,
  BarChartPrimitive,
  StackedBarPrimitive,
  GroupedBarPrimitive,
  HeatmapPrimitive,
  TreemapPrimitive,
  ScatterPrimitive,
  DistributionPrimitive,
  GaugePrimitive,
  TimelinePrimitive,
  SparklinePrimitive,
  CandlestickPrimitive,
  OHLCPrimitive,
  VisualizationContainer,
  VisualizationToolbar,
  VisualizationLegend,
  VisualizationTooltip,
  VisualizationLoading,
  VisualizationEmpty,
  VisualizationError,
} from "@/visualization/primitives";

import {
  ReactComponentsAdapter,
  TanStackAdapter,
  RechartsLegacyAdapter,
  EChartsAdapter,
  TradingViewAdapter,
} from "@/visualization/adapters";

import {
  KPIWidget,
  KPIGridWidget,
  KPIStripWidget,
  KPIComparisonWidget,
  mockKPIs,
  portfolioValueKPI,
  riskScoreKPI,
} from "@/analytics/widgets";

import type { VisualizationConfiguration, ChartData, TableData, HierarchyData } from "@/visualization/types";

const reactAdapter = new ReactComponentsAdapter();
const tanstackAdapter = new TanStackAdapter();
const rechartsAdapter = new RechartsLegacyAdapter();
const echartsAdapter = new EChartsAdapter();
const tradingViewAdapter = new TradingViewAdapter();

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section className="mb-10">
      <h2 className="text-xl font-semibold">{title}</h2>
      {subtitle && <p className="mb-3 text-sm text-muted-foreground">{subtitle}</p>}
      <div className="mt-3">{children}</div>
    </section>
  );
}

function Grid({ children }: { children: React.ReactNode }) {
  return <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">{children}</div>;
}

const sampleChart: ChartData = {
  categories: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
  series: [
    { key: "a", name: "Series A", data: [10, 20, 15, 30, 25, 40], color: "#3b82f6" },
    { key: "b", name: "Series B", data: [5, 15, 25, 20, 35, 30], color: "#22c55e" },
  ],
};

const sampleTable: TableData = {
  columns: [
    { key: "name", header: "Name", sortable: true },
    { key: "value", header: "Value", align: "right" },
    { key: "change", header: "Change", align: "right" },
  ],
  rows: [
    { name: "Alpha", value: 120, change: "+2.1%" },
    { name: "Beta", value: 88, change: "-0.4%" },
    { name: "Gamma", value: 142, change: "+1.8%" },
  ],
  total: 3,
};

const sampleHierarchy: HierarchyData = {
  id: "root",
  name: "Root",
  level: "group",
  metrics: { score: 100 },
  children: [
    {
      id: "c1",
      name: "Child One",
      level: "subgroup",
      parentId: "root",
      metrics: { score: 60 },
      children: [{ id: "c1a", name: "Leaf A", level: "leaf", parentId: "c1", metrics: { score: 30 } }],
    },
    { id: "c2", name: "Child Two", level: "subgroup", parentId: "root", metrics: { score: 40 } },
  ],
};

function cfg(primitive: VisualizationConfiguration["primitive"], adapter: string, title?: string): VisualizationConfiguration {
  return { primitive, adapter: adapter as VisualizationConfiguration["adapter"], data: {}, options: { title } };
}

export default function VisualizationPrimitivesShowcase() {
  const commonProps = { loading: false, error: null } as const;

  return (
    <main className="mx-auto max-w-6xl px-6 py-10">
      <header className="mb-10">
        <h1 className="text-3xl font-bold tracking-tight">Visualization Primitives — Showcase</h1>
        <p className="mt-2 text-muted-foreground">
          Domain-agnostic primitives rendered through pluggable visualization adapters. No business logic, no API.
        </p>
      </header>

      <Section title="Cards" subtitle="Adapter: react">
        <Grid>
          <VisualizationContainer>
            <MetricCardPrimitive {...commonProps} data={{ label: "Metric", value: 42 }} config={cfg("metric-card", "react", "Metric Card")} adapter={reactAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <KPIGridPrimitive {...commonProps} data={[{ label: "A", value: 1 }, { label: "B", value: 2 }]} config={cfg("kpi-grid", "react", "KPI Grid")} adapter={reactAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <SummaryStripPrimitive {...commonProps} data={[{ label: "Items", value: 9 }]} config={cfg("summary-strip", "react", "Summary Strip")} adapter={reactAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <StatusCardPrimitive {...commonProps} data={{ status: "ok", detail: "Nominal" }} config={cfg("status-card", "react", "Status Card")} adapter={reactAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <ValueComparisonPrimitive {...commonProps} data={{ current: 10, previous: 8 }} config={cfg("value-comparison", "react", "Value Comparison")} adapter={reactAdapter} />
          </VisualizationContainer>
        </Grid>
      </Section>

      <Section title="Tables" subtitle="Adapter: tanstack">
        <Grid>
          <VisualizationContainer>
            <DataTablePrimitive {...commonProps} data={sampleTable} config={cfg("data-table", "tanstack", "Data Table")} adapter={tanstackAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <HierarchyTablePrimitive {...commonProps} data={sampleHierarchy} config={cfg("hierarchy-table", "tanstack", "Hierarchy Table")} adapter={tanstackAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <TreeTablePrimitive {...commonProps} data={sampleHierarchy} config={cfg("tree-table", "tanstack", "Tree Table")} adapter={tanstackAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <MatrixTablePrimitive {...commonProps} data={sampleTable} config={cfg("matrix-table", "tanstack", "Matrix Table")} adapter={tanstackAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <RankingTablePrimitive {...commonProps} data={sampleTable} config={cfg("ranked-table", "tanstack", "Ranking Table")} adapter={tanstackAdapter} />
          </VisualizationContainer>
        </Grid>
      </Section>

      <Section title="Charts — Recharts" subtitle="Adapter: recharts-legacy">
        <Grid>
          <VisualizationContainer>
            <LineChartPrimitive {...commonProps} data={sampleChart} config={cfg("line-chart", "recharts-legacy", "Line Chart")} adapter={rechartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <AreaChartPrimitive {...commonProps} data={sampleChart} config={cfg("area-chart", "recharts-legacy", "Area Chart")} adapter={rechartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <BarChartPrimitive {...commonProps} data={sampleChart} config={cfg("bar-chart", "recharts-legacy", "Bar Chart")} adapter={rechartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <SparklinePrimitive {...commonProps} data={sampleChart} config={cfg("sparkline", "recharts-legacy", "Sparkline")} adapter={rechartsAdapter} />
          </VisualizationContainer>
        </Grid>
      </Section>

      <Section title="Charts — ECharts" subtitle="Adapter: echarts">
        <Grid>
          <VisualizationContainer>
            <StackedBarPrimitive {...commonProps} data={sampleChart} config={cfg("stacked-bar-chart", "echarts", "Stacked Bar")} adapter={echartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <GroupedBarPrimitive {...commonProps} data={sampleChart} config={cfg("grouped-bar-chart", "echarts", "Grouped Bar")} adapter={echartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <HeatmapPrimitive {...commonProps} data={sampleChart} config={cfg("heatmap", "echarts", "Heatmap")} adapter={echartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <TreemapPrimitive {...commonProps} data={sampleHierarchy} config={cfg("treemap", "echarts", "Treemap")} adapter={echartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <ScatterPrimitive {...commonProps} data={sampleChart} config={cfg("scatter-plot", "echarts", "Scatter")} adapter={echartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <DistributionPrimitive {...commonProps} data={sampleChart} config={cfg("distribution-chart", "echarts", "Distribution")} adapter={echartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <GaugePrimitive {...commonProps} data={{ value: 72 }} config={cfg("gauge", "echarts", "Gauge")} adapter={echartsAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <TimelinePrimitive {...commonProps} data={sampleChart} config={cfg("timeline", "echarts", "Timeline")} adapter={echartsAdapter} />
          </VisualizationContainer>
        </Grid>
      </Section>

      <Section title="Charts — TradingView" subtitle="Adapter: tradingview">
        <Grid>
          <VisualizationContainer>
            <CandlestickPrimitive {...commonProps} data={sampleChart} config={cfg("candlestick-chart", "tradingview", "Candlestick")} adapter={tradingViewAdapter} />
          </VisualizationContainer>
          <VisualizationContainer>
            <OHLCPrimitive {...commonProps} data={sampleChart} config={cfg("ohlc-chart", "tradingview", "OHLC")} adapter={tradingViewAdapter} />
          </VisualizationContainer>
        </Grid>
      </Section>

      <Section title="Layout Primitives" subtitle="Generic UI building blocks">
        <Grid>
          <VisualizationContainer>
            <VisualizationToolbar items={[{ key: "export", label: "Export", onClick: () => {} }, { key: "full", label: "Fullscreen", onClick: () => {} }]} />
          </VisualizationContainer>
          <VisualizationContainer>
            <VisualizationLegend items={[{ key: "a", label: "Series A", color: "#3b82f6" }, { key: "b", label: "Series B", color: "#22c55e" }]} />
          </VisualizationContainer>
          <VisualizationContainer>
            <VisualizationLoading label="Loading visualization..." />
          </VisualizationContainer>
          <VisualizationContainer>
            <VisualizationEmpty message="No data available" />
          </VisualizationContainer>
          <VisualizationContainer>
            <VisualizationError message="Failed to render" detail="Adapter returned null" />
          </VisualizationContainer>
          <VisualizationContainer>
            <VisualizationTooltip visible content={<span>Tooltip content</span>} x={0} y={0} />
          </VisualizationContainer>
        </Grid>
      </Section>

      <Section title="States" subtitle="Loading and error delegation">
        <Grid>
          <VisualizationContainer>
            <MetricCardPrimitive loading data={null} config={cfg("metric-card", "react")} adapter={reactAdapter} error={null} />
          </VisualizationContainer>
          <VisualizationContainer>
            <MetricCardPrimitive loading={false} data={null} config={cfg("metric-card", "react")} adapter={reactAdapter} error="Something went wrong" />
          </VisualizationContainer>
        </Grid>
      </Section>

      <Section
        title="KPI Widget Framework"
        subtitle="First Analytics Widget — composes primitives, no visualization library imported directly"
      >
        <div className="space-y-8">
          <div>
            <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Single KPI</h3>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
              <KPIWidget config={portfolioValueKPI} onRefresh={() => {}} onNavigate={() => {}} />
              <KPIWidget config={riskScoreKPI} display="status" />
              <KPIWidget config={mockKPIs[2]} />
            </div>
          </div>

          <div>
            <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Responsive KPI Grid</h3>
            <KPIGridWidget items={mockKPIs} />
          </div>

          <div>
            <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Horizontal KPI Strip (cards)</h3>
            <KPIStripWidget items={mockKPIs} variant="cards" />
          </div>

          <div>
            <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Dashboard Summary Strip</h3>
            <KPIStripWidget items={mockKPIs} variant="summary" />
          </div>

          <div>
            <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Comparison KPI</h3>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
              <KPIComparisonWidget config={portfolioValueKPI} />
              <KPIComparisonWidget config={riskScoreKPI} />
              <KPIComparisonWidget config={mockKPIs[6]} />
            </div>
          </div>

          <div>
            <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Widget States</h3>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
              <KPIWidget config={portfolioValueKPI} state={{ loading: true }} />
              <KPIWidget config={portfolioValueKPI} state={{ error: "Failed to load" }} />
              <KPIWidget config={{ ...portfolioValueKPI, value: null }} state={{ empty: true }} />
              <KPIWidget config={portfolioValueKPI} state={{ disabled: true }} />
            </div>
          </div>
        </div>
      </Section>
    </main>
  );
}
