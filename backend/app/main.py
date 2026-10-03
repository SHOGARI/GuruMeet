import logging
import sys

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse

from app.api.routes import health, internal, locations, meetings, temporary_groups, users
from app.core.config import settings
from app.core.middleware import (
    request_size_limit_middleware,
    structured_logging_middleware,
)

log_formatter = logging.Formatter("%(message)s")

gurumeet_logger = logging.getLogger("gurumeet")
gurumeet_logger.handlers.clear()
gurumeet_logger.setLevel(logging.INFO)
gurumeet_logger.propagate = False
application_handler = logging.StreamHandler()
application_handler.setFormatter(log_formatter)
gurumeet_logger.addHandler(application_handler)

# Cloudflare Containers reliably indexes application access logs written to
# stdout. Keep this separate from application errors, which remain on stderr.
access_logger = logging.getLogger("gurumeet.access")
access_logger.handlers.clear()
access_logger.setLevel(logging.INFO)
access_logger.propagate = False
access_handler = logging.StreamHandler(sys.stdout)
access_handler.setFormatter(log_formatter)
access_logger.addHandler(access_handler)

app = FastAPI(
    title=settings.app_name,
    root_path=settings.api_root_path,
    docs_url="/docs" if settings.api_docs_enabled else None,
    redoc_url="/redoc" if settings.api_docs_enabled else None,
    openapi_url="/openapi.json" if settings.api_docs_enabled else None,
)

app.middleware("http")(request_size_limit_middleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Keep response logging outermost so responses created by CORS and request-size
# middleware are logged as well.
app.middleware("http")(structured_logging_middleware)

app.include_router(health.router)
app.include_router(users.router, prefix="/users")
app.include_router(meetings.router, prefix="/meetings")
app.include_router(temporary_groups.router, prefix="/temporary-groups")
app.include_router(locations.router, prefix="/locations")
app.include_router(internal.router)


@app.exception_handler(Exception)
async def unhandled_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    logging.getLogger("gurumeet.error").exception(
        "unhandled_exception path=%s",
        request.url.path,
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "サーバーでエラーが発生しました。時間をおいて再試行してください。"},
    )
