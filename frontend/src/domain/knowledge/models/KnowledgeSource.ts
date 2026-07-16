// Provenance of a knowledge object: which engine produced it and which
// upstream domain object it interprets.
export interface KnowledgeSource {
  engine: string; // e.g. "knowledge-engine"
  objectType?: string; // e.g. "TradingSignal"
  objectId?: string;
}
