import { NextResponse } from "next/server";

const FASTAPI_URL = process.env.NEXT_PUBLIC_FASTAPI_URL ?? "http://localhost:8000";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const target = `${FASTAPI_URL}/api/volume-profile?${searchParams.toString()}`;
    const res = await fetch(target, { next: { revalidate: 0 } });
    if (!res.ok) throw new Error(`FastAPI error: ${res.status}`);
    const data = await res.json();
    return NextResponse.json(data);
  } catch (err) {
    console.error("Failed to fetch volume-profile from FastAPI:", err);
    return NextResponse.json({ error: "Failed to load volume profile" }, { status: 502 });
  }
}
