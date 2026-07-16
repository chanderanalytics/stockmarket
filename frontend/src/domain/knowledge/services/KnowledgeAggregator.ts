import type { Knowledge } from "../models";

// KnowledgeAggregator — combines Knowledge from multiple engines, dedupes by
// id, and orders by importance so consumers (UI, AI, alerts) get a stable,
// prioritised view.
export class KnowledgeAggregator {
  static aggregate(lists: Knowledge[][]): Knowledge[] {
    const byId = new Map<string, Knowledge>();
    for (const list of lists) {
      for (const k of list) {
        const existing = byId.get(k.id);
        if (!existing) {
          byId.set(k.id, k);
        } else {
          // Merge evidence and keep the higher importance.
          byId.set(k.id, {
            ...k,
            importance: Math.max(existing.importance, k.importance),
            supportingEvidence: [...existing.supportingEvidence, ...k.supportingEvidence],
            relatedObjects: Array.from(new Set([...existing.relatedObjects, ...k.relatedObjects])),
          });
        }
      }
    }
    return Array.from(byId.values()).sort((a, b) => b.importance - a.importance);
  }
}
