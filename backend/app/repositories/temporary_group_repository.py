from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.models.anonymous_user import AnonymousUser
from app.models.custom_location import CustomLocation
from app.models.temporary_group import TemporaryGroup
from app.models.temporary_group_participant import TemporaryGroupParticipant
from app.models.temporary_group_vote import TemporaryGroupVote


class TemporaryGroupRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def add(self, group: TemporaryGroup) -> TemporaryGroup:
        self.db.add(group)
        self.db.flush()
        self.db.refresh(group)
        return group

    def update_restaurant(
        self,
        group: TemporaryGroup,
        restaurant: dict[str, Any],
    ) -> TemporaryGroup:
        group.restaurant = restaurant
        self.db.flush()
        return group

    def start_voting(
        self,
        group: TemporaryGroup,
        started_at: datetime,
    ) -> TemporaryGroup:
        if group.voting_started_at is None:
            group.voting_started_at = started_at
            self.db.flush()
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

    def list_participants(
        self,
        group_id: UUID,
    ) -> list[TemporaryGroupParticipant]:
        statement = (
            select(TemporaryGroupParticipant)
            .where(TemporaryGroupParticipant.temporary_group_id == group_id)
            .order_by(TemporaryGroupParticipant.joined_at)
        )
        return list(self.db.scalars(statement))

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

    def get_vote(
        self,
        group_id: UUID,
        anonymous_user_id: UUID,
        restaurant_id: str,
    ) -> TemporaryGroupVote | None:
        statement = select(TemporaryGroupVote).where(
            TemporaryGroupVote.temporary_group_id == group_id,
            TemporaryGroupVote.anonymous_user_id == anonymous_user_id,
            TemporaryGroupVote.restaurant_id == restaurant_id,
        )
        return self.db.scalar(statement)

    def add_vote(self, vote: TemporaryGroupVote) -> TemporaryGroupVote:
        self.db.add(vote)
        self.db.flush()
        self.db.refresh(vote)
        return vote

    def list_votes(self, group_id: UUID) -> list[TemporaryGroupVote]:
        statement = select(TemporaryGroupVote).where(
            TemporaryGroupVote.temporary_group_id == group_id,
        )
        return list(self.db.scalars(statement))

    def list_expired(self, now: datetime) -> list[TemporaryGroup]:
        statement = (
            select(TemporaryGroup)
            .where(TemporaryGroup.expires_at <= now)
            .order_by(TemporaryGroup.created_at)
        )
        return list(self.db.scalars(statement))

    def delete_expired(self, now: datetime) -> int:
        statement = delete(TemporaryGroup).where(TemporaryGroup.expires_at <= now)
        result = self.db.execute(statement)
        return result.rowcount or 0

    def delete_expired_custom_locations(self, now: datetime) -> int:
        statement = delete(CustomLocation).where(
            CustomLocation.expires_at.is_not(None),
            CustomLocation.expires_at <= now,
        )
        result = self.db.execute(statement)
        return result.rowcount or 0
