from datetime import datetime
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.models.anonymous_user import AnonymousUser
from app.models.temporary_group import TemporaryGroup
from app.models.temporary_group_participant import TemporaryGroupParticipant


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

    def get_active_by_id_for_update(
        self,
        group_id: UUID,
        now: datetime,
    ) -> TemporaryGroup | None:
        statement = (
            select(TemporaryGroup)
            .where(
                TemporaryGroup.id == group_id,
                TemporaryGroup.expires_at > now,
            )
            .with_for_update()
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

    def get_active_by_code_for_update(
        self,
        code: str,
        now: datetime,
    ) -> TemporaryGroup | None:
        statement = (
            select(TemporaryGroup)
            .where(
                TemporaryGroup.code == code,
                TemporaryGroup.expires_at > now,
            )
            .with_for_update()
        )
        return self.db.scalar(statement)

    def get_anonymous_user_by_token_hash(
        self,
        participant_token_hash: str,
    ) -> AnonymousUser | None:
        statement = select(AnonymousUser).where(
            AnonymousUser.participant_token_hash == participant_token_hash,
        )
        return self.db.scalar(statement)

    def add_anonymous_user(self, user: AnonymousUser) -> AnonymousUser:
        self.db.add(user)
        self.db.flush()
        self.db.refresh(user)
        return user

    def get_participant(
        self,
        group_id: UUID,
        anonymous_user_id: UUID,
    ) -> TemporaryGroupParticipant | None:
        statement = select(TemporaryGroupParticipant).where(
            TemporaryGroupParticipant.temporary_group_id == group_id,
            TemporaryGroupParticipant.anonymous_user_id == anonymous_user_id,
        )
        return self.db.scalar(statement)

    def add_participant(
        self,
        participant: TemporaryGroupParticipant,
    ) -> TemporaryGroupParticipant:
        self.db.add(participant)
        self.db.flush()
        self.db.refresh(participant)
        return participant

    def count_participants(self, group_id: UUID) -> int:
        statement = select(func.count()).select_from(TemporaryGroupParticipant).where(
            TemporaryGroupParticipant.temporary_group_id == group_id,
        )
        return self.db.scalar(statement) or 0

    def delete_expired(self, now: datetime) -> int:
        statement = delete(TemporaryGroup).where(TemporaryGroup.expires_at <= now)
        result = self.db.execute(statement)
        return result.rowcount or 0
