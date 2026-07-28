from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "GuruMeet Backend"
    environment: str = Field(default="development", validation_alias="ENVIRONMENT")
    api_root_path: str = Field(
        default="",
        validation_alias="GURUMEET_API_ROOT_PATH",
    )
    hotpepper_api_key: SecretStr | None = Field(
        default=None,
        validation_alias="HOTPEPPER_API_KEY",
    )
    temporary_group_ttl_minutes: int = 1440
    temporary_group_code_max_attempts: int = 20
    join_rate_limit_requests: int = 10
    join_rate_limit_window_seconds: int = 60
    participant_token_hash_secret: str = (
        "gurumeet-dev-participant-token-secret"
    )

    @property
    def api_docs_enabled(self) -> bool:
        return self.environment.lower() not in {"production", "product"}

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
