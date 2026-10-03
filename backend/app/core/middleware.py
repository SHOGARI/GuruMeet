import json
import logging
import time
import uuid
from collections.abc import Awaitable, Callable

from fastapi import Request
from starlette.responses import JSONResponse, Response

from app.core.config import settings

logger = logging.getLogger("gurumeet.access")

MAX_REQUEST_ID_LENGTH = 128
MAX_USER_AGENT_LENGTH = 512


async def request_size_limit_middleware(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    content_length = request.headers.get("content-length")
    if content_length is not None:
        try:
            length = int(content_length)
        except ValueError:
            length = 0
        if length > settings.request_body_max_bytes:
            return JSONResponse(
                status_code=413,
                content={"detail": "リクエストサイズが大きすぎます。"},
            )

    return await call_next(request)


async def structured_logging_middleware(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    request_id = _request_id(request)
    started_at = time.perf_counter()
    status_code = 500
    error: Exception | None = None

    try:
        response = await call_next(request)
        status_code = response.status_code
        response.headers["x-request-id"] = request_id
        return response
    except Exception as exc:
        error = exc
        raise
    finally:
        duration_ms = round((time.perf_counter() - started_at) * 1000, 2)
        severity = (
            "error"
            if status_code >= 500
            else "warning"
            if status_code >= 400
            else "info"
        )
        log_fields = {
            "source": "gurumeet",
            "event": "http_response",
            "severity": severity,
            "request_id": request_id,
            "cf_ray": request.headers.get("cf-ray"),
            "method": request.method,
            "path": request.url.path,
            "status_code": status_code,
            "duration_ms": duration_ms,
            "client_ip": request.headers.get("cf-connecting-ip")
            or (request.client.host if request.client else None),
            "country": request.headers.get("cf-ipcountry"),
            "user_agent": _truncate(
                request.headers.get("user-agent"),
                MAX_USER_AGENT_LENGTH,
            ),
            "protocol": request.headers.get("x-forwarded-proto")
            or request.url.scheme,
        }
        if error is not None:
            log_fields["error"] = str(error)
            log_fields["error_type"] = type(error).__name__

        message = json.dumps(log_fields, ensure_ascii=False)
        if severity == "error":
            logger.error(message)
        elif severity == "warning":
            logger.warning(message)
        else:
            logger.info(message)


def _request_id(request: Request) -> str:
    configured = request.headers.get("x-request-id", "").strip()
    if configured:
        return configured[:MAX_REQUEST_ID_LENGTH]
    return str(uuid.uuid4())


def _truncate(value: str | None, max_length: int) -> str | None:
    if value is None or len(value) <= max_length:
        return value
    return value[:max_length]
