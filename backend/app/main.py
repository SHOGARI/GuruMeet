from fastapi import FastAPI

from app.api.routes import health, meetings, temporary_groups, users
from app.core.config import settings

app = FastAPI(
    title=settings.app_name,
    root_path=settings.api_root_path,
    docs_url="/docs" if settings.api_docs_enabled else None,
    redoc_url="/redoc" if settings.api_docs_enabled else None,
    openapi_url="/openapi.json" if settings.api_docs_enabled else None,
)

app.include_router(health.router)
app.include_router(users.router, prefix="/users")
app.include_router(meetings.router, prefix="/meetings")
app.include_router(temporary_groups.router, prefix="/temporary-groups")
