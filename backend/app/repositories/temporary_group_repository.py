from datetime import datetime
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.temporary_group import TemporaryGroup


class TemporaryGroupRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def add(self, group: TemporaryGroup) -> TemporaryGroup:
        self.db.add(group)
        self.db.flush()
        self.db.refresh(group)
        return group

    def get_active_by_id(
        self,
        group_id: UUID,
        now: datetime,
    ) -> TemporaryGroup | None:
        statement = select(TemporaryGroup).where(
            TemporaryGroup.id == group_id,
            TemporaryGroup.expires_at > now,
        )
        return self.db.scalar(statement)

    def get_active_by_code(
        self,
        code: str,
        now: datetime,
    ) -> TemporaryGroup | None:
        statement = select(TemporaryGroup).where(
            TemporaryGroup.code == code,
            TemporaryGroup.expires_at > now,
        )
        return self.db.scalar(statement)

    def delete_expired(self, now: datetime) -> int:
        statement = delete(TemporaryGroup).where(TemporaryGroup.expires_at <= now)
        result = self.db.execute(statement)
        return result.rowcount or 0
