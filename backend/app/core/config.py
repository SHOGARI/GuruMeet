from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "GuruMeet Backend"
    hotpepper_api_key: SecretStr = Field(
        validation_alias="HOTPEPPER_API_KEY",
        min_length=1,
    )
    temporary_group_ttl_minutes: int = 1440
    temporary_group_code_max_attempts: int = 20
    join_rate_limit_requests: int = 10
    join_rate_limit_window_seconds: int = 60
    participant_token_hash_secret: str = (
        "gurumeet-dev-participant-token-secret"
    )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
