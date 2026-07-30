import json
import logging
import time
import uuid
from collections.abc import Awaitable, Callable

from fastapi import Request
from starlette.responses import JSONResponse, Response

from app.core.config import settings

logger = logging.getLogger("gurumeet.access")
error_logger = logging.getLogger("gurumeet.error")


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
    request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
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
        log_fields = {
            "event": "http_request",
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": status_code,
            "duration_ms": duration_ms,
            "client": request.client.host if request.client else None,
        }
        logger.info(
            json.dumps(
                log_fields,
                ensure_ascii=False,
            )
        )
        if status_code >= 500:
            error_fields = {
                **log_fields,
                "event": "http_error_response",
            }
            if error is not None:
                error_fields["error"] = str(error)
                error_fields["error_type"] = type(error).__name__
            error_logger.error(
                json.dumps(
                    error_fields,
                    ensure_ascii=False,
                )
            )
