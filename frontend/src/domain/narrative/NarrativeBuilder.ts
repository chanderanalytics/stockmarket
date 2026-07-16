import type { Narrative } from "./Narrative";
import { renderTemplate, type NarrativeTemplate } from "./NarrativeTemplate";

// NarrativeBuilder — assembles a Narrative object, applies a template, and
// records the related domain objects for traceability.
export class NarrativeBuilder {
  static build(input: {
    id: string;
    kind: Narrative["kind"];
    title: string;
    template?: NarrativeTemplate;
    vars?: Record<string, unknown>;
    body?: string;
    relatedObjects?: string[];
  }): Narrative {
    const body = input.body ?? (input.template ? renderTemplate(input.template, input.vars ?? {}) : "");
    return {
      id: input.id,
      timestamp: new Date().toISOString(),
      kind: input.kind,
      title: input.title,
      body,
      relatedObjects: input.relatedObjects ?? [],
    };
  }
}
