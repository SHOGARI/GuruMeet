import unittest
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

from fastapi.testclient import TestClient

from app.db.session import get_db
from app.main import app
from app.schemas.temporary_group import (
    CustomLocationCreate,
    TemporaryGroupCreate,
    TemporaryGroupResponse,
)
from app.services.hotpepper_service import (
    BUDGET_SCORE_FALLBACK,
    CAPACITY_SCORE_FALLBACK,
    HotPepperAPIError,
    HotPepperAPITimeoutError,
    HotPepperBudgetRangeError,
    HotPepperBudgetRange,
    TEMPORARY_GROUP_RESTAURANT_CANDIDATE_LIMIT,
    TEMPORARY_GROUP_RESTAURANT_RESULT_LIMIT,
    _calculate_budget_score,
    _calculate_capacity_score,
    _deduplicate_shops,
    _normalize_genre_name,
    _rank_restaurants,
    _select_restaurants_with_genre_limit,
    hotpepper_range_for_radius,
    search_restaurants_for_group,
    search_restaurants_for_group_by_coordinates,
    select_hotpepper_budget_codes,
)
from app.services.temporary_group_service import (
    TemporaryGroupHostRequiredError,
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

    def test_location_id_accepts_camel_case_payload(self) -> None:
        request = TemporaryGroupCreate.model_validate(
            {
                "location": "北千住駅・東京都足立区",
                "locationId": "station:1132005",
            }
        )

        self.assertEqual(request.location_id, "station:1132005")

    def test_custom_location_accepts_camel_case_payload(self) -> None:
        request = TemporaryGroupCreate.model_validate(
            {
                "location": "東京都新宿区付近",
                "customLocation": {
                    "displayName": "東京都新宿区付近",
                    "prefectureName": "東京都",
                    "latitude": 35.6895,
                    "longitude": 139.6917,
                    "accuracyMeters": 24.5,
                },
            }
        )

        self.assertIsNotNone(request.custom_location)
        assert request.custom_location is not None
        self.assertEqual(request.custom_location.display_name, "東京都新宿区付近")
        self.assertEqual(request.custom_location.prefecture_name, "東京都")

    def test_location_id_and_custom_location_are_exclusive(self) -> None:
        with self.assertRaises(ValueError):
            TemporaryGroupCreate(
                location_id="station:1132005",
                custom_location=CustomLocationCreate(
                    display_name="東京都新宿区付近",
                    latitude=35.6895,
                    longitude=139.6917,
                ),
            )


class HotPepperBudgetSelectionTests(unittest.TestCase):
    def test_selects_every_budget_code_overlapping_requested_range(self) -> None:
        self.assertEqual(
            select_hotpepper_budget_codes(2000, 3000),
            ["B001", "B002"],
        )

    def test_budget_codes_are_limited_and_not_duplicated(self) -> None:
        codes = select_hotpepper_budget_codes(0, 10000)

        self.assertEqual(codes, ["B008", "B004"])
        self.assertEqual(len(codes), len(set(codes)))

    def test_open_ended_budget_preserves_master_order_when_midpoint_is_missing(
        self,
    ) -> None:
        self.assertEqual(
            select_hotpepper_budget_codes(5000, None),
            ["B008", "B004"],
        )

    def test_missing_budget_does_not_add_a_budget_filter(self) -> None:
        self.assertEqual(select_hotpepper_budget_codes(None, None), [])

    def test_nearest_budget_midpoints_are_prioritized(self) -> None:
        self.assertEqual(
            select_hotpepper_budget_codes(3000, 7000),
            ["B008", "B004"],
        )


class RestaurantScoringTests(unittest.TestCase):
    def test_budget_score_boundaries(self) -> None:
        expected_scores = (
            (0, 70),
            (300, 70),
            (300.5, 63),
            (600, 63),
            (600.5, 56),
            (900, 56),
            (900.5, 49),
            (1200, 49),
            (1200.5, 42),
            (1500, 42),
            (1500.5, 28),
        )

        for difference, expected_score in expected_scores:
            with self.subTest(difference=difference):
                budget_range = HotPepperBudgetRange(
                    code="TEST",
                    min_yen=3000 + difference,
                    max_yen=3000 + difference,
                )
                with patch(
                    "app.services.hotpepper_service."
                    "_get_restaurant_budget_range",
                    return_value=budget_range,
                ):
                    score = _calculate_budget_score(
                        2000,
                        4000,
                        {"budget": {"code": "TEST"}},
                    )

                self.assertEqual(score, expected_score)

    def test_budget_score_supports_fractional_midpoints(self) -> None:
        budget_range = HotPepperBudgetRange(
            code="TEST",
            min_yen=1000,
            max_yen=1001,
        )
        with patch(
            "app.services.hotpepper_service._get_restaurant_budget_range",
            return_value=budget_range,
        ):
            score = _calculate_budget_score(
                1000,
                1001,
                {"budget": {"code": "TEST"}},
            )

        self.assertEqual(score, 70)

    def test_invalid_or_missing_budget_uses_fallback(self) -> None:
        invalid_cases = (
            (None, 3000, {"budget": {"code": "B002"}}),
            (2000, None, {"budget": {"code": "B002"}}),
            (None, None, {"budget": {"code": "B002"}}),
            (4000, 2000, {"budget": {"code": "B002"}}),
            (2000, 3000, {}),
            (2000, 3000, {"budget": {}}),
            (2000, 3000, {"budget": {"code": ""}}),
            (2000, 3000, {"budget": {"code": "UNKNOWN"}}),
        )

        for budget_min, budget_max, shop in invalid_cases:
            with self.subTest(
                budget_min=budget_min,
                budget_max=budget_max,
                shop=shop,
            ):
                self.assertEqual(
                    _calculate_budget_score(budget_min, budget_max, shop),
                    BUDGET_SCORE_FALLBACK,
                )

    def test_open_ended_shop_budget_uses_fallback(self) -> None:
        budget_range = HotPepperBudgetRange(
            code="OPEN",
            min_yen=10001,
            max_yen=None,
        )
        with patch(
            "app.services.hotpepper_service._get_restaurant_budget_range",
            return_value=budget_range,
        ):
            score = _calculate_budget_score(
                10000,
                15000,
                {"budget": {"code": "OPEN"}},
            )

        self.assertEqual(score, BUDGET_SCORE_FALLBACK)

    def test_capacity_score_boundaries(self) -> None:
        expected_scores = (
            (3, 0),
            (4, 12),
            (7, 12),
            (8, 21),
            (15, 21),
            (16, 27),
            (31, 27),
            (32, 30),
        )

        for capacity, expected_score in expected_scores:
            with self.subTest(capacity=capacity):
                self.assertEqual(
                    _calculate_capacity_score(4, capacity),
                    expected_score,
                )

    def test_invalid_capacity_uses_fallback(self) -> None:
        invalid_capacities = (
            None,
            "",
            " ",
            0,
            "0",
            -1,
            "-1",
            "abc",
            True,
            False,
        )

        for capacity in invalid_capacities:
            with self.subTest(capacity=capacity):
                self.assertEqual(
                    _calculate_capacity_score(4, capacity),
                    CAPACITY_SCORE_FALLBACK,
                )

    def test_positive_integer_strings_are_valid_capacities(self) -> None:
        self.assertEqual(_calculate_capacity_score(4, "4"), 12)
        self.assertEqual(_calculate_capacity_score(4, "32"), 30)

    def test_invalid_participant_count_uses_fallback(self) -> None:
        invalid_counts = (None, 0, -1, "", "abc", True, False)

        for participant_count in invalid_counts:
            with self.subTest(participant_count=participant_count):
                self.assertEqual(
                    _calculate_capacity_score(participant_count, 32),
                    CAPACITY_SCORE_FALLBACK,
                )


class RestaurantRankingTests(unittest.TestCase):
    @staticmethod
    def _shop(
        shop_id: str,
        *,
        budget_code: str = "B002",
        capacity: object = 4,
        genre: object = "居酒屋",
    ) -> dict[str, object]:
        return {
            "id": shop_id,
            "budget": {"code": budget_code},
            "capacity": capacity,
            "genre": {"name": genre},
        }

    def test_ranking_uses_all_tie_breakers(self) -> None:
        shops = [
            self._shop("api-first", budget_code="UNKNOWN", capacity=None),
            self._shop("higher-capacity", budget_code="B002", capacity=32),
            self._shop("higher-budget", budget_code="B002", capacity=4),
            self._shop("lower-budget", budget_code="B001", capacity=32),
        ]

        ranked = _rank_restaurants(
            shops,
            budget_min=2000,
            budget_max=3000,
            participant_count=4,
        )

        self.assertEqual(
            [restaurant["shop"]["id"] for restaurant in ranked],
            [
                "higher-capacity",
                "higher-budget",
                "lower-budget",
                "api-first",
            ],
        )

    def test_equal_scores_preserve_hotpepper_order(self) -> None:
        shops = [self._shop("first"), self._shop("second")]

        first_result = _rank_restaurants(shops, 2000, 3000, 4)
        second_result = _rank_restaurants(shops, 2000, 3000, 4)

        self.assertEqual(
            [restaurant["shop"]["id"] for restaurant in first_result],
            ["first", "second"],
        )
        self.assertEqual(first_result, second_result)

    def test_genre_selection_limits_then_fills_in_ranking_order(self) -> None:
        shops = [
            self._shop(f"A{index}", genre="居酒屋")
            for index in range(4)
        ]
        shops.extend(
            self._shop(f"B{index}", genre="焼肉") for index in range(4)
        )
        ranked = _rank_restaurants(shops, 2000, 3000, 4)

        selected = _select_restaurants_with_genre_limit(ranked)

        self.assertEqual(
            [shop["id"] for shop in selected],
            ["A0", "A1", "B0", "B1", "A2", "A3", "B2", "B3"],
        )

    def test_genre_selection_uses_at_most_two_when_pool_is_diverse(self) -> None:
        shops = [
            self._shop(f"{genre}{index}", genre=genre)
            for genre in ("居酒屋", "焼肉", "和食", "洋食", "中華")
            for index in range(3)
        ]
        ranked = _rank_restaurants(shops, 2000, 3000, 4)

        selected = _select_restaurants_with_genre_limit(ranked)

        selected_genres = [
            _normalize_genre_name(shop) for shop in selected
        ]
        self.assertEqual(len(selected), 10)
        for genre in set(selected_genres):
            self.assertEqual(selected_genres.count(genre), 2)

    def test_duplicate_shop_does_not_consume_multiple_genre_slots(self) -> None:
        duplicate = self._shop("duplicate", genre="居酒屋")
        shops = [
            duplicate,
            duplicate,
            self._shop("second", genre="居酒屋"),
            self._shop("third", genre="居酒屋"),
            self._shop("other", genre="焼肉"),
        ]

        unique_shops = _deduplicate_shops(shops)
        ranked = _rank_restaurants(unique_shops, 2000, 3000, 4)
        selected = _select_restaurants_with_genre_limit(ranked)

        self.assertEqual(
            [shop["id"] for shop in selected],
            ["duplicate", "second", "other", "third"],
        )

    def test_genre_normalization_unifies_missing_and_whitespace(self) -> None:
        self.assertEqual(_normalize_genre_name({}), "不明")
        self.assertEqual(_normalize_genre_name({"genre": {}}), "不明")
        self.assertEqual(
            _normalize_genre_name({"genre": {"name": None}}),
            "不明",
        )
        self.assertEqual(
            _normalize_genre_name({"genre": {"name": ""}}),
            "不明",
        )
        self.assertEqual(
            _normalize_genre_name({"genre": {"name": "   "}}),
            "不明",
        )
        self.assertEqual(
            _normalize_genre_name({"genre": {"name": " 居酒屋 "}}),
            "居酒屋",
        )


class HotPepperGroupSearchTests(unittest.IsolatedAsyncioTestCase):
    async def test_search_uses_group_criteria_and_candidate_limit(
        self,
    ) -> None:
        shops = [
            {
                "id": "J0001",
                "name": "渋谷ビストロ",
                "address": "東京都渋谷区",
                "access": "渋谷駅徒歩5分",
                "genre": {"name": "イタリアン"},
                "budget": {"code": "B002", "name": "2001～3000円"},
                "capacity": 8,
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
                participant_count=4,
            )

        fetch_mock.assert_awaited_once_with(
            {
                "keyword": "渋谷",
                "count": TEMPORARY_GROUP_RESTAURANT_CANDIDATE_LIMIT,
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
            for index in range(TEMPORARY_GROUP_RESTAURANT_CANDIDATE_LIMIT)
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
            TEMPORARY_GROUP_RESTAURANT_RESULT_LIMIT,
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

    async def test_coordinate_search_uses_radius_and_group_criteria(self) -> None:
        with patch(
            "app.services.hotpepper_service._fetch_hotpepper_shops",
            new=AsyncMock(return_value=[]),
        ) as fetch_mock:
            result = await search_restaurants_for_group_by_coordinates(
                latitude=35.7494,
                longitude=139.805,
                radius_meters=1000,
                budget_min=2000,
                budget_max=3000,
                participant_count=4,
            )

        fetch_mock.assert_awaited_once_with(
            {
                "lat": 35.7494,
                "lng": 139.805,
                "range": 3,
                "count": TEMPORARY_GROUP_RESTAURANT_CANDIDATE_LIMIT,
                "budget": "B001,B002",
            }
        )
        self.assertEqual(result["restaurants"], [])

    def test_radius_is_capped_to_hotpepper_ranges(self) -> None:
        self.assertEqual(hotpepper_range_for_radius(300), 1)
        self.assertEqual(hotpepper_range_for_radius(1000), 3)
        self.assertEqual(hotpepper_range_for_radius(999999), 5)


class TemporaryGroupRestaurantCreatePersistenceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.db = MagicMock()
        self.service = TemporaryGroupService(self.db)
        self.service.repository.add = MagicMock(side_effect=lambda group: group)

    async def test_create_group_rejects_location_without_location_id(self) -> None:
        with patch(
            "app.services.temporary_group_service."
            "search_restaurants_for_group_by_coordinates",
            new=AsyncMock(),
        ) as search_mock:
            data = TemporaryGroupCreate(
                location="  渋谷  ",
                budget_min=2000,
                budget_max=3000,
                participant_count=4,
            )
            with self.assertRaises(TemporaryGroupSearchCriteriaError):
                await TemporaryGroupService.search_restaurants_for_create(data)

        search_mock.assert_not_awaited()
        self.service.repository.add.assert_not_called()
        self.db.commit.assert_not_called()

    async def test_create_group_uses_selected_station_for_coordinate_search(
        self,
    ) -> None:
        location_entry = SimpleNamespace(
            id="station:1132005",
            location_type="station",
            name="北千住駅",
            display_name="北千住駅・東京都足立区",
            prefecture_name="東京都",
            municipality_name="足立区",
            municipality_code=None,
            station_code="1132005",
            station_group_code="1132005",
            latitude=35.7494,
            longitude=139.805,
        )
        search_result = {
            "restaurants": [{"id": "NEW"}],
            "searched_at": "2026-07-25T00:00:00+00:00",
        }

        with (
            patch(
                "app.services.temporary_group_service."
                "LocationRepository.get_by_location_id",
                return_value=location_entry,
            ),
            patch(
                "app.services.temporary_group_service."
                "search_restaurants_for_group_by_coordinates",
                new=AsyncMock(return_value=search_result),
            ) as search_mock,
        ):
            data = TemporaryGroupCreate(
                location="北千住駅・東京都足立区",
                location_id="station:1132005",
                budget_min=2000,
                budget_max=3000,
                participant_count=4,
            )
            restaurant, restaurant_search_status = (
                await TemporaryGroupService.search_restaurants_for_create(
                    data,
                    self.db,
                )
            )
            group = self.service.create_group(
                data,
                restaurant=restaurant,
                restaurant_search_status=restaurant_search_status,
            )

        search_mock.assert_awaited_once_with(
            latitude=35.7494,
            longitude=139.805,
            radius_meters=1000,
            budget_min=2000,
            budget_max=3000,
            participant_count=4,
        )
        self.assertIs(group.restaurant, search_result)
        self.assertEqual(group.location_id, "station:1132005")

    async def test_create_group_uses_custom_location_for_coordinate_search(
        self,
    ) -> None:
        search_result = {
            "restaurants": [{"id": "CURRENT"}],
            "searched_at": "2026-07-25T00:00:00+00:00",
        }

        with patch(
            "app.services.temporary_group_service."
            "search_restaurants_for_group_by_coordinates",
            new=AsyncMock(return_value=search_result),
        ) as search_mock:
            data = TemporaryGroupCreate(
                location="東京都新宿区付近",
                custom_location=CustomLocationCreate(
                    display_name="東京都新宿区付近",
                    prefecture_name="東京都",
                    latitude=35.6895,
                    longitude=139.6917,
                    accuracy_meters=24.5,
                ),
                budget_min=2000,
                budget_max=3000,
                participant_count=4,
            )
            restaurant, restaurant_search_status = (
                await TemporaryGroupService.search_restaurants_for_create(
                    data,
                    self.db,
                )
            )
            group = self.service.create_group(
                data,
                restaurant=restaurant,
                restaurant_search_status=restaurant_search_status,
            )

        search_mock.assert_awaited_once_with(
            latitude=35.6895,
            longitude=139.6917,
            radius_meters=1000,
            budget_min=2000,
            budget_max=3000,
            participant_count=4,
        )
        self.assertIs(group.restaurant, search_result)
        self.assertIsNone(group.location_id)
        self.assertIsNotNone(group.custom_location_id)

    async def test_coordinate_search_radius_uses_settings(self) -> None:
        location_entry = SimpleNamespace(
            id="station:1132005",
            location_type="station",
            name="北千住駅",
            display_name="北千住駅・東京都足立区",
            latitude=35.7494,
            longitude=139.805,
        )
        search_result = {
            "restaurants": [{"id": "NEW"}],
            "searched_at": "2026-07-25T00:00:00+00:00",
        }

        with (
            patch(
                "app.services.temporary_group_service."
                "LocationRepository.get_by_location_id",
                return_value=location_entry,
            ),
            patch(
                "app.services.temporary_group_service."
                "search_restaurants_for_group_by_coordinates",
                new=AsyncMock(return_value=search_result),
            ) as search_mock,
            patch(
                "app.services.temporary_group_service."
                "settings.hotpepper_station_search_radius_meters",
                800,
            ),
        ):
            await TemporaryGroupService.search_restaurants_for_create(
                TemporaryGroupCreate(location_id="station:1132005"),
                self.db,
            )

        self.assertEqual(search_mock.await_args.kwargs["radius_meters"], 800)

    async def test_create_group_keeps_municipality_code_with_coordinate_fallback(
        self,
    ) -> None:
        location_entry = SimpleNamespace(
            id="municipality:13121",
            location_type="municipality",
            name="足立区",
            display_name="東京都足立区",
            prefecture_name="東京都",
            municipality_name="足立区",
            municipality_code="13121",
            station_code=None,
            station_group_code=None,
            latitude=35.7757,
            longitude=139.8048,
        )
        search_result = {
            "restaurants": [{"id": "NEW"}],
            "searched_at": "2026-07-25T00:00:00+00:00",
        }

        with (
            patch(
                "app.services.temporary_group_service."
                "LocationRepository.get_by_location_id",
                return_value=location_entry,
            ),
            patch(
                "app.services.temporary_group_service."
                "search_restaurants_for_group_by_coordinates",
                new=AsyncMock(return_value=search_result),
            ) as search_mock,
        ):
            data = TemporaryGroupCreate(
                location_id="municipality:13121",
                budget_min=2000,
                budget_max=3000,
                participant_count=4,
            )
            restaurant, restaurant_search_status = (
                await TemporaryGroupService.search_restaurants_for_create(
                    data,
                    self.db,
                )
            )
            group = self.service.create_group(
                data,
                restaurant=restaurant,
                restaurant_search_status=restaurant_search_status,
            )

        search_mock.assert_awaited_once_with(
            latitude=35.7757,
            longitude=139.8048,
            radius_meters=3000,
            budget_min=2000,
            budget_max=3000,
            participant_count=4,
        )
        self.assertEqual(group.location, "東京都足立区")
        self.assertEqual(group.location_id, "municipality:13121")

    async def test_create_group_rejects_unknown_location_id(self) -> None:
        with (
            patch(
                "app.services.temporary_group_service."
                "LocationRepository.get_by_location_id",
                return_value=None,
            ),
            patch(
                "app.services.temporary_group_service."
                "search_restaurants_for_group_by_coordinates",
                new=AsyncMock(),
            ) as search_mock,
        ):
            with self.assertRaises(TemporaryGroupSearchCriteriaError):
                await TemporaryGroupService.search_restaurants_for_create(
                    TemporaryGroupCreate(location_id="station:does-not-exist"),
                    self.db,
                )

        search_mock.assert_not_awaited()

    async def test_create_group_marks_no_results_when_search_returns_empty(
        self,
    ) -> None:
        search_result = {
            "restaurants": [],
            "searched_at": "2026-07-25T00:00:00+00:00",
        }

        location_entry = SimpleNamespace(
            id="station:1132005",
            location_type="station",
            name="北千住駅",
            display_name="北千住駅・東京都足立区",
            latitude=35.7494,
            longitude=139.805,
        )

        with (
            patch(
                "app.services.temporary_group_service."
                "LocationRepository.get_by_location_id",
                return_value=location_entry,
            ),
            patch(
                "app.services.temporary_group_service."
                "search_restaurants_for_group_by_coordinates",
                new=AsyncMock(return_value=search_result),
            ),
        ):
            data = TemporaryGroupCreate(location_id="station:1132005")
            restaurant, restaurant_search_status = (
                await TemporaryGroupService.search_restaurants_for_create(
                    data,
                    self.db,
                )
            )
            group = self.service.create_group(
                data,
                restaurant=restaurant,
                restaurant_search_status=restaurant_search_status,
            )

        self.assertIs(group.restaurant, search_result)
        self.assertEqual(group.restaurant_search_status, "no_results")

    async def test_external_api_error_stops_before_group_creation(self) -> None:
        location_entry = SimpleNamespace(
            id="station:1132005",
            location_type="station",
            name="北千住駅",
            display_name="北千住駅・東京都足立区",
            latitude=35.7494,
            longitude=139.805,
        )

        with (
            patch(
                "app.services.temporary_group_service."
                "LocationRepository.get_by_location_id",
                return_value=location_entry,
            ),
            patch(
                "app.services.temporary_group_service."
                "search_restaurants_for_group_by_coordinates",
                new=AsyncMock(side_effect=HotPepperAPIError),
            ),
        ):
            with self.assertRaises(HotPepperAPIError):
                await TemporaryGroupService.search_restaurants_for_create(
                    TemporaryGroupCreate(location_id="station:1132005"),
                    self.db,
                )

        self.service.repository.add.assert_not_called()
        self.db.commit.assert_not_called()

    async def test_missing_location_creates_group_without_search(self) -> None:
        with patch(
            "app.services.temporary_group_service."
            "search_restaurants_for_group_by_coordinates",
            new=AsyncMock(),
        ) as search_mock:
            data = TemporaryGroupCreate(location="   ")
            restaurant, restaurant_search_status = (
                await TemporaryGroupService.search_restaurants_for_create(data)
            )
            group = self.service.create_group(
                data,
                restaurant=restaurant,
                restaurant_search_status=restaurant_search_status,
            )

        search_mock.assert_not_awaited()
        self.assertIsNone(group.restaurant)
        self.assertEqual(group.restaurant_search_status, "not_requested")
        self.db.commit.assert_called_once_with()

    async def test_invalid_budget_stops_before_group_creation(self) -> None:
        with patch(
            "app.services.temporary_group_service."
            "search_restaurants_for_group_by_coordinates",
        ) as search_mock:
            with self.assertRaises(TemporaryGroupSearchCriteriaError):
                await TemporaryGroupService.search_restaurants_for_create(
                    TemporaryGroupCreate(
                        location="渋谷",
                        budget_min=3000,
                        budget_max=2000,
                    )
                )

        search_mock.assert_not_awaited()
        self.service.repository.add.assert_not_called()
        self.db.commit.assert_not_called()


class TemporaryGroupRestaurantCreateRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db = MagicMock()
        app.dependency_overrides[get_db] = lambda: self.db
        self.client = TestClient(app)
        self.group_id = uuid4()

    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_create_endpoint_returns_create_result_only(self) -> None:
        restaurant = {
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
            "searched_at": "2026-07-25T00:00:00Z",
        }
        group = self._group(restaurant=restaurant)

        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService."
            "search_restaurants_for_create",
            new=AsyncMock(return_value=(restaurant, "succeeded")),
        ) as search_mock:
            with patch(
                "app.api.routes.temporary_groups._create_temporary_group_response",
                return_value=self._response(group, joined_participant_count=1),
            ) as create_response:

                response = self.client.post(
                    "/temporary-groups",
                    json={
                        "location": "渋谷駅・東京都渋谷区",
                        "location_id": "station:1130205",
                        "budget_min": 2000,
                        "budget_max": 3000,
                        "participant_count": 4,
                    },
                )

        self.assertEqual(response.status_code, 201)
        response_body = response.json()
        self.assertEqual(
            set(response_body),
            {
                "id",
                "code",
                "expires_at",
                "joined_participant_count",
                "is_full",
                "phase",
            },
        )
        request = search_mock.await_args.args[0]
        self.assertEqual(request.location, "渋谷駅・東京都渋谷区")
        self.assertEqual(request.location_id, "station:1130205")
        self.assertIs(search_mock.await_args.args[1], self.db)
        create_response.assert_called_once_with(request, restaurant, "succeeded")

    def test_create_rejects_invalid_location_id(self) -> None:
        response = self.client.post(
            "/temporary-groups",
            json={"location": "北千住駅・東京都足立区", "location_id": "station:"},
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json(), {"detail": "invalid location_id"})

    def test_removed_search_endpoint_returns_not_found(self) -> None:
        response = self.client.post(
            f"/temporary-groups/{self.group_id}/restaurants/search"
        )

        self.assertEqual(response.status_code, 404)

    def test_create_search_criteria_error_returns_bad_request(self) -> None:
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService."
            "search_restaurants_for_create",
            new=AsyncMock(
                side_effect=TemporaryGroupSearchCriteriaError(
                    "budget_min must not exceed budget_max"
                )
            ),
        ):
            response = self.client.post("/temporary-groups", json={"location": "渋谷"})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.json(),
            {"detail": "budget_min must not exceed budget_max"},
        )

    def test_create_hotpepper_error_returns_bad_gateway(self) -> None:
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService."
            "search_restaurants_for_create",
            new=AsyncMock(
                side_effect=HotPepperAPIError
            ),
        ):
            response = self.client.post("/temporary-groups", json={"location": "渋谷"})

        self.assertEqual(response.status_code, 502)

    def test_create_hotpepper_timeout_returns_gateway_timeout(self) -> None:
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService."
            "search_restaurants_for_create",
            new=AsyncMock(
                side_effect=HotPepperAPITimeoutError
            ),
        ):
            response = self.client.post("/temporary-groups", json={"location": "渋谷"})

        self.assertEqual(response.status_code, 504)

    def test_join_by_id_endpoint_returns_join_result_only(self) -> None:
        group = self._group(restaurant={"restaurants": [{"id": "J0001"}]})

        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service = service_class.return_value
            service.join_active_by_id.return_value = group
            service.count_participants.return_value = 2
            service.is_full.return_value = False

            response = self.client.post(
                f"/temporary-groups/{self.group_id}/participants",
                json={"participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            set(response.json()),
            {
                "id",
                "code",
                "expires_at",
                "joined_participant_count",
                "is_full",
                "phase",
            },
        )

    def test_join_by_code_endpoint_returns_join_result_only(self) -> None:
        group = self._group(restaurant={"restaurants": [{"id": "J0001"}]})

        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service = service_class.return_value
            service.join_active_by_code.return_value = group
            service.count_participants.return_value = 2
            service.is_full.return_value = False

            response = self.client.post(
                "/temporary-groups/join",
                json={
                    "code": "A7K2F",
                    "participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a",
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            set(response.json()),
            {
                "id",
                "code",
                "expires_at",
                "joined_participant_count",
                "is_full",
                "phase",
            },
        )

    def test_dissolve_endpoint_expires_group(self) -> None:
        group = self._group(restaurant={"restaurants": [{"id": "J0001"}]})

        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service = service_class.return_value
            service.dissolve_group.return_value = group
            service.count_participants.return_value = 1
            service.is_full.return_value = False

            response = self.client.post(
                f"/temporary-groups/{self.group_id}/dissolve",
                json={"participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["id"], str(self.group_id))
        service.dissolve_group.assert_called_once_with(
            self.group_id,
            "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a",
        )

    def test_dissolve_endpoint_returns_not_found_for_expired_group(self) -> None:
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service_class.return_value.dissolve_group.side_effect = (
                TemporaryGroupNotFoundError
            )

            response = self.client.post(
                f"/temporary-groups/{self.group_id}/dissolve",
                json={"participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"},
            )

        self.assertEqual(response.status_code, 404)

    def test_dissolve_endpoint_requires_host(self) -> None:
        with patch(
            "app.api.routes.temporary_groups.TemporaryGroupService"
        ) as service_class:
            service_class.return_value.dissolve_group.side_effect = (
                TemporaryGroupHostRequiredError
            )

            response = self.client.post(
                f"/temporary-groups/{self.group_id}/dissolve",
                json={"participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"},
            )

        self.assertEqual(response.status_code, 403)
        self.assertEqual(
            response.json(),
            {"detail": "この一時グループを解散できるのは作成者だけです。"},
        )

    def _group(self, restaurant: dict[str, object]) -> SimpleNamespace:
        return SimpleNamespace(
            id=self.group_id,
            code="A7K2F",
            expires_at=datetime(2026, 7, 26, 0, 0, tzinfo=UTC),
            created_at=datetime(2026, 7, 25, 0, 0, tzinfo=UTC),
            voting_started_at=None,
            voting_completed_at=None,
            creator_id="user_123",
            participant_count=4,
            location="渋谷",
            budget_min=2000,
            budget_max=3000,
            restaurant_search_status="succeeded",
            restaurant=restaurant,
            location_id=None,
        )

    def _response(
        self,
        group: SimpleNamespace,
        joined_participant_count: int,
    ) -> TemporaryGroupResponse:
        return TemporaryGroupResponse(
            id=group.id,
            code=group.code,
            expires_at=group.expires_at,
            joined_participant_count=joined_participant_count,
            is_full=False,
            phase="waiting",
            restaurant_search_status=group.restaurant_search_status,
        )


if __name__ == "__main__":
    unittest.main()
