import os
from urllib.parse import quote_plus


def build_database_url() -> str:
    database_url = os.getenv("DATABASE_URL")

    if database_url:
        if database_url.startswith("postgresql://"):
            return database_url.replace("postgresql://", "postgresql+psycopg://", 1)
        return database_url

    user = os.getenv("POSTGRES_USER", "gurumeet")
    password = os.getenv("POSTGRES_PASSWORD", "change_me")
    host = os.getenv("POSTGRES_HOST", "db")
    port = os.getenv("POSTGRES_PORT", "5432")
    database = os.getenv("POSTGRES_DB", "gurumeet")

    return (
        "postgresql+psycopg://"
        f"{quote_plus(user)}:{quote_plus(password)}@{host}:{port}/{database}"
    )
