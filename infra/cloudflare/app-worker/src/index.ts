import { Container, getRandom } from "@cloudflare/containers";
import { env as workerEnv } from "cloudflare:workers";

import { sendDiscordAlert } from "../../../discord/discordWebhook";

const INSTANCE_COUNT = 1;
const ERROR_ALERT_SUPPRESSION_SECONDS = 300;
const DISCORD_API_BASE_URL = "https://discord.com/api/v10";
const DISCORD_INTERACTION_PING = 1;
const DISCORD_INTERACTION_APPLICATION_COMMAND = 2;
const DISCORD_RESPONSE_PONG = 1;
const DISCORD_RESPONSE_CHANNEL_MESSAGE = 4;
const DISCORD_RESPONSE_DEFERRED_CHANNEL_MESSAGE = 5;
const DISCORD_MESSAGE_EPHEMERAL = 1 << 6;
const runtimeEnv = workerEnv as {
  DATABASE_URL: string;
  HOTPEPPER_API_KEY?: string;
  CORS_ALLOW_ORIGINS?: string;
  PARTICIPANT_TOKEN_HASH_SECRET?: string;
  INTERNAL_TASK_SECRET?: string;
  DISCORD_ALERT_WEBHOOK_URL?: string;
  DISCORD_APPLICATION_PUBLIC_KEY?: string;
  DISCORD_CLEANUP_FORWARD_SECRET?: string;
  DISCORD_DELETE_COMMAND_ALLOWED_USER_IDS?: string;
  DISCORD_STAGING_CLEANUP_URL?: string;
  DISCORD_PRODUCTION_CLEANUP_URL?: string;
  GURUMEET_ENABLE_MOCK_RESTAURANTS?: string;
  ENVIRONMENT?: string;
  GURUMEET_API_ROOT_PATH?: string;
};

export class BackendContainer extends Container {
  defaultPort = 8000;
  sleepAfter = "5m";

  async onActivityExpired(): Promise<void> {
    console.log(
      JSON.stringify({
        event: "backend_container_activity_expired",
        action: "stop_container_and_clear_alarm",
      }),
    );
    await this.ctx.storage.deleteAlarm();
    if (this.ctx.container?.running) {
      await this.stop();
    }
    await this.ctx.storage.deleteAlarm();
  }

  async onStop(): Promise<void> {
    console.log(
      JSON.stringify({
        event: "backend_container_stopped",
        action: "clear_alarm",
      }),
    );
    await this.ctx.storage.deleteAlarm();
  }

  async onError(error: unknown): Promise<void> {
    const message = errorMessage(error);
    if (isBenignContainerLifecycleError(message)) {
      console.info(
        JSON.stringify({
          event: "backend_container_lifecycle_error_ignored",
          message,
        }),
      );
      await this.ctx.storage.deleteAlarm();
      return;
    }

    console.error(
      JSON.stringify({
        event: "backend_container_error",
        error: message,
      }),
    );
    throw error;
  }

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
  DISCORD_APPLICATION_PUBLIC_KEY?: string;
  DISCORD_CLEANUP_FORWARD_SECRET?: string;
  DISCORD_DELETE_COMMAND_ALLOWED_USER_IDS?: string;
  DISCORD_STAGING_CLEANUP_URL?: string;
  DISCORD_PRODUCTION_CLEANUP_URL?: string;
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

      if (isApiHealthPath(url.pathname)) {
        return apiHealth();
      }

      if (url.pathname === "/discord/interactions") {
        return handleDiscordInteraction(request, env, ctx);
      }

      if (url.pathname === "/edge/internal/cleanup-expired-temporary-groups") {
        return handleForwardedCleanupRequest(request, env);
      }

      if (url.pathname.startsWith("/files/")) {
        return handleFileRequest(request, env);
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

};

type CleanupTarget = "staging" | "production";

interface DiscordInteraction {
  id: string;
  application_id: string;
  token: string;
  type: number;
  data?: {
    name?: string;
    options?: Array<{
      name?: string;
      type?: number;
    }>;
  };
  member?: {
    user?: {
      id?: string;
    };
  };
  user?: {
    id?: string;
  };
}

async function handleDiscordInteraction(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const body = await request.text();
  if (!(await verifyDiscordRequest(request, env, body))) {
    return new Response("invalid request signature", { status: 401 });
  }

  let interaction: DiscordInteraction;
  try {
    interaction = JSON.parse(body) as DiscordInteraction;
  } catch {
    return discordMessage("不正なリクエストです。", 400);
  }

  if (interaction.type === DISCORD_INTERACTION_PING) {
    return json({ type: DISCORD_RESPONSE_PONG });
  }

  if (interaction.type !== DISCORD_INTERACTION_APPLICATION_COMMAND) {
    return discordMessage("未対応の Discord interaction です。");
  }

  const target = cleanupTargetFromInteraction(interaction);
  if (!target) {
    return discordMessage(
      "`/delete staging` または `/delete production` を使ってください。",
    );
  }

  const userId = interaction.member?.user?.id ?? interaction.user?.id ?? "";
  if (!isAllowedDiscordUser(env, userId)) {
    return discordMessage("この cleanup command を実行する権限がありません。");
  }

  ctx.waitUntil(runCleanupAndUpdateDiscordResponse(env, interaction, target));
  return json({
    type: DISCORD_RESPONSE_DEFERRED_CHANNEL_MESSAGE,
    data: {
      flags: DISCORD_MESSAGE_EPHEMERAL,
    },
  });
}

async function handleForwardedCleanupRequest(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const configuredSecret = env.DISCORD_CLEANUP_FORWARD_SECRET?.trim() ?? "";
  const requestSecret =
    request.headers.get("X-Discord-Cleanup-Forward-Secret")?.trim() ?? "";
  if (
    !configuredSecret ||
    !requestSecret ||
    !(await timingSafeEqual(configuredSecret, requestSecret))
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  return runLocalCleanup(env, "discord_forward");
}

async function runCleanupAndUpdateDiscordResponse(
  env: Env,
  interaction: DiscordInteraction,
  target: CleanupTarget,
): Promise<void> {
  try {
    const result = await runCleanupForTarget(env, target);
    await updateDiscordOriginalResponse(interaction, {
      content: `/${interaction.data?.name ?? "delete"} ${target} completed. deleted_expired_temporary_groups=${result.deletedCount}`,
    });
  } catch (error) {
    const message = errorMessage(error);
    console.error(
      JSON.stringify({
        event: "discord_delete_command_failed",
        environment: env.ENVIRONMENT ?? "unknown",
        target,
        error: message,
      }),
    );
    await notifyCleanupFailed(env, {
      status: "discord_delete_command_failed",
      message,
      target,
    });
    await updateDiscordOriginalResponse(interaction, {
      content: `/${interaction.data?.name ?? "delete"} ${target} failed. ${truncate(message, 500)}`,
    });
  }
}

async function runCleanupForTarget(
  env: Env,
  target: CleanupTarget,
): Promise<{ deletedCount: number }> {
  if (target === currentCleanupTarget(env)) {
    const response = await runLocalCleanup(env, "discord_command");
    return parseCleanupResponse(response);
  }

  const url = cleanupForwardUrl(env, target);
  const secret = env.DISCORD_CLEANUP_FORWARD_SECRET?.trim() ?? "";
  if (!url || !secret) {
    throw new Error(
      `Forwarding to ${target} cleanup is not configured. Check DISCORD_${target.toUpperCase()}_CLEANUP_URL and DISCORD_CLEANUP_FORWARD_SECRET.`,
    );
  }

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "X-Discord-Cleanup-Forward-Secret": secret,
    },
  });
  return parseCleanupResponse(response);
}

async function runLocalCleanup(
  env: Env,
  trigger: "discord_command" | "discord_forward",
): Promise<Response> {
  console.info(
    JSON.stringify({
      event: "cleanup_expired_temporary_groups_started",
      environment: env.ENVIRONMENT ?? "unknown",
      trigger,
      triggered_at: new Date().toISOString(),
    }),
  );

  if (!env.INTERNAL_TASK_SECRET) {
    logWorkerError("cleanup_internal_task_secret_missing", undefined, env);
    await notifyCleanupFailed(env, {
      status: "missing_internal_task_secret",
      message: "INTERNAL_TASK_SECRET is not configured.",
    });
    return json({ detail: "INTERNAL_TASK_SECRET is not configured." }, { status: 500 });
  }

  const container = await getRandom(env.BACKEND_CONTAINER, INSTANCE_COUNT);
  const response = await container.fetch(
    new Request("http://container/internal/cleanup-expired-temporary-groups", {
      method: "POST",
      headers: {
        "X-Internal-Task-Secret": env.INTERNAL_TASK_SECRET,
      },
    }),
  );

  if (!response.ok) {
    const message = await response.clone().text();
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
  return response;
}

async function notifyCleanupFailed(
  env: Env,
  failure: { status: number | string; message: string; target?: CleanupTarget },
): Promise<void> {
  try {
    await sendDiscordAlert({
      webhookUrl: env.DISCORD_ALERT_WEBHOOK_URL,
      title: "cleanup_failed",
      level: "critical",
      fields: {
        environment: env.ENVIRONMENT ?? "unknown",
        target: failure.target ?? currentCleanupTarget(env),
        status: failure.status,
        message: truncate(failure.message, 500),
        triggered_at: formatJst(new Date()),
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

async function verifyDiscordRequest(
  request: Request,
  env: Env,
  body: string,
): Promise<boolean> {
  const publicKey = env.DISCORD_APPLICATION_PUBLIC_KEY?.trim() ?? "";
  const signature = request.headers.get("X-Signature-Ed25519") ?? "";
  const timestamp = request.headers.get("X-Signature-Timestamp") ?? "";
  if (!publicKey || !signature || !timestamp) {
    return false;
  }

  try {
    const key = await crypto.subtle.importKey(
      "raw",
      hexToBytes(publicKey),
      { name: "Ed25519" },
      false,
      ["verify"],
    );
    return crypto.subtle.verify(
      { name: "Ed25519" },
      key,
      hexToBytes(signature),
      new TextEncoder().encode(`${timestamp}${body}`),
    );
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "discord_signature_verification_failed",
        error: errorMessage(error),
      }),
    );
    return false;
  }
}

function cleanupTargetFromInteraction(
  interaction: DiscordInteraction,
): CleanupTarget | undefined {
  if (interaction.data?.name !== "delete") {
    return undefined;
  }
  const subcommandName = interaction.data.options?.[0]?.name;
  if (subcommandName === "staging" || subcommandName === "production") {
    return subcommandName;
  }
  return undefined;
}

function isAllowedDiscordUser(env: Env, userId: string): boolean {
  if (!userId) {
    return false;
  }
  const allowedUserIds = new Set(
    (env.DISCORD_DELETE_COMMAND_ALLOWED_USER_IDS ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
  return allowedUserIds.has(userId);
}

function currentCleanupTarget(env: Env): CleanupTarget {
  return (env.ENVIRONMENT ?? "production").toLowerCase() === "staging"
    ? "staging"
    : "production";
}

function cleanupForwardUrl(env: Env, target: CleanupTarget): string {
  const configured =
    target === "staging"
      ? env.DISCORD_STAGING_CLEANUP_URL
      : env.DISCORD_PRODUCTION_CLEANUP_URL;
  return configured?.trim() ?? "";
}

async function parseCleanupResponse(
  response: Response,
): Promise<{ deletedCount: number }> {
  const responseBody = await response.text();
  if (!response.ok) {
    throw new Error(
      `cleanup request failed: status=${response.status}, body=${truncate(
        responseBody,
        500,
      )}`,
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(responseBody);
  } catch {
    throw new Error(`cleanup response is not JSON: ${truncate(responseBody, 500)}`);
  }

  if (!isCleanupResult(parsed)) {
    throw new Error(`cleanup response has unexpected shape: ${truncate(responseBody, 500)}`);
  }
  return { deletedCount: parsed.deleted_expired_temporary_groups };
}

function isCleanupResult(
  value: unknown,
): value is { deleted_expired_temporary_groups: number } {
  return (
    typeof value === "object" &&
    value !== null &&
    "deleted_expired_temporary_groups" in value &&
    typeof value.deleted_expired_temporary_groups === "number"
  );
}

async function updateDiscordOriginalResponse(
  interaction: DiscordInteraction,
  body: { content: string },
): Promise<void> {
  const response = await fetch(
    `${DISCORD_API_BASE_URL}/webhooks/${interaction.application_id}/${interaction.token}/messages/@original`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );
  if (!response.ok) {
    const responseBody = await response.text();
    throw new Error(
      `failed to update Discord interaction response: status=${response.status}, body=${truncate(
        responseBody,
        500,
      )}`,
    );
  }
}

function discordMessage(content: string, status = 200): Response {
  return json(
    {
      type: DISCORD_RESPONSE_CHANNEL_MESSAGE,
      data: {
        content,
        flags: DISCORD_MESSAGE_EPHEMERAL,
      },
    },
    { status },
  );
}

async function timingSafeEqual(left: string, right: string): Promise<boolean> {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  if (leftBytes.length !== rightBytes.length) {
    return false;
  }

  const leftHash = await crypto.subtle.digest("SHA-256", leftBytes);
  const rightHash = await crypto.subtle.digest("SHA-256", rightBytes);
  return bytesEqual(new Uint8Array(leftHash), new Uint8Array(rightHash));
}

function bytesEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) {
    return false;
  }
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

function hexToBytes(value: string): Uint8Array {
  if (!/^[0-9a-fA-F]+$/.test(value) || value.length % 2 !== 0) {
    throw new Error("hex value must contain an even number of hex characters.");
  }
  const bytes = new Uint8Array(value.length / 2);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(value.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
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

function apiHealth(): Response {
  return json(
    {
      status: "healthy",
      service: "gurumeet-worker",
      backend_container: "not_checked",
    },
    {
      headers: {
        "Cache-Control": "no-store",
        "X-Gurumeet-Health-Source": "worker",
      },
    },
  );
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

function isApiRootPath(pathname: string): boolean {
  return pathname === "/api" || pathname === "/api/";
}

function isApiHealthPath(pathname: string): boolean {
  return pathname === "/api/health" || pathname === "/api/health/";
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

function isBenignContainerLifecycleError(message: string): boolean {
  const normalized = message.toLowerCase();
  return (
    normalized.includes("durable object reset because its code was updated") ||
    normalized.includes("runtime signalled the container to exit due to a new version rollout")
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
