import { NextResponse } from "next/server";
import { KnowledgeRuntime } from "@/domain/services/knowledge-runtime.service";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json(KnowledgeRuntime.alerts());
}
