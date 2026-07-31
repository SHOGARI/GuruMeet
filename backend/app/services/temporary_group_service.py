from datetime import UTC, datetime, timedelta
from hashlib import sha256
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.anonymous_user import AnonymousUser
from app.models.custom_location import CustomLocation
from app.models.temporary_group import (
    RESTAURANT_SEARCH_STATUS_NOT_REQUESTED,
    RESTAURANT_SEARCH_STATUS_NO_RESULTS,
    RESTAURANT_SEARCH_STATUS_SUCCEEDED,
    TemporaryGroup,
)
from app.models.location import (
    LOCATION_TYPE_MUNICIPALITY,
    LOCATION_TYPE_STATION,
    Location,
)
from app.repositories.location_repository import LocationRepository
from app.models.temporary_group_participant import TemporaryGroupParticipant
from app.models.temporary_group_vote import TemporaryGroupVote
from app.repositories.temporary_group_repository import TemporaryGroupRepository
from app.schemas.temporary_group import (
    TemporaryGroupCreate,
    TemporaryGroupRestaurant,
    TemporaryGroupRestaurantResult,
    TemporaryGroupVoteSubmitResponse,
    TemporaryGroupVotingProgress,
    TemporaryGroupVotingResult,
    TemporaryGroupParticipantVotingProgress,
)
from app.services.code_generator import generate_temporary_group_code
from app.services.hotpepper_service import (
    HotPepperBudgetRangeError,
    search_restaurants_for_group_by_coordinates,
)
from app.services.discord_alert_service import notify_voting_completed


class TemporaryGroupCodeCollisionError(RuntimeError):
    pass


class TemporaryGroupFullError(RuntimeError):
    pass


class TemporaryGroupNotFoundError(RuntimeError):
    pass


class TemporaryGroupSearchCriteriaError(ValueError):
    pass


class TemporaryGroupVotingCandidatesError(ValueError):
    pass


class TemporaryGroupVotingNotStartedError(RuntimeError):
    pass


class TemporaryGroupVotingNotCompleteError(RuntimeError):
    pass


class TemporaryGroupVotingCompleteError(RuntimeError):
    pass


class TemporaryGroupVotingNotReadyError(RuntimeError):
    pass


class TemporaryGroupParticipantNotFoundError(RuntimeError):
    pass


class TemporaryGroupRestaurantNotFoundError(ValueError):
    pass


class TemporaryGroupService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = TemporaryGroupRepository(db)

    def create_group(
        self,
        data: TemporaryGroupCreate,
        restaurant: dict[str, Any] | None,
        restaurant_search_status: str,
    ) -> TemporaryGroup:
        expires_at = self._now() + timedelta(
            minutes=settings.temporary_group_ttl_minutes
        )
        location_entry = self._resolve_location_entry(data.location_id)
        custom_location_entry = self._build_custom_location(data, expires_at)
        location_value = self._group_location_value(
            data,
            location_entry,
            custom_location_entry,
        )

        for _ in range(settings.temporary_group_code_max_attempts):
            group = TemporaryGroup(
                code=generate_temporary_group_code(),
                creator_id=data.creator_id,
                participant_count=data.participant_count,
                location=location_value,
                location_id=location_entry.id if location_entry else None,
                custom_location_id=(
                    custom_location_entry.id if custom_location_entry else None
                ),
                budget_min=data.budget_min,
                budget_max=data.budget_max,
                restaurant=restaurant,
                restaurant_search_status=restaurant_search_status,
                expires_at=expires_at,
            )
            try:
                if custom_location_entry is not None:
                    self.db.add(custom_location_entry)
                    self.db.flush()
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

    @staticmethod
    async def search_restaurants_for_create(
        data: TemporaryGroupCreate,
        db: Session | None = None,
    ) -> tuple[dict[str, Any] | None, str]:
        if (
            data.budget_min is not None
            and data.budget_max is not None
            and data.budget_min > data.budget_max
        ):
            raise TemporaryGroupSearchCriteriaError(
                "budget_min must not exceed budget_max"
            )

        location_entry = TemporaryGroupService._resolve_location_entry_from_db(
            data.location_id,
            db,
        )
        if location_entry is not None:
            radius_meters = TemporaryGroupService._radius_meters_for_location(
                location_entry
            )
            try:
                if settings.enable_mock_restaurants:
                    restaurant = TemporaryGroupService._mock_restaurant_search_result(
                        location_entry.name
                    )
                else:
                    restaurant = await search_restaurants_for_group_by_coordinates(
                        latitude=location_entry.latitude,
                        longitude=location_entry.longitude,
                        radius_meters=radius_meters,
                        budget_min=data.budget_min,
                        budget_max=data.budget_max,
                        participant_count=data.participant_count,
                    )
            except HotPepperBudgetRangeError as exc:
                raise TemporaryGroupSearchCriteriaError(str(exc)) from exc

            restaurants = restaurant.get("restaurants")
            if isinstance(restaurants, list) and restaurants:
                return restaurant, RESTAURANT_SEARCH_STATUS_SUCCEEDED

            return restaurant, RESTAURANT_SEARCH_STATUS_NO_RESULTS

        custom_location = data.custom_location
        if custom_location is not None:
            try:
                if settings.enable_mock_restaurants:
                    restaurant = TemporaryGroupService._mock_restaurant_search_result(
                        custom_location.display_name
                    )
                else:
                    restaurant = await search_restaurants_for_group_by_coordinates(
                        latitude=custom_location.latitude,
                        longitude=custom_location.longitude,
                        radius_meters=(
                            settings.hotpepper_custom_location_search_radius_meters
                        ),
                        budget_min=data.budget_min,
                        budget_max=data.budget_max,
                        participant_count=data.participant_count,
                    )
            except HotPepperBudgetRangeError as exc:
                raise TemporaryGroupSearchCriteriaError(str(exc)) from exc

            restaurants = restaurant.get("restaurants")
            if isinstance(restaurants, list) and restaurants:
                return restaurant, RESTAURANT_SEARCH_STATUS_SUCCEEDED

            return restaurant, RESTAURANT_SEARCH_STATUS_NO_RESULTS

        if data.location is None or not data.location.strip():
            return None, RESTAURANT_SEARCH_STATUS_NOT_REQUESTED

        raise TemporaryGroupSearchCriteriaError(
            "location_id is required for restaurant search"
        )

    def _resolve_location_entry(
        self,
        location_id: str | None,
    ) -> Location | None:
        return self._resolve_location_entry_from_db(location_id, self.db)

    @staticmethod
    def _resolve_location_entry_from_db(
        location_id: str | None,
        db: Session | None,
    ) -> Location | None:
        normalized_location_id = location_id.strip() if location_id else ""
        if not normalized_location_id:
            return None
        if db is None:
            raise TemporaryGroupSearchCriteriaError("location_id requires database")

        location_type, separator, source_key = normalized_location_id.partition(":")
        if (
            separator != ":"
            or location_type not in {LOCATION_TYPE_MUNICIPALITY, LOCATION_TYPE_STATION}
            or not source_key
            or ":" in source_key
        ):
            raise TemporaryGroupSearchCriteriaError("invalid location_id")

        entry = LocationRepository(db).get_by_location_id(normalized_location_id)
        if entry is None:
            raise TemporaryGroupSearchCriteriaError("invalid location_id")
        return entry

    @staticmethod
    def _radius_meters_for_location(
        location_entry: Location,
    ) -> int:
        if location_entry.location_type == LOCATION_TYPE_STATION:
            return settings.hotpepper_station_search_radius_meters
        return settings.hotpepper_municipality_search_radius_meters

    @staticmethod
    def _build_custom_location(
        data: TemporaryGroupCreate,
        expires_at: datetime,
    ) -> CustomLocation | None:
        custom_location = data.custom_location
        if custom_location is None:
            return None
        return CustomLocation(
            id=uuid4(),
            display_name=custom_location.display_name.strip(),
            prefecture_name=(
                custom_location.prefecture_name.strip()
                if custom_location.prefecture_name
                else None
            ),
            latitude=custom_location.latitude,
            longitude=custom_location.longitude,
            accuracy_meters=custom_location.accuracy_meters,
            source=custom_location.source,
            expires_at=expires_at,
        )

    @staticmethod
    def _group_location_value(
        data: TemporaryGroupCreate,
        location_entry: Location | None,
        custom_location_entry: CustomLocation | None = None,
    ) -> str | None:
        location = data.location.strip() if data.location else ""
        if location:
            return location
        if custom_location_entry is not None:
            return custom_location_entry.display_name
        if location_entry is not None:
            return location_entry.display_name
        return None

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

    def start_voting(
        self,
        group_id: UUID,
        participant_token: str,
    ) -> TemporaryGroupVotingProgress:
        group = self.repository.get_active_by_id_for_update(group_id, self._now())
        if group is None:
            raise TemporaryGroupNotFoundError

        self._require_participant(group.id, participant_token)
        joined_participant_count = self.repository.count_participants(group.id)
        if (
            group.participant_count is not None
            and joined_participant_count < group.participant_count
        ):
            raise TemporaryGroupVotingNotReadyError

        self.repository.start_voting(group, self._now())
        self.db.commit()
        self.db.refresh(group)
        return self.get_voting_progress(group.id)

    def submit_vote(
        self,
        group_id: UUID,
        participant_token: str,
        restaurant_id: str,
        liked: bool,
    ) -> TemporaryGroupVoteSubmitResponse:
        group = self.repository.get_active_by_id_for_update(group_id, self._now())
        if group is None:
            raise TemporaryGroupNotFoundError
        if group.voting_started_at is None:
            raise TemporaryGroupVotingNotStartedError

        participant = self._require_participant(group.id, participant_token)
        restaurants = self._candidate_restaurants(group)
        if restaurant_id not in {restaurant.id for restaurant in restaurants}:
            raise TemporaryGroupRestaurantNotFoundError

        vote = self.repository.get_vote(
            group.id,
            participant.anonymous_user_id,
            restaurant_id,
        )
        if group.voting_completed_at is not None:
            if vote is not None and vote.liked == liked:
                return TemporaryGroupVoteSubmitResponse(
                    restaurant_id=restaurant_id,
                    liked=liked,
                    progress=self._build_voting_progress(group),
                )
            raise TemporaryGroupVotingCompleteError

        if vote is None:
            self.repository.add_vote(
                TemporaryGroupVote(
                    temporary_group_id=group.id,
                    anonymous_user_id=participant.anonymous_user_id,
                    restaurant_id=restaurant_id,
                    liked=liked,
                )
            )
        else:
            vote.liked = liked
            self.db.flush()

        progress = self._build_voting_progress(group)
        should_notify_completion = False
        if progress.is_complete and group.voting_completed_at is None:
            self.repository.complete_voting(group, self._now())
            should_notify_completion = True

        self.db.commit()
        self.db.refresh(group)
        progress = self._build_voting_progress(group)
        if should_notify_completion:
            notify_voting_completed(group, result=self.get_voting_result(group.id))

        return TemporaryGroupVoteSubmitResponse(
            restaurant_id=restaurant_id,
            liked=liked,
            progress=progress,
        )

    def get_voting_progress(self, group_id: UUID) -> TemporaryGroupVotingProgress:
        group = self.get_active_by_id(group_id)
        if group is None:
            raise TemporaryGroupNotFoundError

        return self._build_voting_progress(group)

    def _build_voting_progress(
        self,
        group: TemporaryGroup,
    ) -> TemporaryGroupVotingProgress:
        candidate_count = len(self._candidate_restaurants(group, required=False))
        participants = self.repository.list_participants(group.id)
        votes = self.repository.list_votes(group.id)
        completed_vote_counts = {
            participant.anonymous_user_id: 0 for participant in participants
        }
        for vote in votes:
            if vote.anonymous_user_id in completed_vote_counts:
                completed_vote_counts[vote.anonymous_user_id] += 1

        participant_progress = [
            TemporaryGroupParticipantVotingProgress(
                anonymous_user_id=participant.anonymous_user_id,
                completed_vote_count=min(
                    completed_vote_counts[participant.anonymous_user_id],
                    candidate_count,
                ),
                is_complete=(
                    candidate_count > 0
                    and completed_vote_counts[participant.anonymous_user_id]
                    >= candidate_count
                ),
            )
            for participant in participants
        ]
        completed_participant_count = sum(
            1 for participant in participant_progress if participant.is_complete
        )
        joined_participant_count = len(participants)

        return TemporaryGroupVotingProgress(
            voting_started_at=group.voting_started_at,
            voting_completed_at=group.voting_completed_at,
            candidate_count=candidate_count,
            participant_count=group.participant_count,
            joined_participant_count=joined_participant_count,
            completed_participant_count=completed_participant_count,
            is_complete=(
                joined_participant_count > 0
                and completed_participant_count == joined_participant_count
            ),
            participants=participant_progress,
        )

    def get_voting_result(self, group_id: UUID) -> TemporaryGroupVotingResult:
        group = self.get_active_by_id(group_id)
        if group is None:
            raise TemporaryGroupNotFoundError
        if group.voting_started_at is None:
            raise TemporaryGroupVotingNotStartedError
        if group.voting_completed_at is None:
            raise TemporaryGroupVotingNotCompleteError

        restaurants = self._candidate_restaurants(group)
        progress = self.get_voting_progress(group.id)
        votes = self.repository.list_votes(group.id)
        votes_by_restaurant = {
            restaurant.id: {"like": 0, "reject": 0} for restaurant in restaurants
        }
        for vote in votes:
            counts = votes_by_restaurant.get(vote.restaurant_id)
            if counts is None:
                continue
            counts["like" if vote.liked else "reject"] += 1

        sorted_restaurants = sorted(
            restaurants,
            key=lambda restaurant: (
                -votes_by_restaurant[restaurant.id]["like"],
                votes_by_restaurant[restaurant.id]["reject"],
                restaurants.index(restaurant),
            ),
        )

        results: list[TemporaryGroupRestaurantResult] = []
        previous_like_count = -1
        current_rank = 0
        for index, restaurant in enumerate(sorted_restaurants):
            counts = votes_by_restaurant[restaurant.id]
            like_count = counts["like"]
            reject_count = counts["reject"]
            vote_count = like_count + reject_count
            if like_count != previous_like_count:
                current_rank = index + 1
                previous_like_count = like_count
            results.append(
                TemporaryGroupRestaurantResult(
                    restaurant=restaurant,
                    like_count=like_count,
                    reject_count=reject_count,
                    vote_count=vote_count,
                    rank=current_rank,
                    like_rate=0 if vote_count == 0 else like_count / vote_count,
                )
            )

        top_like_count = results[0].like_count if results else 0
        top_result_count = sum(
            1 for result in results if result.like_count == top_like_count
        )

        return TemporaryGroupVotingResult(
            voting_started_at=group.voting_started_at,
            voting_completed_at=group.voting_completed_at,
            candidate_count=progress.candidate_count,
            joined_participant_count=progress.joined_participant_count,
            completed_participant_count=progress.completed_participant_count,
            is_complete=progress.is_complete,
            has_tie=top_result_count > 1,
            top_like_count=top_like_count,
            results=results,
        )

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

    def _require_participant(
        self,
        group_id: UUID,
        participant_token: str,
    ) -> TemporaryGroupParticipant:
        user = self.repository.get_anonymous_user_by_token_hash(
            self._hash_participant_token(participant_token)
        )
        if user is None:
            raise TemporaryGroupParticipantNotFoundError

        participant = self.repository.get_participant(group_id, user.id)
        if participant is None:
            raise TemporaryGroupParticipantNotFoundError

        now = self._now()
        user.last_seen_at = now
        participant.last_seen_at = now
        self.db.flush()
        return participant

    def _candidate_restaurants(
        self,
        group: TemporaryGroup,
        *,
        required: bool = True,
    ) -> list[TemporaryGroupRestaurant]:
        restaurant_payload = group.restaurant
        if not isinstance(restaurant_payload, dict):
            if not required:
                return []
            raise TemporaryGroupVotingCandidatesError("restaurant candidates are required")

        restaurants_payload = restaurant_payload.get("restaurants")
        if not isinstance(restaurants_payload, list) or not restaurants_payload:
            if not required:
                return []
            raise TemporaryGroupVotingCandidatesError("restaurant candidates are required")

        return [
            TemporaryGroupRestaurant.model_validate(restaurant)
            for restaurant in restaurants_payload
        ]

    @staticmethod
    def _mock_restaurant_search_result(location: str) -> dict[str, object]:
        restaurants = [
            {
                "id": "e2e-ginza-sora",
                "name": "GINZA SORA",
                "address": f"東京都{location}1-2-3",
                "access": f"{location}駅 徒歩3分",
                "genre": "モダンビストロ",
                "budget": "3,000〜5,000円",
                "image_url": (
                    "https://images.unsplash.com/photo-1555396273-367ea4eb4db5"
                    "?auto=format&fit=crop&w=1200&q=85"
                ),
                "shop_url": "https://example.com/e2e-ginza-sora",
            },
            {
                "id": "e2e-kitchen-noka",
                "name": "KITCHEN noka",
                "address": f"東京都{location}4-5-6",
                "access": f"{location}駅 徒歩6分",
                "genre": "イタリアン",
                "budget": "2,000〜3,000円",
                "image_url": (
                    "https://images.unsplash.com/photo-1544148103-0773bf10d330"
                    "?auto=format&fit=crop&w=1200&q=85"
                ),
                "shop_url": "https://example.com/e2e-kitchen-noka",
            },
            {
                "id": "e2e-shokudo-koharu",
                "name": "食堂 こはる",
                "address": f"東京都{location}7-8-9",
                "access": f"{location}駅 徒歩8分",
                "genre": "創作和食",
                "budget": "2,000〜3,000円",
                "image_url": (
                    "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4"
                    "?auto=format&fit=crop&w=1200&q=85"
                ),
                "shop_url": "https://example.com/e2e-shokudo-koharu",
            },
        ]
        return {
            "restaurants": restaurants,
            "searched_at": datetime.now(UTC).isoformat(),
        }

    @staticmethod
    def _now() -> datetime:
        return datetime.now(UTC)
