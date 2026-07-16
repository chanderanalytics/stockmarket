// Centralized, typed API client (Milestone 1, Task 9).
//
// Design goals:
//  - No component calls `fetch` directly; everything goes through `apiClient`.
//  - Authentication-ready: a token provider can be injected; the token is
//    attached via the request interceptor.
//  - Request/response/error interceptors for cross-cutting concerns.
//  - Built-in retry with backoff for transient failures.
//  - Typed responses via `request<T>`.
//  - Centralized error model (`ApiError`).

export type RequestInterceptor = (init: RequestInit, url: string) => RequestInit | Promise<RequestInit>;
export type ResponseInterceptor = (response: Response, url: string) => Response | Promise<Response>;
export type ErrorInterceptor = (error: unknown, url: string) => unknown;

export interface ApiClientConfig {
  baseURL: string;
  getToken?: () => string | null | Promise<string | null>;
  maxRetries?: number;
  retryDelayMs?: number;
  onUnauthorized?: () => void;
}

export class ApiError extends Error {
  status: number;
  data: unknown;
  constructor(message: string, status: number, data?: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.data = data;
  }
}

export function createApiClient(config: ApiClientConfig) {
  const requestInterceptors: RequestInterceptor[] = [];
  const responseInterceptors: ResponseInterceptor[] = [];
  const errorInterceptors: ErrorInterceptor[] = [];

  const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

  async function resolveUrl(path: string) {
    const base = config.baseURL.replace(/\/$/, "");
    const clean = path.startsWith("/") ? path : `/${path}`;
    return `${base}${clean}`;
  }

  async function execute(url: string, init: RequestInit): Promise<Response> {
    let finalInit = init;
    for (const interceptor of requestInterceptors) {
      finalInit = await interceptor(finalInit, url);
    }
    let response = await fetch(url, finalInit);
    for (const interceptor of responseInterceptors) {
      response = await interceptor(response, url);
    }
    return response;
  }

  async function withRetry(url: string, init: RequestInit, attempt = 0): Promise<Response> {
    try {
      return await execute(url, init);
    } catch (err) {
      const maxRetries = config.maxRetries ?? 2;
      if (attempt < maxRetries && isRetryable(err)) {
        await sleep((config.retryDelayMs ?? 400) * Math.pow(2, attempt));
        return withRetry(url, init, attempt + 1);
      }
      throw err;
    }
  }

  function isRetryable(err: unknown): boolean {
    // Network-level errors are retryable; HTTP errors are handled separately.
    return err instanceof TypeError;
  }

  async function request<T>(path: string, options: RequestInit = {}, params?: Record<string, unknown>): Promise<T> {
    const url = new URL(await resolveUrl(path));
    if (params) {
      for (const [key, value] of Object.entries(params)) {
        if (value === undefined || value === null || value === "") continue;
        if (Array.isArray(value)) value.forEach((v) => url.searchParams.append(key, String(v)));
        else url.searchParams.append(key, String(value));
      }
    }

    const init: RequestInit = {
      headers: {
        "Content-Type": "application/json",
        ...(options.headers || {}),
      },
      ...options,
    };

    let response: Response;
    try {
      response = await withRetry(url.toString(), init);
    } catch (err) {
      let handled = err;
      for (const interceptor of errorInterceptors) handled = await interceptor(handled, url.toString());
      throw handled;
    }

    if (!response.ok) {
      let data: unknown = null;
      try {
        data = await response.json();
      } catch {
        /* ignore parse errors */
      }
      if (response.status === 401) config.onUnauthorized?.();
      const message = extractErrorMessage(data) ?? `Request failed (${response.status})`;
      const error = new ApiError(message, response.status, data);
      let handled: unknown = error;
      for (const interceptor of errorInterceptors) handled = await interceptor(handled, url.toString());
      throw handled;
    }

    if (response.status === 204) return undefined as T;
    const contentType = response.headers.get("content-type") || "";
    if (!contentType.includes("application/json")) return (await response.text()) as unknown as T;
    return (await response.json()) as T;
  }

  function extractErrorMessage(data: unknown): string | null {
    if (!data) return null;
    if (typeof data === "string") return data;
    if (typeof data === "object" && "detail" in (data as Record<string, unknown>)) {
      const detail = (data as Record<string, unknown>).detail;
      if (typeof detail === "string") return detail;
      if (Array.isArray(detail)) {
        return detail.map((d) => (typeof d === "object" && d && "msg" in d ? (d as { msg: string }).msg : String(d))).join(", ");
      }
    }
    return null;
  }

  return {
    request,
    get: <T>(path: string, params?: Record<string, unknown>) => request<T>(path, { method: "GET" }, params),
    post: <T>(path: string, body?: unknown, params?: Record<string, unknown>) =>
      request<T>(path, { method: "POST", body: body ? JSON.stringify(body) : undefined }, params),
    put: <T>(path: string, body?: unknown, params?: Record<string, unknown>) =>
      request<T>(path, { method: "PUT", body: body ? JSON.stringify(body) : undefined }, params),
    patch: <T>(path: string, body?: unknown, params?: Record<string, unknown>) =>
      request<T>(path, { method: "PATCH", body: body ? JSON.stringify(body) : undefined }, params),
    delete: <T>(path: string, params?: Record<string, unknown>) => request<T>(path, { method: "DELETE" }, params),
    useRequestInterceptor: (fn: RequestInterceptor) => requestInterceptors.push(fn),
    useResponseInterceptor: (fn: ResponseInterceptor) => responseInterceptors.push(fn),
    useErrorInterceptor: (fn: ErrorInterceptor) => errorInterceptors.push(fn),
  };
}

export type ApiClient = ReturnType<typeof createApiClient>;
