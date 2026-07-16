# Market Knowledge Runtime

> **Rule:** The Market Knowledge Runtime does not use LLMs. Every knowledge object, explanation, narrative, and investment thesis is generated deterministically from structured domain models and rule-based interpretation. LLMs are consumers of the knowledge runtime — not part of it.

---

## Architecture

```
Market Data
      ↓
Indicator Engine
      ↓
Breadth Engine
      ↓
Sector Engine
      ↓
Probability Engine
      ↓
Signal Engine
      ↓
Decision Engine
      ↓
══════════════════════════════════
Market Knowledge Runtime
══════════════════════════════════
Knowledge Engine
Evidence Engine
Narrative Engine
Investment Thesis Engine
Research Engine
Insight Engine
Alert Engine
Explanation Engine
Knowledge Graph
══════════════════════════════════
API
══════════════════════════════════
Frontend
AI
Alerts
Reports
Notifications
```

The Market Knowledge Runtime sits between the Market Intelligence Runtime and every consumer. It never recalculates indicators. It interprets, connects, explains, and summarizes existing results into reusable, canonical knowledge objects.

---

## Directory Structure

```
frontend/src/domain/
├── knowledge/
│   ├── KnowledgeEngine.ts
│   ├── models/
│   │   ├── Knowledge.ts
│   │   ├── KnowledgeCategory.ts
│   │   ├── KnowledgeSeverity.ts
│   │   ├── KnowledgeContext.ts
│   │   └── KnowledgeSource.ts
│   └── services/
│       ├── KnowledgeBuilder.ts
│       ├── KnowledgeClassifier.ts
│       └── KnowledgeAggregator.ts
├── evidence/
│   ├── EvidenceEngine.ts
│   ├── Evidence.ts
│   └── EvidenceBuilder.ts
├── narrative/
│   ├── NarrativeEngine.ts
│   ├── NarrativeBuilder.ts
│   ├── NarrativeTemplate.ts
│   └── Narrative.ts
├── thesis/
│   ├── InvestmentThesisEngine.ts
│   └── InvestmentThesis.ts
├── insight/
│   ├── InsightEngine.ts
│   └── Insight.ts
├── alert/
│   ├── AlertEngine.ts
│   └── Alert.ts
├── explanation/
│   ├── ExplanationEngine.ts
│   └── Explanation.ts
├── graph/
│   └── KnowledgeGraph.ts
└── services/
    └── knowledge-runtime.service.ts
```

---

## Knowledge Flow

1. **Input Assembly** — `KnowledgeRuntime.context()` gathers outputs from the Market Intelligence Runtime: `MarketPulse`, `MarketBreadth`, `MarketRegime`, `SectorSnapshot[]`, `StockSnapshot[]`, `TradingSignal[]`, `DecisionSummary`, `TradingOpportunity[]`, `PortfolioSummary`, `WatchlistSummary`.

2. **Evidence Generation** — `EvidenceEngine.compute()` converts raw indicator/breadth/probability/sector/signal outputs into a flat list of `Evidence` objects. Every signal, decision, knowledge item, and investment thesis carries evidence.

3. **Knowledge Generation** — `KnowledgeEngine.compute()` transforms assembled context into `Knowledge[]` via rule-based interpreters:
   - `fromPulse` → market sentiment knowledge
   - `fromBreadth` → breadth interpretation
   - `fromRegime` → regime classification
   - `fromSectors` → sector leadership
   - `fromSignals` → per-signal interpretation
   - `fromDecision` → capital allocation stance
   - `fromPortfolio` → portfolio health
   - `fromWatchlist` → watchlist summary
   - `fromOpportunities` → opportunity descriptions

4. **Narrative Generation** — `NarrativeEngine` builds prose summaries from structured knowledge:
   - `dailyMarket(ctx)` → market summary
   - `sector(snapshot)` → sector summary
   - `stock(snapshot, trend, momentum, signal)` → stock summary
   - `portfolio(summary)` → portfolio summary

5. **Thesis Generation** — `InvestmentThesisEngine.build()` produces a complete, evidence-backed thesis for a single opportunity.

6. **Insight Generation** — `InsightEngine.compute()` produces concise, independent observations categorized as bullish, bearish, neutral, opportunity, warning, risk, momentum, breadth, sector, portfolio, or research.

7. **Alert Generation** — `AlertEngine.compute()` converts knowledge changes into typed alerts: market, sector, stock, watchlist, portfolio, risk, opportunity.

8. **Explanation** — `ExplanationEngine` answers "Why?" for any signal, decision, or knowledge item by referencing its supporting evidence.

9. **Knowledge Graph** — `KnowledgeGraph.build()` links Market → Sector → Industry → Stock → Signal → Thesis. Supports traversal, dependency mapping, and impact analysis.

10. **Orchestration** — `KnowledgeRuntime` exposes view methods (`marketView`, `sectorView`, `stockView`, `portfolioView`, `opportunities`) that wire all engines together.

---

## Evidence Flow

Every conclusion in the platform must be explainable. The `Evidence` model is the atomic unit of explainability:

```ts
interface Evidence {
  id: string;
  metric: string;        // e.g. "Breadth", "RSI", "Volume"
  observation: string;   // human-readable finding
  weight: number;        // contribution to confidence, -1..1
  confidence: number;    // 0-100
  reason: string;        // why this observation matters
  importance: number;    // 0-100
  supportingData?: Record<string, unknown>;
  status: "confirmed" | "divergent" | "weak";
}
```

Rules:
- Every `TradingSignal` contains `SignalEvidence[]`.
- Every `DecisionSummary` contains a `thesis: string[]` derived from evidence.
- Every `Knowledge` item carries `supportingEvidence: Evidence[]`.
- Every `InvestmentThesis` carries `supportingEvidence: Evidence[]`.
- Every `Explanation` references the evidence that supports its conclusion.

The `EvidenceEngine` synthesizes evidence from:
- Breadth metrics (participation, advance/decline)
- Probability models (upside/downside, reward/risk)
- Sector leadership (relative strength, participation)
- Signal evidence (indicator weights, confidence contributions)

---

## Narrative Generation

Narratives are generated from structured knowledge, never from raw indicators.

```ts
interface Narrative {
  id: string;
  kind: "market" | "sector" | "stock" | "portfolio" | "research";
  title: string;
  body: string; // multi-paragraph prose
  relatedObjects: string[];
}
```

### Templates

Narratives use `NarrativeTemplate` blocks composed by `NarrativeBuilder`:

- **Market Summary** — sentiment, breadth trend, regime, leading/lagging sectors, participation quality.
- **Sector Summary** — rank, relative strength, participation, momentum, leadership status.
- **Stock Summary** — trend direction, momentum state, signal rating, probability outlook, risk.
- **Portfolio Summary** — exposure, cash, P&L, top/worst sectors, diversification.
- **Research Summary** — bull/bear cases, key metrics, consensus, upside, confidence.

### Example

```
The market remains in a healthy uptrend.
Breadth improved for the third consecutive session.
Capital Goods continues to lead while Financials have weakened slightly.
Overall participation remains strong and risk is moderate.
```

---

## Thesis Generation

`InvestmentThesisEngine.build()` produces a complete thesis for one opportunity:

```ts
interface InvestmentThesis {
  id: string;
  symbol: string;
  marketContext: string;
  sectorContext: string;
  trend: string;
  momentum: string;
  probability: string;
  risk: string;
  holdingPeriod: string;
  catalysts: string[];
  warnings: string[];
  supportingEvidence: Evidence[];
  confidence: number;      // 0-100
  suggestedAction: "accumulate" | "hold" | "watch" | "reduce" | "avoid";
  entryBias: string;
  exitConsiderations: string;
}
```

The thesis is built deterministically from:
- `StockSnapshot` + `StockTrend` + `StockMomentum`
- `TradingSignal` (rating, confidence, risk, evidence)
- `SectorSnapshot` (leadership, relative strength)
- `MarketRegime` (regime, confidence)
- `ProbabilityAnalysis` (upside probability, reward/risk)

### Example

```
Stock: RELIANCE
Suggested Action: Accumulate
Confidence: 84%
Risk: Low
Holding Period: 7–15 Days
Catalysts:
  • Sector leadership
  • Strong breadth
  • Improving momentum
  • Above 50 DMA
Warnings:
  • Volume slightly below average
```

---

## Insight Generation

`InsightEngine.compute()` produces reusable, UI-independent observations:

```ts
interface Insight {
  id: string;
  title: string;
  description: string;
  category: InsightCategory;
  priority: InsightPriority;
  confidence: number;      // 0-100
  relatedObjects: string[];
}
```

Categories:
- `bullish`, `bearish`, `neutral`
- `opportunity`, `warning`, `risk`
- `momentum`, `breadth`, `sector`
- `portfolio`, `research`

### Example

```
Insight: Technology participation improved significantly.
Category: Sector
Priority: High
Confidence: 88%
```

---

## Alert Generation

`AlertEngine.compute()` converts knowledge changes into typed alert objects. Alerts contain no UI — consumers (push, email, in-app) render them.

```ts
interface Alert {
  id: string;
  type: "market" | "sector" | "stock" | "watchlist" | "portfolio" | "risk" | "opportunity";
  title: string;
  message: string;
  importance: number;      // 0-100
  severity: "info" | "warning" | "critical";
  suggestedAction: string;
  relatedObjects: string[];
}
```

### Example

```
Alert: Breadth deteriorated.
Importance: High
Severity: Warning
Suggested Action: Reduce exposure.
```

---

## Explanation Engine

`ExplanationEngine` answers "Why?" for any result:

```ts
interface Explanation {
  id: string;
  targetId: string;        // id of signal / knowledge / decision
  targetType: string;      // e.g. "TradingSignal"
  summary: string;         // e.g. "BUY"
  detailedReason: string;
  supportingEvidence: Evidence[];
  confidence: number;      // 0-100
  references: string[];    // ids of related domain objects
}
```

### Example

```
Summary: BUY
Why?
  • Momentum improving (+0.82)
  • Probability 82%
  • Sector leader
  • Breadth strong
  • Market healthy
  • Risk acceptable
```

---

## Knowledge Graph

`KnowledgeGraph` links related knowledge together:

```ts
interface GraphNode {
  id: string;
  type: "market" | "sector" | "industry" | "stock" | "signal" | "thesis";
  label: string;
  weight?: number;         // -1..1
}

interface GraphEdge {
  from: string;
  to: string;
  relation: string;
}
```

### Relationships

```
Market
  ↓ contains
Sector
  ↓ contains
Industry
  ↓ contains
Stock
  ↓ produces
Signal
  ↓ supports
Thesis
```

### Operations

- `traverse(id)` — all descendants reachable from a node
- `dependencies(id)` — all ancestors a node depends on
- `impactAnalysis(rootId, change)` — propagates impact from a change, decaying with depth

### Example

```
Market: Bullish
  ↓ contains
Sector: Capital Goods
  ↓ contains
Industry: Capital Goods - Electrical Equipment
  ↓ contains
Stock: L&T
  ↓ produces
Signal: Strong Buy
  ↓ supports
Thesis: Accumulate
```

---

## API Reference

All endpoints return canonical knowledge models. No raw indicators. No raw SQL.

### `GET /api/knowledge/market`

Returns the market knowledge view.

```ts
{
  pulse: MarketPulse;
  breadth: MarketBreadth;
  regime: MarketRegime;
  decision: DecisionSummary;
  knowledge: Knowledge[];
  narrative: Narrative;
  insights: Insight[];
  alerts: Alert[];
}
```

### `GET /api/knowledge/sectors`

Returns sector knowledge views.

```ts
[
  {
    snapshot: SectorSnapshot;
    knowledge: Knowledge[];
    narrative: Narrative;
  }
]
```

### `GET /api/knowledge/stocks/{symbol}`

Returns stock knowledge view for a symbol.

```ts
{
  snapshot: StockSnapshot;
  trend: StockTrend;
  momentum: StockMomentum;
  probability: ProbabilityAnalysis;
  signal: TradingSignal;
  thesis: InvestmentThesis;
  knowledge: Knowledge[];
  narrative: Narrative;
  explanation: Explanation;
}
```

### `GET /api/knowledge/portfolio`

Returns portfolio knowledge view.

```ts
{
  summary: PortfolioSummary;
  knowledge: Knowledge[];
  narrative: Narrative;
}
```

### `GET /api/knowledge/opportunities`

Returns opportunities with knowledge.

```ts
{
  opportunities: TradingOpportunity[];
  knowledge: Knowledge[];
}
```

### `GET /api/knowledge/alerts`

Returns generated alerts.

```ts
Alert[]
```

### `GET /api/knowledge/thesis/{symbol}`

Returns investment thesis for a symbol.

```ts
InvestmentThesis
```

### `GET /api/knowledge/explanations/{id}`

Returns explanation for a signal, knowledge, or decision ID.

```ts
Explanation
```

Returns `404` if the ID is not found.

---

## Knowledge Context

`KnowledgeContext` is the assembled bundle the Knowledge Engine interprets:

```ts
interface KnowledgeContext {
  pulse: MarketPulse;
  breadth: MarketBreadth;
  regime: MarketRegime;
  sectors: SectorSnapshot[];
  stocks: StockSnapshot[];
  signals: TradingSignal[];
  decision: DecisionSummary;
  opportunities: TradingOpportunity[];
  portfolio?: PortfolioSummary;
  watchlist?: WatchlistSummary;
}
```

Built by `KnowledgeRuntime.context()` from Market Intelligence Runtime outputs.

---

## Knowledge Categories

```ts
type KnowledgeCategory =
  | "market"
  | "breadth"
  | "regime"
  | "sector"
  | "signal"
  | "decision"
  | "portfolio"
  | "watchlist"
  | "opportunity";
```

---

## Knowledge Severity

```ts
type KnowledgeSeverity = "info" | "warning" | "critical";
```

---

## Extension Guide

### Adding a new Knowledge category

1. Add the category to `KnowledgeCategory` in `models/KnowledgeCategory.ts`.
2. Add a `fromXxx` static method in `KnowledgeEngine`.
3. Call it from `KnowledgeEngine.compute()`.
4. Optionally add a narrative template in `NarrativeEngine`.

### Adding a new Alert type

1. Add the type to `AlertType` in `alert/Alert.ts`.
2. Add detection logic in `AlertEngine.compute()`.
3. The alert is automatically exposed via `/api/knowledge/alerts`.

### Adding a new Insight category

1. Add the category to `InsightCategory` in `insight/Insight.ts`.
2. Add generation logic in `InsightEngine.compute()`.

### Adding a new Graph node type

1. Add the type to `GraphNodeType` in `graph/KnowledgeGraph.ts`.
2. Add construction logic in `KnowledgeGraph.build()`.
3. Add edge relations as needed.

### Swapping the data source

Replace functions in `services/data-source.ts` with real DB/API queries. Nothing downstream in the Knowledge Runtime changes — that is the entire point of the layer.

---

## Examples

### Market View

```ts
const view = KnowledgeRuntime.marketView();
console.log(view.knowledge[0].title);    // "Market sentiment: bullish"
console.log(view.narrative.body);         // multi-paragraph market summary
console.log(view.alerts[0].title);        // "Breadth deteriorated"
```

### Stock View

```ts
const stock = KnowledgeRuntime.stockView("RELIANCE");
console.log(stock.thesis.suggestedAction); // "accumulate"
console.log(stock.explanation.summary);    // "BUY"
console.log(stock.narrative.body);         // stock-specific prose
```

### Sector View

```ts
const sectors = KnowledgeRuntime.sectorView();
sectors.forEach((s) => {
  console.log(s.snapshot.sector, s.knowledge[0]?.title);
});
```

### Graph Traversal

```ts
const graph = KnowledgeRuntime.graph();
const related = graph.traverse("market-pulse");
const deps = graph.dependencies("signal-RELIANCE");
const impact = graph.impactAnalysis("sector-Capital Goods", 0.8);
```

---

## Testing Strategy

### Unit Tests

- `KnowledgeEngine` — test each `fromXxx` method with known inputs, verify output `Knowledge` shape and content.
- `EvidenceEngine` — test evidence generation from breadth, sectors, signals.
- `NarrativeEngine` — test each narrative kind with mock context, verify prose structure.
- `InvestmentThesisEngine` — test thesis generation for buy, sell, watch, avoid ratings.
- `InsightEngine` — test insight categories and priorities.
- `AlertEngine` — test alert generation thresholds and severity classification.
- `ExplanationEngine` — test explanation generation for signals, decisions, knowledge.
- `KnowledgeGraph` — test node/edge construction, traversal, dependencies, impact analysis.

### Integration Tests

- `KnowledgeRuntime.marketView()` — verify all sub-views are present and typed.
- `KnowledgeRuntime.stockView(symbol)` — verify thesis, explanation, narrative are consistent with the same signal.
- API routes — hit each `/api/knowledge/*` endpoint, verify response shape and HTTP status.

### Property Tests

- Every `Knowledge` item produced by `KnowledgeEngine.compute()` must have `supportingEvidence.length > 0` or be explicitly flagged as fallback.
- Every `InvestmentThesis` must have `supportingEvidence.length > 0`.
- Every `Explanation` must reference the ID it explains.
- `KnowledgeGraph.build()` must produce a DAG (no cycles).

---

## Success Criteria

- Every decision produced by the platform is explainable.
- All market conclusions are represented as reusable knowledge objects rather than UI text.
- AI assistants, alerts, dashboards, and reports consume the same structured knowledge instead of duplicating logic.
- Investment theses are generated consistently from the same evidence and decision engines.
- The platform has a dedicated knowledge layer that sits between the Market Intelligence Runtime and every consumer (frontend, APIs, AI, notifications).
- No LLM is used inside the Market Knowledge Runtime. All outputs are deterministic and rule-based.
