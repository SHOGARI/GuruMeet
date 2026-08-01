from datetime import UTC, datetime
import logging
from typing import Any

from sqlalchemy.orm import Session

from app.repositories.temporary_group_repository import TemporaryGroupRepository
from app.services.discord_alert_service import notify_cleanup_completed

logger = logging.getLogger("gurumeet.cleanup")


class TemporaryGroupCleanupService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = TemporaryGroupRepository(db)

    def delete_expired_groups(self) -> int:
        now = datetime.now(UTC)
        summary = self._build_cleanup_summary(now)
        deleted_count = self.repository.delete_expired(now)
        self.repository.delete_expired_custom_locations(now)
        self.db.commit()
        notify_cleanup_completed(
            deleted_expired_temporary_groups=deleted_count,
            summary=summary,
            scheduled_at=now,
        )
        return deleted_count

    def _build_cleanup_summary(self, now: datetime) -> dict[str, Any]:
        try:
            return self.repository.expired_summary(now)
        except Exception:
            logger.exception("cleanup_summary_failed")
            self.db.rollback()
            return {
                "expired_groups": 0,
                "total_expected_participants": 0,
                "total_joined_participants": 0,
                "total_votes": 0,
                "groups_with_votes": 0,
                "restaurant_statuses": "(summary_failed)",
                "top_locations": "(summary_failed)",
            }
