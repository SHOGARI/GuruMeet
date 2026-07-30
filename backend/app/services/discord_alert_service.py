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
        title="group_created",
        fields={
            "environment": settings.environment,
            "group_id": str(group.id),
            "participant_count": _display(group.participant_count),
            "location": group.location or "(none)",
            "budget": _budget(group.budget_min, group.budget_max),
            "restaurant_search_status": group.restaurant_search_status,
            "expires_at": _isoformat(group.expires_at),
        },
    )


def notify_cleanup_completed(
    *,
    deleted_expired_temporary_groups: int,
    summary: dict[str, Any],
    scheduled_at: datetime,
) -> None:
    send_discord_alert(
        title="cleanup_completed",
        fields={
            "environment": settings.environment,
            "deleted_expired_temporary_groups": deleted_expired_temporary_groups,
            "expired_groups": summary.get("expired_groups", 0),
            "total_expected_participants": summary.get(
                "total_expected_participants",
                0,
            ),
            "total_joined_participants": summary.get(
                "total_joined_participants",
                0,
            ),
            "total_votes": summary.get("total_votes", 0),
            "groups_with_votes": summary.get("groups_with_votes", 0),
            "restaurant_statuses": summary.get("restaurant_statuses", "(none)"),
            "top_locations": summary.get("top_locations", "(none)"),
            "scheduled_at": _isoformat(scheduled_at),
        },
    )


def notify_voting_result_viewed(
    group: TemporaryGroup,
    *,
    result: Any,
) -> None:
    top_result = result.results[0] if result.results else None
    top_restaurant = top_result.restaurant if top_result else None
    send_discord_alert(
        title="voting_result_viewed",
        fields={
            "environment": settings.environment,
            "group_id": str(group.id),
            "participant_count": _display(group.participant_count),
            "joined/completed": (
                f"{result.joined_participant_count}/"
                f"{result.completed_participant_count}"
            ),
            "is_complete": result.is_complete,
            "location": group.location or "(none)",
            "has_tie": result.has_tie,
            "top_like_count": result.top_like_count,
            "top_restaurant_name": (
                top_restaurant.name if top_restaurant is not None else "(none)"
            ),
            "created_to_result_viewed_minutes": _elapsed_minutes(group.created_at),
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
                        "inline": True,
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


def _isoformat(value: datetime) -> str:
    return value.astimezone(DISPLAY_TIMEZONE).isoformat()


def _elapsed_minutes(started_at: datetime) -> str:
    started_at_utc = started_at.astimezone(UTC)
    elapsed_seconds = (datetime.now(UTC) - started_at_utc).total_seconds()
    elapsed_minutes = max(0, round(elapsed_seconds / 60))
    return str(elapsed_minutes)


def _field_value(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, UUID):
        return str(value)
    text = _display(value)
    if len(text) > 1024:
        return f"{text[:1021]}..."
    return text
