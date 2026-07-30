import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse

from app.api.routes import health, internal, locations, meetings, temporary_groups, users
from app.core.config import settings
from app.core.middleware import (
    request_size_limit_middleware,
    structured_logging_middleware,
)

logging.basicConfig(level=logging.INFO, format="%(message)s")

app = FastAPI(
    title=settings.app_name,
    root_path=settings.api_root_path,
    docs_url="/docs" if settings.api_docs_enabled else None,
    redoc_url="/redoc" if settings.api_docs_enabled else None,
    openapi_url="/openapi.json" if settings.api_docs_enabled else None,
)

app.middleware("http")(structured_logging_middleware)
app.middleware("http")(request_size_limit_middleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
