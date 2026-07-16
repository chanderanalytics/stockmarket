// Lightweight template system: a template is a string with {token} placeholders
// plus a list of sentence fragments that can be conditionally included.
export interface NarrativeTemplate {
  id: string;
  kind: string;
  // Ordered rules; each yields a sentence when its `when` passes.
  rules: {
    when: (vars: Record<string, unknown>) => boolean;
    text: string; // may contain {token}
  }[];
  fallback: string;
}

export function renderTemplate(tpl: NarrativeTemplate, vars: Record<string, unknown>): string {
  const sentences: string[] = [];
  for (const rule of tpl.rules) {
    if (rule.when(vars)) sentences.push(fill(rule.text, vars));
  }
  return sentences.length ? sentences.join(" ") : fill(tpl.fallback, vars);
}

function fill(text: string, vars: Record<string, unknown>): string {
  return text.replace(/\{(\w+)\}/g, (_, key) => {
    const v = vars[key];
    return v === undefined || v === null ? "" : String(v);
  });
}
