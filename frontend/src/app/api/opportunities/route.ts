import { NextResponse } from "next/server";

const FASTAPI_URL = process.env.NEXT_PUBLIC_FASTAPI_URL ?? "http://localhost:8000";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const res = await fetch(`${FASTAPI_URL}/api/domain/signals`, { next: { revalidate: 0 } });
    if (!res.ok) throw new Error(`FastAPI error: ${res.status}`);
    const signals = await res.json();
    const opportunities = signals.filter((s: any) => ["strong_buy", "buy"].includes(s.rating));
    return NextResponse.json({ opportunities });
  } catch (err) {
    console.error("Failed to fetch opportunities from FastAPI:", err);
    return NextResponse.json({ error: "Failed to load opportunities" }, { status: 502 });
  }
}
