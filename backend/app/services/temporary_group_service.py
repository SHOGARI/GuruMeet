from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.temporary_group import TemporaryGroup
from app.repositories.temporary_group_repository import TemporaryGroupRepository
from app.schemas.temporary_group import TemporaryGroupCreate
from app.services.code_generator import generate_temporary_group_code


class TemporaryGroupCodeCollisionError(RuntimeError):
    pass


class TemporaryGroupService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = TemporaryGroupRepository(db)

    def create_group(self, data: TemporaryGroupCreate) -> TemporaryGroup:
        expires_at = self._now() + timedelta(
            minutes=settings.temporary_group_ttl_minutes
        )

        for _ in range(settings.temporary_group_code_max_attempts):
            group = TemporaryGroup(
                code=generate_temporary_group_code(),
                creator_id=data.creator_id,
                expires_at=expires_at,
            )
            try:
                self.repository.add(group)
                self.db.commit()
                self.db.refresh(group)
                return group
            except IntegrityError:
                self.db.rollback()

        raise TemporaryGroupCodeCollisionError(
            "temporary group code generation exceeded max attempts"
        )

    def get_active_by_id(self, group_id: UUID) -> TemporaryGroup | None:
        return self.repository.get_active_by_id(group_id, self._now())

    def get_active_by_code(self, code: str) -> TemporaryGroup | None:
        return self.repository.get_active_by_code(code.upper(), self._now())

    @staticmethod
    def _now() -> datetime:
        return datetime.now(UTC)
