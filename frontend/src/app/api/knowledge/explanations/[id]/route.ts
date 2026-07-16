import { NextResponse } from "next/server";
import { KnowledgeRuntime } from "@/domain/services/knowledge-runtime.service";

export const dynamic = "force-dynamic";

export function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  return params.then(({ id }) => {
    const explanation = KnowledgeRuntime.explanation(id);
    if (!explanation) {
      return NextResponse.json({ error: "Explanation not found" }, { status: 404 });
    }
    return NextResponse.json(explanation);
  });
}
