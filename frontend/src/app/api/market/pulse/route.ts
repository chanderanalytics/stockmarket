import { NextResponse } from "next/server";

const FASTAPI_URL = process.env.NEXT_PUBLIC_FASTAPI_URL ?? "http://localhost:8000";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const res = await fetch(`${FASTAPI_URL}/api/domain/market/pulse`, { next: { revalidate: 0 } });
    if (!res.ok) throw new Error(`FastAPI error: ${res.status}`);
    const data = await res.json();
    return NextResponse.json(data);
  } catch (err) {
    console.error("Failed to fetch market pulse from FastAPI:", err);
    return NextResponse.json({ error: "Failed to load market pulse" }, { status: 502 });
  }
}
