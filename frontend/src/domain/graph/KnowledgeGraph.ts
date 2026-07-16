import type { KnowledgeContext } from "../knowledge/models/KnowledgeContext";
import type { InvestmentThesis } from "../thesis/InvestmentThesis";

export type GraphNodeType = "market" | "sector" | "industry" | "stock" | "signal" | "thesis";
export type ImpactLevel = "high" | "medium" | "low";

export interface GraphNode {
  id: string;
  type: GraphNodeType;
  label: string;
  weight?: number; // directional importance, -1..1
}

export interface GraphEdge {
  from: string;
  to: string;
  relation: string;
}

export interface ImpactResult {
  nodeId: string;
  type: GraphNodeType;
  label: string;
  impact: ImpactLevel;
}

// KnowledgeGraph — links Market → Sector → Industry → Stock → Signal → Thesis.
// Enables traversal, dependency mapping and impact analysis. Pure data
// structure; built deterministically from domain objects.
export class KnowledgeGraph {
  nodes = new Map<string, GraphNode>();
  edges: GraphEdge[] = [];
  private adj = new Map<string, string[]>();

  addNode(node: GraphNode): this {
    this.nodes.set(node.id, node);
    if (!this.adj.has(node.id)) this.adj.set(node.id, []);
    return this;
  }

  addEdge(edge: GraphEdge): this {
    this.edges.push(edge);
    if (!this.adj.has(edge.from)) this.adj.set(edge.from, []);
    this.adj.get(edge.from)!.push(edge.to);
    return this;
  }

  static build(ctx: KnowledgeContext, theses: InvestmentThesis[]): KnowledgeGraph {
    const g = new KnowledgeGraph();
    g.addNode({ id: ctx.pulse.id, type: "market", label: `Market (${ctx.regime.regime})`, weight: ctx.decision.deployNewMoney ? 1 : -1 });

    const industryByKey = new Map<string, string>();
    for (const sector of ctx.sectors) {
      g.addNode({ id: sector.id, type: "sector", label: sector.sector, weight: (sector.relativeStrength - 50) / 50 });
      g.addEdge({ from: ctx.pulse.id, to: sector.id, relation: "contains" });
    }

    const stockBySymbol = new Map(ctx.stocks.map((s) => [s.symbol, s]));
    for (const sig of ctx.signals) {
      const stock = stockBySymbol.get(sig.symbol);
      if (!stock) continue;
      const industryKey = `${stock.sector}:${stock.industry}`;
      let industryId = industryByKey.get(industryKey);
      if (!industryId) {
        industryId = `industry-${industryKey}`;
        industryByKey.set(industryKey, industryId);
        g.addNode({ id: industryId, type: "industry", label: stock.industry ?? "n/a" });
        const sec = ctx.sectors.find((s) => s.sector === stock.sector);
        if (sec) g.addEdge({ from: sec.id, to: industryId, relation: "contains" });
      }
      g.addNode({ id: stock.id, type: "stock", label: stock.symbol, weight: (sig.confidenceScore - 50) / 50 });
      g.addEdge({ from: industryId, to: stock.id, relation: "contains" });
      g.addNode({ id: sig.id, type: "signal", label: `${stock.symbol} ${sig.rating}`, weight: (sig.confidenceScore - 50) / 50 });
      g.addEdge({ from: stock.id, to: sig.id, relation: "produces" });
    }

    for (const t of theses) {
      g.addNode({ id: t.id, type: "thesis", label: `Thesis ${t.symbol}`, weight: (t.confidence - 50) / 50 });
      const sig = ctx.signals.find((s) => s.symbol === t.symbol);
      if (sig) g.addEdge({ from: sig.id, to: t.id, relation: "supports" });
    }
    return g;
  }

  // All nodes reachable from `id` (descendants), with relation path.
  getRelated(id: string): GraphNode[] {
    const seen = new Set<string>([id]);
    const queue = [...(this.adj.get(id) ?? [])];
    const result: GraphNode[] = [];
    while (queue.length) {
      const cur = queue.shift()!;
      if (seen.has(cur)) continue;
      seen.add(cur);
      const node = this.nodes.get(cur);
      if (node) result.push(node);
      queue.push(...(this.adj.get(cur) ?? []));
    }
    return result;
  }

  traverse(id: string): string[] {
    return this.getRelated(id).map((n) => n.id);
  }

  // Dependency mapping: everything a node depends on (ancestors).
  dependencies(id: string): GraphNode[] {
    const parents = new Map<string, string[]>();
    for (const e of this.edges) {
      if (!parents.has(e.to)) parents.set(e.to, []);
      parents.get(e.to)!.push(e.from);
    }
    const seen = new Set<string>([id]);
    const queue = [...(parents.get(id) ?? [])];
    const result: GraphNode[] = [];
    while (queue.length) {
      const cur = queue.shift()!;
      if (seen.has(cur)) continue;
      seen.add(cur);
      const node = this.nodes.get(cur);
      if (node) result.push(node);
      queue.push(...(parents.get(cur) ?? []));
    }
    return result;
  }

  // Impact analysis: a change at `rootId` propagates to descendants. The
  // impact decays with depth and scales with each node's weight.
  impactAnalysis(rootId: string, change: number): ImpactResult[] {
    const results: ImpactResult[] = [];
    const queue: { id: string; depth: number }[] = [{ id: rootId, depth: 0 }];
    const seen = new Set<string>([rootId]);
    while (queue.length) {
      const { id, depth } = queue.shift()!;
      const node = this.nodes.get(id);
      if (!node) continue;
      const decay = Math.pow(0.7, depth);
      const magnitude = Math.abs(change) * decay * (Math.abs(node.weight ?? 0.5) + 0.3);
      const impact: ImpactLevel = magnitude > 0.6 ? "high" : magnitude > 0.3 ? "medium" : "low";
      if (depth > 0) results.push({ nodeId: id, type: node.type, label: node.label, impact });
      for (const next of this.adj.get(id) ?? []) {
        if (!seen.has(next)) {
          seen.add(next);
          queue.push({ id: next, depth: depth + 1 });
        }
      }
    }
    return results.sort((a, b) => (a.impact === b.impact ? 0 : a.impact === "high" ? -1 : b.impact === "high" ? 1 : a.impact === "medium" ? -1 : 1));
  }
}
