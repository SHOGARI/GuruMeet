import json
from typing import Annotated

from pydantic import Field, SecretStr
from pydantic import field_validator
from pydantic import model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


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
    temporary_group_ttl_minutes: int = 180
    temporary_group_code_max_attempts: int = 20
    join_rate_limit_requests: int = 10
    join_rate_limit_window_seconds: int = 60
    enable_mock_restaurants: bool = Field(
        default=False,
        validation_alias="GURUMEET_ENABLE_MOCK_RESTAURANTS",
    )
    hotpepper_station_search_radius_meters: int = Field(
        default=1000,
        validation_alias="GURUMEET_HOTPEPPER_STATION_SEARCH_RADIUS_METERS",
    )
    hotpepper_municipality_search_radius_meters: int = Field(
        default=3000,
        validation_alias="GURUMEET_HOTPEPPER_MUNICIPALITY_SEARCH_RADIUS_METERS",
    )
    hotpepper_custom_location_search_radius_meters: int = Field(
        default=1000,
        validation_alias="GURUMEET_HOTPEPPER_CUSTOM_LOCATION_SEARCH_RADIUS_METERS",
    )
    cors_allow_origins: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: [
            "http://localhost:3000",
            "http://127.0.0.1:3000",
            "http://localhost:8080",
            "http://127.0.0.1:8080",
            "http://localhost:5000",
            "http://127.0.0.1:5000",
        ],
        validation_alias="CORS_ALLOW_ORIGINS",
    )
    participant_token_hash_secret: str = Field(
        validation_alias="PARTICIPANT_TOKEN_HASH_SECRET",
    )
    internal_task_secret: SecretStr | None = Field(
        default=None,
        validation_alias="INTERNAL_TASK_SECRET",
    )
    discord_alert_webhook_url: SecretStr | None = Field(
        default=None,
        validation_alias="DISCORD_ALERT_WEBHOOK_URL",
    )
    request_body_max_bytes: int = 1024 * 1024

    @field_validator("cors_allow_origins", mode="before")
    @classmethod
    def parse_cors_allow_origins(cls, value: object) -> object:
        if isinstance(value, str):
            stripped = value.strip()
            if stripped.startswith("["):
                try:
                    parsed = json.loads(stripped)
                except json.JSONDecodeError:
                    parsed = None
                if isinstance(parsed, list):
                    return parsed
            return [
                origin.strip()
                for origin in value.split(",")
                if origin.strip()
            ]
        return value

    @field_validator("participant_token_hash_secret")
    @classmethod
    def require_participant_token_hash_secret(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("PARTICIPANT_TOKEN_HASH_SECRET must not be empty")
        return value

    @field_validator(
        "hotpepper_station_search_radius_meters",
        "hotpepper_municipality_search_radius_meters",
        "hotpepper_custom_location_search_radius_meters",
    )
    @classmethod
    def require_positive_radius_meters(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("Hot Pepper search radius must be positive")
        return value

    @model_validator(mode="after")
    def require_runtime_configuration(self) -> "Settings":
        if not self.cors_allow_origins:
            raise ValueError("CORS_ALLOW_ORIGINS must not be empty")
        if self.internal_task_secret is None:
            raise ValueError("INTERNAL_TASK_SECRET must be configured")
        if not self.internal_task_secret.get_secret_value().strip():
            raise ValueError("INTERNAL_TASK_SECRET must not be empty")
        if not self.enable_mock_restaurants:
            if self.hotpepper_api_key is None:
                raise ValueError(
                    "HOTPEPPER_API_KEY must be configured when "
                    "GURUMEET_ENABLE_MOCK_RESTAURANTS=false"
                )
            if not self.hotpepper_api_key.get_secret_value().strip():
                raise ValueError(
                    "HOTPEPPER_API_KEY must not be empty when "
                    "GURUMEET_ENABLE_MOCK_RESTAURANTS=false"
                )
        return self

    @property
    def api_docs_enabled(self) -> bool:
        return self.environment.lower() not in {"production", "product"}

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )


settings = Settings()
