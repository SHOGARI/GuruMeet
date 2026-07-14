import os

from pydantic import BaseModel


class Settings(BaseModel):
    app_name: str = "Gurumeet Backend"
    temporary_group_ttl_minutes: int = int(
        os.getenv("TEMPORARY_GROUP_TTL_MINUTES", "1440")
    )
    temporary_group_code_max_attempts: int = int(
        os.getenv("TEMPORARY_GROUP_CODE_MAX_ATTEMPTS", "20")
    )
    join_rate_limit_requests: int = int(os.getenv("JOIN_RATE_LIMIT_REQUESTS", "10"))
    join_rate_limit_window_seconds: int = int(
        os.getenv("JOIN_RATE_LIMIT_WINDOW_SECONDS", "60")
    )


settings = Settings()
