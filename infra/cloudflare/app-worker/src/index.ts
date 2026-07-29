import { Container, getRandom } from "@cloudflare/containers";
import { env as workerEnv } from "cloudflare:workers";

const INSTANCE_COUNT = 1;
const runtimeEnv = workerEnv as {
  DATABASE_URL: string;
  ENVIRONMENT?: string;
  GURUMEET_API_ROOT_PATH?: string;
};

export class BackendContainer extends Container {
  defaultPort = 8000;
  sleepAfter = "5m";
  envVars = {
    DATABASE_URL: runtimeEnv.DATABASE_URL,
    ENVIRONMENT: runtimeEnv.ENVIRONMENT ?? "production",
    GURUMEET_API_ROOT_PATH: runtimeEnv.GURUMEET_API_ROOT_PATH ?? "",
  };
}

interface Env {
  ASSETS: Fetcher;
  BACKEND_CONTAINER: DurableObjectNamespace<BackendContainer>;
  ASSETS_BUCKET: R2Bucket;
  DATABASE_URL: string;
  ENVIRONMENT?: string;
  GURUMEET_API_ROOT_PATH?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/edge/health") {
      return edgeHealth(env);
    }

    if (url.pathname.startsWith("/files/")) {
      return handleFileRequest(request, env);
    }

    if (isApiRootPath(url.pathname)) {
      return new Response("Not found", { status: 404 });
    }

    if (isProduction(env) && isApiDocsPath(url.pathname)) {
      return new Response("Not found", { status: 404 });
    }

    if (url.pathname.startsWith("/api/")) {
      const container = await getRandom(env.BACKEND_CONTAINER, INSTANCE_COUNT);
      return container.fetch(stripApiPrefix(request));
    }

    return env.ASSETS.fetch(request);
  },
};

async function edgeHealth(env: Env): Promise<Response> {
  const checks = {
    environment: env.ENVIRONMENT ?? "unknown",
    worker: "healthy",
    r2: "unknown",
  };

  try {
    await env.ASSETS_BUCKET.head("__healthcheck__");
    checks.r2 = "healthy";
  } catch {
    checks.r2 = "unhealthy";
  }

  return json(checks);
}

async function handleFileRequest(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const key = decodeURIComponent(url.pathname.replace(/^\/files\//, ""));

  if (!key || key.includes("..")) {
    return new Response("Bad request", { status: 400 });
  }

  const object = await env.ASSETS_BUCKET.get(key);

  if (!object) {
    return new Response("Not found", { status: 404 });
  }

  return new Response(object.body, {
    headers: {
      "Content-Type": object.httpMetadata?.contentType ?? "application/octet-stream",
      "Cache-Control": "public, max-age=3600",
      "ETag": object.httpEtag,
    },
  });
}

function stripApiPrefix(request: Request): Request {
  const url = new URL(request.url);
  url.pathname = url.pathname.replace(/^\/api/, "") || "/";
  return new Request(url, request);
}

function isProduction(env: Env): boolean {
  return (env.ENVIRONMENT ?? "production").toLowerCase() === "production";
}

function isApiRootPath(pathname: string): boolean {
  return pathname === "/api" || pathname === "/api/";
}

function isApiDocsPath(pathname: string): boolean {
  return (
    pathname === "/api/openapi.json" ||
    pathname === "/api/redoc" ||
    pathname.startsWith("/api/redoc/") ||
    pathname === "/api/docs" ||
    pathname.startsWith("/api/docs/")
  );
}

function json(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...init.headers,
    },
  });
}
