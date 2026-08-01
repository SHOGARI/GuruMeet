from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import uuid4
import unittest

from fastapi.testclient import TestClient

from app.main import app
from app.schemas.temporary_group import (
    TemporaryGroupParticipantVotingProgress,
    TemporaryGroupVotingProgress,
)
from app.services.temporary_group_service import (
    TemporaryGroupParticipantNotFoundError,
    TemporaryGroupRestaurantDecisionError,
    TemporaryGroupRestaurantNotFoundError,
    TemporaryGroupService,
    TemporaryGroupHostRequiredError,
    TemporaryGroupVotingCandidatesError,
    TemporaryGroupVotingCompleteError,
    TemporaryGroupVotingNotCompleteError,
    TemporaryGroupVotingNotReadyError,
    TemporaryGroupVotingNotStartedError,
)


TOKEN = "participant-token-123"


class FakeTemporaryGroupRepository:
    def __init__(self, group: SimpleNamespace) -> None:
        self.group = group
        self.user = SimpleNamespace(id=uuid4(), last_seen_at=None)
        self.participant = SimpleNamespace(
            anonymous_user_id=self.user.id,
            last_seen_at=None,
        )
        self.votes: list[SimpleNamespace] = []
        self.token_hash = TemporaryGroupService._hash_participant_token(TOKEN)

    def get_active_by_id(self, group_id, now):
        return self.group if group_id == self.group.id else None

    def get_active_by_id_for_update(self, group_id, now):
        return self.get_active_by_id(group_id, now)

    def get_anonymous_user_by_token_hash(self, participant_token_hash):
        if participant_token_hash == self.token_hash:
            return self.user
        return None

    def get_participant(self, group_id, anonymous_user_id):
        if group_id == self.group.id and anonymous_user_id == self.user.id:
            return self.participant
        return None

    def list_participants(self, group_id):
        return [self.participant] if group_id == self.group.id else []

    def count_participants(self, group_id):
        return len(self.list_participants(group_id))

    def start_voting(self, group, started_at):
        group.voting_started_at = group.voting_started_at or started_at
        return group

    def complete_voting(self, group, completed_at):
        group.voting_completed_at = group.voting_completed_at or completed_at
        return group

    def select_restaurant(self, group, restaurant_id):
        group.selected_restaurant_id = restaurant_id
        return group

    def expire(self, group, expired_at):
        group.expires_at = expired_at
        return group

    def get_vote(self, group_id, anonymous_user_id, restaurant_id):
        for vote in self.votes:
            if (
                vote.temporary_group_id == group_id
                and vote.anonymous_user_id == anonymous_user_id
                and vote.restaurant_id == restaurant_id
            ):
                return vote
        return None

    def add_vote(self, vote):
        self.votes.append(vote)
        return vote

    def list_votes(self, group_id):
        return [vote for vote in self.votes if vote.temporary_group_id == group_id]


def make_group(
    *,
    restaurant=None,
    voting_started_at=None,
    voting_completed_at=None,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=uuid4(),
        expires_at=datetime.now(UTC) + timedelta(hours=1),
        participant_count=1,
        restaurant=restaurant
        if restaurant is not None
        else {
            "restaurants": [
                {
                    "id": "shop-a",
                    "name": "Shop A",
                    "address": "東京都渋谷区1-1",
                    "access": "渋谷駅徒歩3分",
                    "genre": "居酒屋",
                    "budget": "2,000〜3,000円",
                    "image_url": "https://example.com/a.jpg",
                    "shop_url": "https://example.com/a",
                },
                {
                    "id": "shop-b",
                    "name": "Shop B",
                    "address": "東京都渋谷区2-2",
                    "access": "渋谷駅徒歩5分",
                    "genre": "焼肉",
                    "budget": "3,000〜5,000円",
                    "image_url": "https://example.com/b.jpg",
                    "shop_url": "https://example.com/b",
                },
            ]
        },
        voting_started_at=voting_started_at,
        voting_completed_at=voting_completed_at,
        selected_restaurant_id=None,
        creator_id=None,
    )


class TemporaryGroupVotingServiceTests(unittest.TestCase):
    def make_service(self, group: SimpleNamespace):
        service = TemporaryGroupService(MagicMock())
        repository = FakeTemporaryGroupRepository(group)
        service.repository = repository
        return service, repository

    def test_start_voting_sets_started_at_and_returns_progress(self) -> None:
        group = make_group()
        service, _ = self.make_service(group)

        progress = service.start_voting(group.id, TOKEN)

        self.assertIsNotNone(group.voting_started_at)
        self.assertEqual(progress.candidate_count, 2)
        self.assertEqual(progress.joined_participant_count, 1)
        self.assertFalse(progress.is_complete)

    def test_dissolve_group_sets_expires_at_to_now(self) -> None:
        group = make_group()
        service, _ = self.make_service(group)
        before = datetime.now(UTC)

        dissolved = service.dissolve_group(group.id, TOKEN)

        self.assertIs(dissolved, group)
        self.assertGreaterEqual(group.expires_at, before)
        self.assertLessEqual(group.expires_at, datetime.now(UTC))

    def test_dissolve_group_requires_host_when_creator_is_set(self) -> None:
        group = make_group()
        service, repository = self.make_service(group)
        group.creator_id = str(uuid4())

        with self.assertRaises(TemporaryGroupHostRequiredError):
            service.dissolve_group(group.id, TOKEN)

        self.assertGreater(group.expires_at, datetime.now(UTC))

        group.creator_id = str(repository.user.id)
        service.dissolve_group(group.id, TOKEN)
        self.assertLessEqual(group.expires_at, datetime.now(UTC))

    def test_start_voting_allows_missing_restaurant_candidates(self) -> None:
        group = make_group(restaurant={"restaurants": []})
        service, _ = self.make_service(group)

        progress = service.start_voting(group.id, TOKEN)

        self.assertEqual(progress.candidate_count, 0)
        self.assertIsNotNone(group.voting_started_at)

    def test_start_voting_requires_full_room_when_count_is_set(self) -> None:
        group = make_group()
        group.participant_count = 2
        service, _ = self.make_service(group)

        with self.assertRaises(TemporaryGroupVotingNotReadyError):
            service.start_voting(group.id, TOKEN)

    def test_submit_vote_requires_started_voting(self) -> None:
        group = make_group()
        service, _ = self.make_service(group)

        with self.assertRaises(TemporaryGroupVotingNotStartedError):
            service.submit_vote(group.id, TOKEN, "shop-a", True)

    def test_submit_vote_requires_joined_participant(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, _ = self.make_service(group)

        with self.assertRaises(TemporaryGroupParticipantNotFoundError):
            service.submit_vote(group.id, "not-joined-token", "shop-a", True)

    def test_submit_vote_rejects_unknown_restaurant(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, _ = self.make_service(group)

        with self.assertRaises(TemporaryGroupRestaurantNotFoundError):
            service.submit_vote(group.id, TOKEN, "missing-shop", True)

    def test_submit_vote_upserts_and_progress_completes(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, repository = self.make_service(group)

        service.submit_vote(group.id, TOKEN, "shop-a", True)
        response = service.submit_vote(group.id, TOKEN, "shop-b", False)
        service.submit_vote(group.id, TOKEN, "shop-a", False)

        self.assertEqual(len(repository.votes), 2)
        self.assertFalse(repository.votes[0].liked)
        self.assertTrue(response.progress.is_complete)
        self.assertEqual(response.progress.completed_participant_count, 1)
        self.assertIsNotNone(group.voting_completed_at)

    def test_submit_vote_notifies_once_when_restaurant_is_decided(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, _ = self.make_service(group)

        with patch(
            "app.services.temporary_group_service.notify_restaurant_decided"
        ) as notify:
            service.submit_vote(group.id, TOKEN, "shop-a", True)
            notify.assert_not_called()

            service.submit_vote(group.id, TOKEN, "shop-b", False)
            notify.assert_called_once()

            service.submit_vote(group.id, TOKEN, "shop-a", False)
            notify.assert_called_once()

    def test_submit_vote_does_not_notify_decision_when_tied(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, _ = self.make_service(group)

        with patch(
            "app.services.temporary_group_service.notify_restaurant_decided"
        ) as notify:
            service.submit_vote(group.id, TOKEN, "shop-a", True)
            service.submit_vote(group.id, TOKEN, "shop-b", True)

            notify.assert_not_called()

    def test_submit_vote_rejects_changes_after_group_completion(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, _ = self.make_service(group)
        service.submit_vote(group.id, TOKEN, "shop-a", True)
        service.submit_vote(group.id, TOKEN, "shop-b", False)

        response = service.submit_vote(group.id, TOKEN, "shop-b", False)
        self.assertTrue(response.progress.is_complete)

        with self.assertRaises(TemporaryGroupVotingCompleteError):
            service.submit_vote(group.id, TOKEN, "shop-b", True)

    def test_progress_marks_current_participant_and_host(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, repository = self.make_service(group)
        group.creator_id = str(repository.user.id)

        progress = service.get_voting_progress(group.id, TOKEN)

        self.assertTrue(progress.participants[0].is_me)
        self.assertTrue(progress.participants[0].is_host)

    def test_result_returns_ranking_and_tie_detection(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, _ = self.make_service(group)
        service.submit_vote(group.id, TOKEN, "shop-a", True)
        service.submit_vote(group.id, TOKEN, "shop-b", True)

        result = service.get_voting_result(group.id)

        self.assertTrue(result.has_tie)
        self.assertEqual(result.top_like_count, 1)
        self.assertEqual([item.rank for item in result.results], [1, 1])
        self.assertEqual([item.like_count for item in result.results], [1, 1])

    def test_decide_restaurant_selects_tied_top_restaurant(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, repository = self.make_service(group)
        group.creator_id = str(repository.user.id)
        service.submit_vote(group.id, TOKEN, "shop-a", True)
        service.submit_vote(group.id, TOKEN, "shop-b", True)

        result = service.decide_restaurant(group.id, TOKEN, "shop-b")

        self.assertEqual(group.selected_restaurant_id, "shop-b")
        self.assertEqual(result.selected_restaurant_id, "shop-b")

    def test_decide_restaurant_notifies_when_tied_restaurant_is_selected(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, repository = self.make_service(group)
        group.creator_id = str(repository.user.id)
        service.submit_vote(group.id, TOKEN, "shop-a", True)
        service.submit_vote(group.id, TOKEN, "shop-b", True)

        with patch(
            "app.services.temporary_group_service.notify_restaurant_decided"
        ) as notify:
            service.decide_restaurant(group.id, TOKEN, "shop-b")

            notify.assert_called_once()

    def test_decide_restaurant_rejects_non_top_restaurant(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, repository = self.make_service(group)
        group.creator_id = str(repository.user.id)
        service.submit_vote(group.id, TOKEN, "shop-a", True)
        service.submit_vote(group.id, TOKEN, "shop-b", False)

        with self.assertRaises(TemporaryGroupRestaurantDecisionError):
            service.decide_restaurant(group.id, TOKEN, "shop-b")

    def test_result_requires_group_completion(self) -> None:
        group = make_group(voting_started_at=datetime.now(UTC))
        service, _ = self.make_service(group)
        service.submit_vote(group.id, TOKEN, "shop-a", True)

        with self.assertRaises(TemporaryGroupVotingNotCompleteError):
            service.get_voting_result(group.id)


class TemporaryGroupVotingRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)
        self.group_id = uuid4()

    def test_start_endpoint_returns_progress(self) -> None:
        progress = TemporaryGroupVotingProgress(
            voting_started_at=datetime.now(UTC),
            voting_completed_at=None,
            candidate_count=2,
            participant_count=1,
            joined_participant_count=1,
            completed_participant_count=0,
            is_complete=False,
            participants=[
                TemporaryGroupParticipantVotingProgress(
                    anonymous_user_id=uuid4(),
                    completed_vote_count=0,
                    is_complete=False,
                )
            ],
        )
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service_class.return_value.start_voting.return_value = progress

            response = self.client.post(
                f"/temporary-groups/{self.group_id}/voting/start",
                json={"participant_token": TOKEN},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["candidate_count"], 2)

    def test_start_endpoint_maps_candidate_error_to_bad_request(self) -> None:
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service_class.return_value.start_voting.side_effect = (
                TemporaryGroupVotingCandidatesError("restaurant candidates are required")
            )

            response = self.client.post(
                f"/temporary-groups/{self.group_id}/voting/start",
                json={"participant_token": TOKEN},
            )

        self.assertEqual(response.status_code, 400)

    def test_cors_preflight_allows_flutter_web_origin(self) -> None:
        response = self.client.options(
            f"/temporary-groups/{self.group_id}/voting/progress",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "http://localhost:3000",
        )
