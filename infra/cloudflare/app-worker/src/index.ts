import { Container, getRandom } from "@cloudflare/containers";
import { env as workerEnv } from "cloudflare:workers";

import { sendDiscordAlert } from "../../../discord/discordWebhook";

const INSTANCE_COUNT = 1;
const CLEANUP_CRON_UTC_HOUR = 12;
const CLEANUP_CRON_UTC_MINUTE = 0;
const ERROR_ALERT_SUPPRESSION_SECONDS = 300;
const runtimeEnv = workerEnv as {
  DATABASE_URL: string;
  HOTPEPPER_API_KEY?: string;
  CORS_ALLOW_ORIGINS?: string;
  PARTICIPANT_TOKEN_HASH_SECRET?: string;
  INTERNAL_TASK_SECRET?: string;
  DISCORD_ALERT_WEBHOOK_URL?: string;
  GURUMEET_ENABLE_MOCK_RESTAURANTS?: string;
  ENVIRONMENT?: string;
  GURUMEET_API_ROOT_PATH?: string;
};

export class BackendContainer extends Container {
  defaultPort = 8000;
  sleepAfter = "5m";
  envVars = {
    DATABASE_URL: requiredRuntimeEnv(runtimeEnv.DATABASE_URL, "DATABASE_URL"),
    HOTPEPPER_API_KEY: requiredRuntimeEnv(
      runtimeEnv.HOTPEPPER_API_KEY,
      "HOTPEPPER_API_KEY",
    ),
    CORS_ALLOW_ORIGINS: requiredRuntimeEnv(
      runtimeEnv.CORS_ALLOW_ORIGINS,
      "CORS_ALLOW_ORIGINS",
    ),
    PARTICIPANT_TOKEN_HASH_SECRET: requiredRuntimeEnv(
      runtimeEnv.PARTICIPANT_TOKEN_HASH_SECRET,
      "PARTICIPANT_TOKEN_HASH_SECRET",
    ),
    INTERNAL_TASK_SECRET: requiredRuntimeEnv(
      runtimeEnv.INTERNAL_TASK_SECRET,
      "INTERNAL_TASK_SECRET",
    ),
    DISCORD_ALERT_WEBHOOK_URL: runtimeEnv.DISCORD_ALERT_WEBHOOK_URL ?? "",
    GURUMEET_ENABLE_MOCK_RESTAURANTS:
      runtimeEnv.GURUMEET_ENABLE_MOCK_RESTAURANTS ?? "false",
    ENVIRONMENT: runtimeEnv.ENVIRONMENT ?? "production",
    GURUMEET_API_ROOT_PATH: runtimeEnv.GURUMEET_API_ROOT_PATH ?? "",
  };
}

interface Env {
  ASSETS: Fetcher;
  BACKEND_CONTAINER: DurableObjectNamespace<BackendContainer>;
  ASSETS_BUCKET: R2Bucket;
  DATABASE_URL: string;
  HOTPEPPER_API_KEY?: string;
  CORS_ALLOW_ORIGINS?: string;
  PARTICIPANT_TOKEN_HASH_SECRET?: string;
  INTERNAL_TASK_SECRET?: string;
  DISCORD_ALERT_WEBHOOK_URL?: string;
  GURUMEET_ENABLE_MOCK_RESTAURANTS?: string;
  ENVIRONMENT?: string;
  GURUMEET_API_ROOT_PATH?: string;
}

export default {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);

    try {
      if (url.pathname === "/edge/health") {
        return edgeHealth(request, env);
      }

      if (url.pathname.startsWith("/files/")) {
        return handleFileRequest(request, env);
      }

      if (isProduction(env) && isApiPath(url.pathname)) {
        return new Response("Not found", { status: 404 });
      }

      if (isApiRootPath(url.pathname)) {
        return new Response("Not found", { status: 404 });
      }

      if (url.pathname.startsWith("/api/")) {
        return handleApiRequest(request, env, ctx);
      }

      return env.ASSETS.fetch(request);
    } catch (error) {
      logWorkerError("worker_request_failed", request, env, error);
      return new Response("Internal server error", { status: 500 });
    }
  },

  async scheduled(event: ScheduledEvent, env: Env): Promise<void> {
    if (!isCleanupScheduleWindow(event.scheduledTime)) {
      console.info(
        JSON.stringify({
          event: "cleanup_expired_temporary_groups_skipped",
          cron: event.cron,
          scheduled_at: new Date(event.scheduledTime).toISOString(),
          reason: "outside_cleanup_schedule_window",
        }),
      );
      return;
    }

    console.info(
      JSON.stringify({
        event: "cleanup_expired_temporary_groups_started",
        cron: event.cron,
        scheduled_at: new Date(event.scheduledTime).toISOString(),
      }),
    );

    if (!env.INTERNAL_TASK_SECRET) {
      logWorkerError("cleanup_internal_task_secret_missing", undefined, env);
      await notifyCleanupFailed(env, {
        status: "missing_internal_task_secret",
        message: "INTERNAL_TASK_SECRET is not configured.",
      });
      return;
    }
    const container = await getRandom(env.BACKEND_CONTAINER, INSTANCE_COUNT);
    const response = await container.fetch(
      new Request(
        "http://container/internal/cleanup-expired-temporary-groups",
        {
          method: "POST",
          headers: {
            "X-Internal-Task-Secret": env.INTERNAL_TASK_SECRET,
          },
        },
      ),
    );
    if (!response.ok) {
      const message = await response.text();
      console.error(
        JSON.stringify({
          event: "cleanup_expired_temporary_groups_failed",
          environment: env.ENVIRONMENT ?? "unknown",
          status: response.status,
          response_body: truncate(message, 1000),
        }),
      );
      await notifyCleanupFailed(env, {
        status: response.status,
        message,
      });
    }
  },
};

async function notifyCleanupFailed(
  env: Env,
  failure: { status: number | string; message: string },
): Promise<void> {
  try {
    await sendDiscordAlert({
      webhookUrl: env.DISCORD_ALERT_WEBHOOK_URL,
      title: "cleanup_failed",
      level: "critical",
      fields: {
        environment: env.ENVIRONMENT ?? "unknown",
        status: failure.status,
        message: truncate(failure.message, 500),
        scheduled_at: formatJst(new Date()),
      },
    });
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "discord_cleanup_failed_alert_failed",
        error: error instanceof Error ? error.message : String(error),
      }),
    );
  }
}

function isCleanupScheduleWindow(scheduledTime: number): boolean {
  const scheduledAt = new Date(scheduledTime);
  return (
    scheduledAt.getUTCHours() === CLEANUP_CRON_UTC_HOUR &&
    scheduledAt.getUTCMinutes() === CLEANUP_CRON_UTC_MINUTE
  );
}

function requiredRuntimeEnv(value: string | undefined, name: string): string {
  if (!value?.trim()) {
    throw new Error(`${name} must be configured and non-empty.`);
  }
  return value;
}

async function handleApiRequest(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
): Promise<Response> {
  try {
    const container = await getRandom(env.BACKEND_CONTAINER, INSTANCE_COUNT);
    const response = await container.fetch(stripApiPrefix(request));
    if (response.status >= 500) {
      const responseForLog = response.clone();
      ctx.waitUntil(reportContainerErrorResponse(request, env, responseForLog));
    }
    return response;
  } catch (error) {
    logWorkerError("container_proxy_failed", request, env, error);
    ctx.waitUntil(
      notifyProductionContainerError({
        env,
        request,
        event: "container_proxy_failed",
        status: 502,
        message: errorMessage(error),
      }),
    );
    return new Response("Bad gateway", { status: 502 });
  }
}

async function reportContainerErrorResponse(
  request: Request,
  env: Env,
  response: Response,
): Promise<void> {
  let responseBody: string | undefined;
  try {
    responseBody = truncate(await response.text(), 1000);
  } catch (error) {
    responseBody = `failed to read response body: ${errorMessage(error)}`;
  }

  console.error(
    JSON.stringify({
      event: "container_error_response",
      environment: env.ENVIRONMENT ?? "unknown",
      method: request.method,
      path: new URL(request.url).pathname,
      status: response.status,
      response_body: responseBody,
    }),
  );
  await notifyProductionContainerError({
    env,
    request,
    event: "container_error_response",
    status: response.status,
    message: "Container returned a 5xx response. Check Cloudflare Logs.",
  });
}

async function edgeHealth(request: Request, env: Env): Promise<Response> {
  const checks = {
    environment: env.ENVIRONMENT ?? "unknown",
    worker: "healthy",
    r2: "unknown",
  };

  try {
    await env.ASSETS_BUCKET.head("__healthcheck__");
    checks.r2 = "healthy";
  } catch (error) {
    checks.r2 = "unhealthy";
    logWorkerError("edge_health_r2_check_failed", request, env, error);
  }

  return json(checks);
}

async function handleFileRequest(
  request: Request,
  env: Env,
): Promise<Response> {
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
      "Content-Type":
        object.httpMetadata?.contentType ?? "application/octet-stream",
      "Cache-Control": "public, max-age=3600",
      ETag: object.httpEtag,
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

function isApiPath(pathname: string): boolean {
  return pathname === "/api" || pathname.startsWith("/api/");
}

function isApiRootPath(pathname: string): boolean {
  return pathname === "/api" || pathname === "/api/";
}

function truncate(value: string, maxLength: number): string {
  if (value.length <= maxLength) {
    return value;
  }
  return `${value.slice(0, maxLength - 3)}...`;
}

function formatJst(value: Date): string {
  return value.toLocaleString("ja-JP", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });
}

async function notifyProductionContainerError({
  env,
  request,
  event,
  status,
  message,
}: {
  env: Env;
  request: Request;
  event: string;
  status: number;
  message: string;
}): Promise<void> {
  if (!isProduction(env) || !env.DISCORD_ALERT_WEBHOOK_URL?.trim()) {
    return;
  }

  const path = new URL(request.url).pathname;
  if (!(await shouldSendErrorAlert(event, path, status))) {
    return;
  }

  try {
    await sendDiscordAlert({
      webhookUrl: env.DISCORD_ALERT_WEBHOOK_URL,
      title: "production_container_error",
      level: "critical",
      fields: {
        environment: env.ENVIRONMENT ?? "unknown",
        event,
        method: request.method,
        path,
        status,
        message: truncate(message, 300),
        occurred_at: formatJst(new Date()),
      },
    });
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "production_container_error_alert_failed",
        environment: env.ENVIRONMENT ?? "unknown",
        original_event: event,
        path,
        status,
        error: errorMessage(error),
      }),
    );
  }
}

async function shouldSendErrorAlert(
  event: string,
  path: string,
  status: number,
): Promise<boolean> {
  const cacheKey = new Request(
    `https://gurumeet-alert-suppression.local/${encodeURIComponent(
      event,
    )}/${encodeURIComponent(path)}/${status}`,
  );
  try {
    if (await caches.default.match(cacheKey)) {
      return false;
    }
    await caches.default.put(
      cacheKey,
      new Response("1", {
        headers: {
          "Cache-Control": `max-age=${ERROR_ALERT_SUPPRESSION_SECONDS}`,
        },
      }),
    );
    return true;
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "production_container_error_alert_suppression_failed",
        error: errorMessage(error),
      }),
    );
    return true;
  }
}

function logWorkerError(
  event: string,
  request: Request | undefined,
  env: Env,
  error?: unknown,
): void {
  const url = request ? new URL(request.url) : undefined;
  console.error(
    JSON.stringify({
      event,
      environment: env.ENVIRONMENT ?? "unknown",
      method: request?.method,
      path: url?.pathname,
      error: error === undefined ? undefined : errorMessage(error),
      stack: error instanceof Error ? error.stack : undefined,
    }),
  );
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
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
