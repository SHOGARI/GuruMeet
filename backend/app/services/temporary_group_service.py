from datetime import UTC, datetime, timedelta
from hashlib import sha256
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.anonymous_user import AnonymousUser
from app.models.temporary_group import TemporaryGroup
from app.models.temporary_group_participant import TemporaryGroupParticipant
from app.repositories.temporary_group_repository import TemporaryGroupRepository
from app.schemas.temporary_group import TemporaryGroupCreate
from app.services.code_generator import generate_temporary_group_code
from app.services.hotpepper_service import (
    HotPepperBudgetRangeError,
    search_restaurants_for_group,
)


class TemporaryGroupCodeCollisionError(RuntimeError):
    pass


class TemporaryGroupFullError(RuntimeError):
    pass


class TemporaryGroupNotFoundError(RuntimeError):
    pass


class TemporaryGroupSearchCriteriaError(ValueError):
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
                participant_count=data.participant_count,
                location=data.location,
                budget_min=data.budget_min,
                budget_max=data.budget_max,
                expires_at=expires_at,
            )
            try:
                self.repository.add(group)
                if data.participant_token is not None:
                    self._join_group(group, data.participant_token)
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

    def join_active_by_id(
        self,
        group_id: UUID,
        participant_token: str,
    ) -> TemporaryGroup | None:
        group = self.repository.get_active_by_id_for_update(group_id, self._now())
        if group is None:
            return None

        self._join_group(group, participant_token)
        self.db.commit()
        self.db.refresh(group)
        return group

    def join_active_by_code(
        self,
        code: str,
        participant_token: str,
    ) -> TemporaryGroup | None:
        group = self.repository.get_active_by_code_for_update(code.upper(), self._now())
        if group is None:
            return None

        self._join_group(group, participant_token)
        self.db.commit()
        self.db.refresh(group)
        return group

    def count_participants(self, group_id: UUID) -> int:
        return self.repository.count_participants(group_id)

    def is_full(self, group: TemporaryGroup, joined_participant_count: int) -> bool:
        return (
            group.participant_count is not None
            and joined_participant_count >= group.participant_count
        )

    async def search_and_save_restaurants(
        self,
        group_id: UUID,
    ) -> dict[str, object]:
        group = self.get_active_by_id(group_id)
        if group is None:
            raise TemporaryGroupNotFoundError

        location = group.location.strip() if group.location else ""
        if not location:
            raise TemporaryGroupSearchCriteriaError("location is required")
        if (
            group.budget_min is not None
            and group.budget_max is not None
            and group.budget_min > group.budget_max
        ):
            raise TemporaryGroupSearchCriteriaError(
                "budget_min must not exceed budget_max"
            )

        try:
            search_result = await search_restaurants_for_group(
                location=location,
                budget_min=group.budget_min,
                budget_max=group.budget_max,
                participant_count=group.participant_count,
            )
        except HotPepperBudgetRangeError as exc:
            raise TemporaryGroupSearchCriteriaError(str(exc)) from exc

        previous_restaurant = group.restaurant
        try:
            self.repository.update_restaurant(group, search_result)
            self.db.commit()
            self.db.refresh(group)
        except Exception:
            self.db.rollback()
            group.restaurant = previous_restaurant
            raise

        return search_result

    def _join_group(
        self,
        group: TemporaryGroup,
        participant_token: str,
    ) -> TemporaryGroupParticipant:
        now = self._now()
        user = self._get_or_create_anonymous_user(participant_token, now)
        participant = self.repository.get_participant(group.id, user.id)
        if participant is not None:
            participant.last_seen_at = now
            user.last_seen_at = now
            self.db.flush()
            return participant

        joined_participant_count = self.repository.count_participants(group.id)
        if self.is_full(group, joined_participant_count):
            raise TemporaryGroupFullError("temporary group is full")

        participant = TemporaryGroupParticipant(
            temporary_group_id=group.id,
            anonymous_user_id=user.id,
            joined_at=now,
            last_seen_at=now,
        )
        return self.repository.add_participant(participant)

    def _get_or_create_anonymous_user(
        self,
        participant_token: str,
        now: datetime,
    ) -> AnonymousUser:
        participant_token_hash = self._hash_participant_token(participant_token)
        user = self.repository.get_anonymous_user_by_token_hash(participant_token_hash)
        if user is not None:
            user.last_seen_at = now
            self.db.flush()
            return user

        try:
            with self.db.begin_nested():
                return self.repository.add_anonymous_user(
                    AnonymousUser(
                        participant_token_hash=participant_token_hash,
                        last_seen_at=now,
                    )
                )
        except IntegrityError:
            user = self.repository.get_anonymous_user_by_token_hash(
                participant_token_hash
            )
            if user is None:
                raise

            user.last_seen_at = now
            self.db.flush()
            return user

    @staticmethod
    def _hash_participant_token(participant_token: str) -> str:
        payload = (
            f"{settings.participant_token_hash_secret}:{participant_token}"
        ).encode("utf-8")
        return sha256(payload).hexdigest()

    @staticmethod
    def _now() -> datetime:
        return datetime.now(UTC)
