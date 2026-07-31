import logging
from datetime import UTC, datetime
from zoneinfo import ZoneInfo
from typing import Any
from uuid import UUID

import httpx

from app.core.config import settings
from app.models.temporary_group import TemporaryGroup

logger = logging.getLogger("gurumeet.discord_alert")

DISCORD_TIMEOUT_SECONDS = 3.0
DISPLAY_TIMEZONE = ZoneInfo("Asia/Tokyo")


def notify_group_created(
    group: TemporaryGroup,
) -> None:
    send_discord_alert(
        title="グループ作成",
        fields={
            "環境": settings.environment,
            "グループID": str(group.id),
            "人数": _display(group.participant_count),
            "場所": group.location or "(none)",
            "予算": _budget(group.budget_min, group.budget_max),
            "店舗検索": group.restaurant_search_status,
            "無効化時刻": _format_jst(group.expires_at),
        },
    )


def notify_cleanup_completed(
    *,
    deleted_expired_temporary_groups: int,
    summary: dict[str, Any],
    scheduled_at: datetime,
) -> None:
    send_discord_alert(
        title="期限切れグループ削除",
        fields={
            "環境": settings.environment,
            "削除グループ数": deleted_expired_temporary_groups,
            "期限切れグループ数": summary.get("expired_groups", 0),
            "予定人数合計": summary.get(
                "total_expected_participants",
                0,
            ),
            "参加人数合計": summary.get(
                "total_joined_participants",
                0,
            ),
            "投票数": summary.get("total_votes", 0),
            "投票ありグループ数": summary.get("groups_with_votes", 0),
            "店舗検索状態": summary.get("restaurant_statuses", "(none)"),
            "多い場所": summary.get("top_locations", "(none)"),
            "削除実行時刻": _format_jst(scheduled_at),
        },
    )


def notify_voting_completed(
    group: TemporaryGroup,
    *,
    result: Any,
) -> None:
    top_result = result.results[0] if result.results else None
    top_restaurant = top_result.restaurant if top_result else None
    send_discord_alert(
        title="投票完了",
        fields={
            "環境": settings.environment,
            "グループID": str(group.id),
            "人数": _display(group.participant_count),
            "参加/完了": (
                f"{result.joined_participant_count}/"
                f"{result.completed_participant_count}"
            ),
            "完了状態": result.is_complete,
            "場所": group.location or "(none)",
            "同率あり": result.has_tie,
            "最多いいね": result.top_like_count,
            "1位候補": (
                top_restaurant.name if top_restaurant is not None else "(none)"
            ),
            "完了まで": _elapsed_minutes(group.created_at),
            "完了時刻": (
                _format_jst(group.voting_completed_at)
                if group.voting_completed_at is not None
                else "(none)"
            ),
        },
    )


def send_discord_alert(
    *,
    title: str,
    fields: dict[str, Any],
) -> None:
    webhook_url = _webhook_url()
    if webhook_url is None:
        return

    payload = {
        "allowed_mentions": {"parse": []},
        "embeds": [
            {
                "title": title,
                "color": 0x2563EB,
                "fields": [
                    {
                        "name": key,
                        "value": _field_value(value),
                        "inline": False,
                    }
                    for key, value in fields.items()
                ],
            }
        ],
    }
    try:
        with httpx.Client(timeout=DISCORD_TIMEOUT_SECONDS) as client:
            response = client.post(webhook_url, json=payload)
            response.raise_for_status()
    except Exception:
        logger.exception("discord_alert_failed title=%s", title)


def _webhook_url() -> str | None:
    secret = settings.discord_alert_webhook_url
    if secret is None:
        return None
    value = secret.get_secret_value().strip()
    return value or None


def _budget(budget_min: int | None, budget_max: int | None) -> str:
    if budget_min is None and budget_max is None:
        return "(none)"
    return f"{_display(budget_min)}-{_display(budget_max)}"


def _display(value: object) -> str:
    return "(none)" if value is None else str(value)


def _format_jst(value: datetime) -> str:
    return value.astimezone(DISPLAY_TIMEZONE).strftime("%Y-%m-%d %H:%M:%S JST")


def _elapsed_minutes(started_at: datetime) -> str:
    started_at_utc = started_at.astimezone(UTC)
    elapsed_seconds = (datetime.now(UTC) - started_at_utc).total_seconds()
    elapsed_minutes = max(0, round(elapsed_seconds / 60))
    return f"{elapsed_minutes}分"


def _field_value(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, UUID):
        return str(value)
    text = _display(value)
    if len(text) > 1024:
        return f"{text[:1021]}..."
    return text
