from pydantic import Field, SecretStr
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "GuruMeet Backend"
    hotpepper_api_key: SecretStr | None = Field(
        default=None,
        validation_alias="HOTPEPPER_API_KEY",
    )
    temporary_group_ttl_minutes: int = 1440
    temporary_group_code_max_attempts: int = 20
    join_rate_limit_requests: int = 10
    join_rate_limit_window_seconds: int = 60
    cors_allow_origins: list[str] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:5000",
        "http://127.0.0.1:5000",
    ]
    participant_token_hash_secret: str = (
        "gurumeet-dev-participant-token-secret"
    )

    @field_validator("cors_allow_origins", mode="before")
    @classmethod
    def parse_cors_allow_origins(cls, value: object) -> object:
        if isinstance(value, str):
            return [
                origin.strip()
                for origin in value.split(",")
                if origin.strip()
            ]
        return value

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
