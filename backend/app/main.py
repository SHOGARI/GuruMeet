from fastapi import FastAPI

from app.api.routes import health, meetings, users

app = FastAPI(title="GuruMeet Backend")

app.include_router(health.router)
app.include_router(users.router, prefix="/users")
app.include_router(meetings.router, prefix="/meetings")
