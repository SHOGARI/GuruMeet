from collections import Counter
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.orm import Session

from app.repositories.temporary_group_repository import TemporaryGroupRepository
from app.services.discord_alert_service import notify_cleanup_completed


class TemporaryGroupCleanupService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = TemporaryGroupRepository(db)

    def delete_expired_groups(self) -> int:
        now = datetime.now(UTC)
        summary = self._build_cleanup_summary(now)
        deleted_count = self.repository.delete_expired(now)
        self.db.commit()
        notify_cleanup_completed(
            deleted_expired_temporary_groups=deleted_count,
            summary=summary,
            scheduled_at=now,
        )
        return deleted_count

    def _build_cleanup_summary(self, now: datetime) -> dict[str, Any]:
        groups = self.repository.list_expired(now)
        total_expected_participants = sum(
            group.participant_count or 0 for group in groups
        )
        participant_counts = [
            self.repository.count_participants(group.id) for group in groups
        ]
        vote_counts = [len(self.repository.list_votes(group.id)) for group in groups]
        restaurant_statuses = Counter(
            group.restaurant_search_status for group in groups
        )
        locations = Counter(group.location or "(none)" for group in groups)

        return {
            "expired_groups": len(groups),
            "total_expected_participants": total_expected_participants,
            "total_joined_participants": sum(participant_counts),
            "total_votes": sum(vote_counts),
            "groups_with_votes": sum(
                1 for vote_count in vote_counts if vote_count > 0
            ),
            "restaurant_statuses": _format_counter(restaurant_statuses),
            "top_locations": _format_counter(locations, limit=5),
        }


def _format_counter(counter: Counter[str], *, limit: int | None = None) -> str:
    items = counter.most_common(limit)
    if not items:
        return "(none)"
    return ", ".join(f"{name}:{count}" for name, count in items)
