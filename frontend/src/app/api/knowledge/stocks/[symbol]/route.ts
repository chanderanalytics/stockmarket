import { NextResponse } from "next/server";
import { KnowledgeRuntime } from "@/domain/services/knowledge-runtime.service";

export const dynamic = "force-dynamic";

export function GET(_req: Request, { params }: { params: Promise<{ symbol: string }> }) {
  return params.then(({ symbol }) => NextResponse.json(KnowledgeRuntime.stockView(symbol.toUpperCase())));
}
