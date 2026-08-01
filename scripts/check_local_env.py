#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SECRET_KEYS = {
    "DATABASE_URL",
    "HOTPEPPER_API_KEY",
    "POSTGRES_PASSWORD",
    "PARTICIPANT_TOKEN_HASH_SECRET",
    "INTERNAL_TASK_SECRET",
    "CLOUDFLARE_API_TOKEN",
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="動作確認前に .env と環境変数の設定状態を安全に確認します。",
    )
    parser.add_argument(
        "--scope",
        choices=["all", "backend", "frontend"],
        default="all",
    )
    args = parser.parse_args()

    has_error = False
    if args.scope in {"all", "backend"}:
        has_error = check_backend_env() or has_error
    if args.scope in {"all", "frontend"}:
        has_error = check_frontend_env() or has_error

    if has_error:
        print("\nNG: 動作確認前に上記の環境変数を直してください。")
        return 1

    print("\nOK: 動作確認に必要な環境変数は確認済みです。")
    return 0


def check_backend_env() -> bool:
    print("Backend env")
    env = load_env(ROOT / "backend" / ".env")
    has_error = False
    has_error |= report_file(ROOT / "backend" / ".env")

    required = [
        "API_PORT",
        "POSTGRES_DB",
        "POSTGRES_USER",
        "POSTGRES_PASSWORD",
        "POSTGRES_PORT",
        "TEMPORARY_GROUP_CODE_MAX_ATTEMPTS",
        "JOIN_RATE_LIMIT_REQUESTS",
        "JOIN_RATE_LIMIT_WINDOW_SECONDS",
        "CORS_ALLOW_ORIGINS",
        "GURUMEET_ENABLE_MOCK_RESTAURANTS",
        "PARTICIPANT_TOKEN_HASH_SECRET",
        "INTERNAL_TASK_SECRET",
        "REQUEST_BODY_MAX_BYTES",
    ]
    enable_mock_restaurants = value(env, "GURUMEET_ENABLE_MOCK_RESTAURANTS")
    if enable_mock_restaurants.lower() != "true":
        required.append("HOTPEPPER_API_KEY")

    for key in required:
        has_error |= report_key(env, key)

    if placeholder(value(env, "PARTICIPANT_TOKEN_HASH_SECRET")):
        print("  WARN PARTICIPANT_TOKEN_HASH_SECRET is still a placeholder")
    if placeholder(value(env, "INTERNAL_TASK_SECRET")):
        print("  WARN INTERNAL_TASK_SECRET is still a placeholder")
    print(f"  INFO GURUMEET_ENABLE_MOCK_RESTAURANTS={enable_mock_restaurants}")
    return has_error


def check_frontend_env() -> bool:
    print("Frontend env")
    env = load_env(ROOT / "frontend" / ".env")
    has_error = False
    has_error |= report_file(ROOT / "frontend" / ".env")

    required = [
        "FRONTEND_PORT",
        "GURUMEET_API_BASE_URL",
        "GURUMEET_INVITE_BASE_URL",
        "GURUMEET_ENABLE_MOCKS",
        "DEMO_MODE",
    ]
    for key in required:
        has_error |= report_key(env, key)

    enable_mocks = value(env, "GURUMEET_ENABLE_MOCKS")
    if enable_mocks.lower() == "true":
        print("  WARN GURUMEET_ENABLE_MOCKS=true のため実APIは叩きません")
    elif enable_mocks.lower() != "false":
        print("  ERROR GURUMEET_ENABLE_MOCKS must be true or false")
        has_error = True

    demo_mode = value(env, "DEMO_MODE")
    if demo_mode.lower() == "true":
        has_error |= report_key(env, "DEMO_ROOM_CODE")
    elif demo_mode.lower() != "false":
        print("  ERROR DEMO_MODE must be true or false")
        has_error = True

    api_base_url = value(env, "GURUMEET_API_BASE_URL")
    if not api_base_url.startswith(("http://", "https://")):
        print("  ERROR GURUMEET_API_BASE_URL must start with http:// or https://")
        has_error = True
    print("  INFO frontend Makefile passes .env values via --dart-define")
    return has_error


def report_file(path: Path) -> bool:
    if path.exists():
        print(f"  OK   {path.relative_to(ROOT)} exists")
        return False
    print(f"  ERROR {path.relative_to(ROOT)} is missing")
    return True


def report_key(env: dict[str, str], key: str, default: str = "") -> bool:
    raw = value(env, key, default)
    if raw:
        source = "default" if key not in env and key not in os.environ else "configured"
        print(f"  OK   {key}={masked(key, raw)} ({source})")
        return False
    print(f"  ERROR {key} is empty or missing")
    return True


def value(env: dict[str, str], key: str, default: str = "") -> str:
    environment_value = os.environ.get(key)
    if environment_value is not None and environment_value.strip():
        return environment_value.strip()
    return env.get(key, default).strip()


def masked(key: str, raw: str) -> str:
    if key in SECRET_KEYS:
        return "<configured>"
    if len(raw) > 96:
        return raw[:93] + "..."
    return raw


def placeholder(raw: str) -> bool:
    lowered = raw.lower()
    return not raw or "change_me" in lowered or lowered in {"secret", "password"}


def load_env(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}

    env: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, raw_value = stripped.split("=", 1)
        env[key.strip()] = unquote(raw_value.strip())
    return env


def unquote(raw: str) -> str:
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in {"'", '"'}:
        return raw[1:-1]
    return raw


if __name__ == "__main__":
    raise SystemExit(main())
