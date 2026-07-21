"use client";

// Thin fetch-based API client. No axios dependency; works in the browser and
// during Next.js client-side navigation. Reads an auth token from localStorage.

const BASE_URL =
  process.env.NEXT_PUBLIC_FASTAPI_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  "http://localhost:8001";

function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem("auth_token");
}

export class ApiError extends Error {
  status: number;
  payload: unknown;
  constructor(status: number, message: string, payload?: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.payload = payload;
  }
}

type RequestOptions = {
  params?: Record<string, unknown>;
  signal?: AbortSignal;
  headers?: Record<string, string>;
};

async function request<T>(method: string, path: string, body?: unknown, opts: RequestOptions = {}): Promise<T> {
  const url = new URL(`${BASE_URL}${path}`, typeof window === "undefined" ? "http://localhost" : window.location.origin);
  if (opts.params) {
    Object.entries(opts.params).forEach(([k, v]) => {
      if (v === undefined || v === null || v === "") return;
      if (Array.isArray(v)) {
        v.forEach((item) => {
          if (item !== undefined && item !== null && item !== "") {
            url.searchParams.append(k, String(item));
          }
        });
      } else {
        url.searchParams.set(k, String(v));
      }
    });
  }

  const headers: Record<string, string> = { "Content-Type": "application/json", ...opts.headers };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(url.toString(), {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
    signal: opts.signal,
  });

  if (!res.ok) {
    let payload: unknown;
    try {
      const raw = await res.text();
      payload = raw;
      try {
        payload = JSON.parse(raw);
      } catch {
        // keep as text
      }
    } catch {
      payload = null;
    }
    const message =
      (payload && typeof payload === "object" && "message" in payload && (payload as any).message) ||
      res.statusText;
    throw new ApiError(res.status, String(message), payload);
  }

  if (res.status === 204) return undefined as T;
  const jsonPayload = await res.json();
  return jsonPayload as T;
}

export const api = {
  get: <T>(path: string, opts?: RequestOptions) => request<T>("GET", path, undefined, opts),
  post: <T>(path: string, body?: unknown, opts?: RequestOptions) => request<T>("POST", path, body, opts),
  put: <T>(path: string, body?: unknown, opts?: RequestOptions) => request<T>("PUT", path, body, opts),
  patch: <T>(path: string, body?: unknown, opts?: RequestOptions) => request<T>("PATCH", path, body, opts),
  del: <T>(path: string, opts?: RequestOptions) => request<T>("DELETE", path, undefined, opts),
};
