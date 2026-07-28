from fastapi import FastAPI

from app.api.routes import health, meetings, temporary_groups, users
from app.core.config import settings

app = FastAPI(title=settings.app_name)

app.include_router(health.router)
app.include_router(users.router, prefix="/users")
app.include_router(meetings.router, prefix="/meetings")
app.include_router(temporary_groups.router, prefix="/temporary-groups")
