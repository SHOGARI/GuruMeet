from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.repositories.temporary_group_repository import TemporaryGroupRepository


class TemporaryGroupCleanupService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = TemporaryGroupRepository(db)

    def delete_expired_groups(self) -> int:
        deleted_count = self.repository.delete_expired(datetime.now(UTC))
        self.db.commit()
        return deleted_count
