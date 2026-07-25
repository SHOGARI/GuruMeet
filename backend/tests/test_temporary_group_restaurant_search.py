import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

from fastapi.testclient import TestClient

from app.db.session import get_db
from app.main import app
from app.schemas.temporary_group import TemporaryGroupCreate
from app.services.hotpepper_service import (
    HotPepperAPIError,
    HotPepperBudgetRangeError,
    TEMPORARY_GROUP_RESTAURANT_LIMIT,
    search_restaurants_for_group,
    select_hotpepper_budget_codes,
)
from app.services.temporary_group_service import (
    TemporaryGroupNotFoundError,
    TemporaryGroupSearchCriteriaError,
    TemporaryGroupService,
)


class TemporaryGroupCreateSchemaTests(unittest.TestCase):
    def test_restaurant_is_not_accepted_as_a_create_field(self) -> None:
        request = TemporaryGroupCreate.model_validate(
            {
                "location": "渋谷",
                "restaurant": {"restaurants": [{"id": "client-value"}]},
            }
        )

        self.assertNotIn("restaurant", request.model_dump())


class HotPepperBudgetSelectionTests(unittest.TestCase):
    def test_selects_every_budget_code_overlapping_requested_range(self) -> None:
        self.assertEqual(
            select_hotpepper_budget_codes(2000, 3000),
            ["B001", "B002"],
        )

    def test_budget_codes_are_not_duplicated(self) -> None:
        codes = select_hotpepper_budget_codes(0, 10000)

        self.assertEqual(len(codes), len(set(codes)))

    def test_open_ended_budget_uses_all_overlapping_supported_ranges(self) -> None:
        self.assertEqual(
            select_hotpepper_budget_codes(5000, None),
            ["B008", "B004", "B005"],
        )

    def test_missing_budget_does_not_add_a_budget_filter(self) -> None:
        self.assertEqual(select_hotpepper_budget_codes(None, None), [])


class HotPepperGroupSearchTests(unittest.IsolatedAsyncioTestCase):
    async def test_search_uses_location_budget_codes_and_ten_result_limit(
        self,
    ) -> None:
        shops = [
            {
                "id": "J0001",
                "name": "渋谷ビストロ",
                "address": "東京都渋谷区",
                "access": "渋谷駅徒歩5分",
                "genre": {"name": "イタリアン"},
                "budget": {"name": "2001～3000円"},
                "photo": {"pc": {"l": "https://example.com/shop.jpg"}},
                "urls": {"pc": "https://example.com/shop"},
            },
            {
                "id": "J0001",
                "name": "重複店舗",
            },
        ]

        with patch(
            "app.services.hotpepper_service._fetch_hotpepper_shops",
            new=AsyncMock(return_value=shops),
        ) as fetch_mock:
            result = await search_restaurants_for_group(
                location="  渋谷  ",
                budget_min=2000,
                budget_max=3000,
            )

        fetch_mock.assert_awaited_once_with(
            {
                "keyword": "渋谷",
                "count": TEMPORARY_GROUP_RESTAURANT_LIMIT,
                "budget": "B001,B002",
            }
        )
        self.assertEqual(len(result["restaurants"]), 1)
        self.assertEqual(
            result["restaurants"][0],
            {
                "id": "J0001",
                "name": "渋谷ビストロ",
                "address": "東京都渋谷区",
                "access": "渋谷駅徒歩5分",
                "genre": "イタリアン",
                "budget": "2001～3000円",
                "image_url": "https://example.com/shop.jpg",
                "shop_url": "https://example.com/shop",
            },
        )
        self.assertIn("searched_at", result)

    async def test_empty_search_result_is_successful(self) -> None:
        with patch(
            "app.services.hotpepper_service._fetch_hotpepper_shops",
            new=AsyncMock(return_value=[]),
        ):
            result = await search_restaurants_for_group(
                location="該当なし",
                budget_min=None,
                budget_max=None,
            )

        self.assertEqual(result["restaurants"], [])
        self.assertIn("searched_at", result)

    async def test_result_is_capped_after_deduplication(self) -> None:
        shops = [
            {"id": f"J{index:04d}", "name": f"店舗{index}"}
            for index in range(TEMPORARY_GROUP_RESTAURANT_LIMIT + 5)
        ]

        with patch(
            "app.services.hotpepper_service._fetch_hotpepper_shops",
            new=AsyncMock(return_value=shops),
        ):
            result = await search_restaurants_for_group(
                location="東京",
                budget_min=None,
                budget_max=None,
            )

        self.assertEqual(
            len(result["restaurants"]),
            TEMPORARY_GROUP_RESTAURANT_LIMIT,
        )

    async def test_unsupported_budget_stops_before_external_api(self) -> None:
        with patch(
            "app.services.hotpepper_service._fetch_hotpepper_shops",
            new=AsyncMock(),
        ) as fetch_mock:
            with self.assertRaises(HotPepperBudgetRangeError):
                await search_restaurants_for_group(
                    location="東京",
                    budget_min=10001,
                    budget_max=15000,
                )

        fetch_mock.assert_not_awaited()


class TemporaryGroupRestaurantPersistenceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.db = MagicMock()
        self.service = TemporaryGroupService(self.db)
        self.group_id = uuid4()
        self.group = SimpleNamespace(
            id=self.group_id,
            location="渋谷",
            budget_min=2000,
            budget_max=3000,
            participant_count=4,
            restaurant={"restaurants": [{"id": "OLD"}], "searched_at": "old"},
        )
        self.service.repository.get_active_by_id = MagicMock(
            return_value=self.group
        )

    async def test_latest_result_overwrites_entire_restaurant_value(self) -> None:
        latest_result = {
            "restaurants": [{"id": "NEW"}],
            "searched_at": "2026-07-25T00:00:00+00:00",
        }

        with patch(
            "app.services.temporary_group_service.search_restaurants_for_group",
            new=AsyncMock(return_value=latest_result),
        ) as search_mock:
            result = await self.service.search_and_save_restaurants(self.group_id)

        search_mock.assert_awaited_once_with(
            location="渋谷",
            budget_min=2000,
            budget_max=3000,
        )
        self.assertIs(result, latest_result)
        self.assertIs(self.group.restaurant, latest_result)
        self.db.commit.assert_called_once_with()
        self.db.refresh.assert_called_once_with(self.group)

    async def test_external_api_error_preserves_existing_restaurant(self) -> None:
        original_restaurant = self.group.restaurant

        with patch(
            "app.services.temporary_group_service.search_restaurants_for_group",
            new=AsyncMock(side_effect=HotPepperAPIError),
        ):
            with self.assertRaises(HotPepperAPIError):
                await self.service.search_and_save_restaurants(self.group_id)

        self.assertIs(self.group.restaurant, original_restaurant)
        self.db.commit.assert_not_called()
        self.db.rollback.assert_not_called()

    async def test_database_error_rolls_back_and_restores_in_memory_value(
        self,
    ) -> None:
        original_restaurant = self.group.restaurant
        self.db.flush.side_effect = RuntimeError("database unavailable")

        with patch(
            "app.services.temporary_group_service.search_restaurants_for_group",
            new=AsyncMock(
                return_value={
                    "restaurants": [{"id": "NEW"}],
                    "searched_at": "2026-07-25T00:00:00+00:00",
                }
            ),
        ):
            with self.assertRaises(RuntimeError):
                await self.service.search_and_save_restaurants(self.group_id)

        self.db.rollback.assert_called_once_with()
        self.assertIs(self.group.restaurant, original_restaurant)

    async def test_missing_or_expired_group_stops_before_external_api(self) -> None:
        self.service.repository.get_active_by_id.return_value = None

        with patch(
            "app.services.temporary_group_service.search_restaurants_for_group",
            new=AsyncMock(),
        ) as search_mock:
            with self.assertRaises(TemporaryGroupNotFoundError):
                await self.service.search_and_save_restaurants(self.group_id)

        search_mock.assert_not_awaited()
        self.db.commit.assert_not_called()

    async def test_missing_location_stops_before_external_api(self) -> None:
        self.group.location = "   "

        with patch(
            "app.services.temporary_group_service.search_restaurants_for_group",
            new=AsyncMock(),
        ) as search_mock:
            with self.assertRaises(TemporaryGroupSearchCriteriaError):
                await self.service.search_and_save_restaurants(self.group_id)

        search_mock.assert_not_awaited()
        self.db.commit.assert_not_called()


class TemporaryGroupRestaurantRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db = MagicMock()
        app.dependency_overrides[get_db] = lambda: self.db
        self.client = TestClient(app)
        self.group_id = uuid4()

    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_search_endpoint_returns_saved_restaurants(self) -> None:
        search_result = {
            "restaurants": [
                {
                    "id": "J0001",
                    "name": "渋谷ビストロ",
                    "address": "東京都渋谷区",
                    "access": "渋谷駅徒歩5分",
                    "genre": "イタリアン",
                    "budget": "2001～3000円",
                    "image_url": "https://example.com/shop.jpg",
                    "shop_url": "https://example.com/shop",
                }
            ],
            "searched_at": "2026-07-25T00:00:00+00:00",
        }

        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service_class.return_value.search_and_save_restaurants = AsyncMock(
                return_value=search_result
            )
            response = self.client.post(
                f"/temporary-groups/{self.group_id}/restaurants/search"
            )

        self.assertEqual(response.status_code, 200)
        expected_response = {
            **search_result,
            "searched_at": "2026-07-25T00:00:00Z",
        }
        self.assertEqual(response.json(), expected_response)

    def test_missing_or_expired_group_returns_not_found(self) -> None:
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service_class.return_value.search_and_save_restaurants = AsyncMock(
                side_effect=TemporaryGroupNotFoundError
            )
            response = self.client.post(
                f"/temporary-groups/{self.group_id}/restaurants/search"
            )

        self.assertEqual(response.status_code, 404)

    def test_missing_search_criteria_returns_bad_request(self) -> None:
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service_class.return_value.search_and_save_restaurants = AsyncMock(
                side_effect=TemporaryGroupSearchCriteriaError(
                    "location is required"
                )
            )
            response = self.client.post(
                f"/temporary-groups/{self.group_id}/restaurants/search"
            )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json(), {"detail": "location is required"})

    def test_hotpepper_error_returns_bad_gateway(self) -> None:
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service_class.return_value.search_and_save_restaurants = AsyncMock(
                side_effect=HotPepperAPIError
            )
            response = self.client.post(
                f"/temporary-groups/{self.group_id}/restaurants/search"
            )

        self.assertEqual(response.status_code, 502)


if __name__ == "__main__":
    unittest.main()
