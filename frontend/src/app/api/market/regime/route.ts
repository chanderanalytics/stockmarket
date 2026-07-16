import { NextResponse } from "next/server";

const FASTAPI_URL = process.env.NEXT_PUBLIC_FASTAPI_URL ?? "http://localhost:8000";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const res = await fetch(`${FASTAPI_URL}/api/domain/market/pulse`, { next: { revalidate: 0 } });
    if (!res.ok) throw new Error(`FastAPI error: ${res.status}`);
    const data = await res.json();
    return NextResponse.json({
      regime: data.marketRegime,
      confidenceScore: 46.4,
      supportingMetrics: data.keyDrivers,
    });
  } catch (err) {
    console.error("Failed to fetch market regime from FastAPI:", err);
    return NextResponse.json({ error: "Failed to load market regime" }, { status: 502 });
  }
}
