import type { IndicatorResult } from "../types";
import type { IndicatorContext, IndicatorMeta, IndicatorName, IndicatorOutput } from "./types";
import { calculators } from "./calculators";

function validate(ctx: IndicatorContext): void {
  if (!ctx || ctx.closes.length === 0) throw new Error("IndicatorEngine: empty series");
  if (ctx.closes.length !== ctx.times.length) throw new Error("IndicatorEngine: closes/times length mismatch");
}

// IndicatorEngine — single entry point for every technical indicator.
// Pure computation only; no UI, no I/O.
export class IndicatorEngine {
  static compute(name: IndicatorName, ctx: IndicatorContext, params?: Record<string, number>): IndicatorOutput {
    validate(ctx);
    const calc = calculators[name];
    if (!calc) throw new Error(`IndicatorEngine: unknown indicator "${name}"`);
    const result: IndicatorResult = calc(ctx, params);
    return { ...result, name, params };
  }

  // Run a batch of indicators and return normalized outputs.
  static batch(metas: IndicatorMeta[], ctx: IndicatorContext): IndicatorOutput[] {
    validate(ctx);
    return metas.map((m) => this.compute(m.name, ctx, m.params));
  }

  static available(): IndicatorName[] {
    return Object.keys(calculators) as IndicatorName[];
  }
}
