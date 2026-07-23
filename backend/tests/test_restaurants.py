import unittest
from unittest.mock import AsyncMock, MagicMock, patch

import httpx
from fastapi.testclient import TestClient

from app.main import app
from app.services.hotpepper_service import (
    HotPepperAPIError,
    search_restaurants_by_location,
)


class RestaurantRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)

    def test_location_searches_return_success(self) -> None:
        result = {"success": True, "count": 0, "shops": []}

        for location in ("渋谷", "埼玉県", "東京駅"):
            with self.subTest(location=location):
                with patch(
                    "app.api.routes.restaurants.search_restaurants_by_location",
                    new=AsyncMock(return_value=result),
                ) as search_mock:
                    response = self.client.get(
                        "/restaurants/search-by-location",
                        params={"location": location, "count": 10},
                    )

                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json(), result)
                search_mock.assert_awaited_once_with(
                    location=location,
                    count=10,
                )

    def test_location_is_trimmed(self) -> None:
        result = {"success": True, "count": 0, "shops": []}
        with patch(
            "app.api.routes.restaurants.search_restaurants_by_location",
            new=AsyncMock(return_value=result),
        ) as search_mock:
            response = self.client.get(
                "/restaurants/search-by-location",
                params={"location": "  渋谷  "},
            )

        self.assertEqual(response.status_code, 200)
        search_mock.assert_awaited_once_with(location="渋谷", count=20)

    def test_empty_location_is_rejected(self) -> None:
        response = self.client.get(
            "/restaurants/search-by-location",
            params={"location": ""},
        )
        self.assertEqual(response.status_code, 422)

    def test_whitespace_location_is_rejected(self) -> None:
        response = self.client.get(
            "/restaurants/search-by-location",
            params={"location": "   "},
        )
        self.assertEqual(response.status_code, 422)

    def test_count_below_minimum_is_rejected(self) -> None:
        response = self.client.get(
            "/restaurants/search-by-location",
            params={"location": "渋谷", "count": 0},
        )
        self.assertEqual(response.status_code, 422)

    def test_count_above_maximum_is_rejected(self) -> None:
        response = self.client.get(
            "/restaurants/search-by-location",
            params={"location": "渋谷", "count": 101},
        )
        self.assertEqual(response.status_code, 422)

    def test_no_results_returns_empty_shops(self) -> None:
        result = {"success": True, "count": 0, "shops": []}
        with patch(
            "app.api.routes.restaurants.search_restaurants_by_location",
            new=AsyncMock(return_value=result),
        ):
            response = self.client.get(
                "/restaurants/search-by-location",
                params={"location": "該当なし"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), result)

    def test_api_failure_returns_bad_gateway(self) -> None:
        with patch(
            "app.api.routes.restaurants.search_restaurants_by_location",
            new=AsyncMock(side_effect=HotPepperAPIError),
        ):
            response = self.client.get(
                "/restaurants/search-by-location",
                params={"location": "渋谷"},
            )

        self.assertEqual(response.status_code, 502)
        self.assertEqual(
            response.json(),
            {"detail": "Failed to communicate with Hot Pepper API"},
        )

    def test_existing_coordinate_search_still_works(self) -> None:
        result = {"success": True, "count": 0, "shops": []}
        with patch(
            "app.api.routes.restaurants.search_hotpepper_restaurants",
            new=AsyncMock(return_value=result),
        ):
            response = self.client.get(
                "/restaurants/search",
                params={"lat": 35.6812, "lng": 139.7671},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), result)


class RestaurantServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_keyword_is_sent_with_params_and_missing_shop_is_empty(self) -> None:
        response = MagicMock()
        response.raise_for_status.return_value = None
        response.json.return_value = {"results": {}}

        client = AsyncMock()
        client.get.return_value = response
        client_context = MagicMock()
        client_context.__aenter__ = AsyncMock(return_value=client)
        client_context.__aexit__ = AsyncMock(return_value=None)

        with patch(
            "app.services.hotpepper_service.httpx.AsyncClient",
            return_value=client_context,
        ):
            result = await search_restaurants_by_location("  日本橋  ", count=5)

        self.assertEqual(result, {"success": True, "count": 0, "shops": []})
        request_params = client.get.await_args.kwargs["params"]
        self.assertEqual(request_params["keyword"], "日本橋")
        self.assertEqual(request_params["count"], 5)
        self.assertEqual(request_params["format"], "json")

    async def test_connection_failure_raises_service_error(self) -> None:
        client = AsyncMock()
        client.get.side_effect = httpx.ConnectError("connection failed")
        client_context = MagicMock()
        client_context.__aenter__ = AsyncMock(return_value=client)
        client_context.__aexit__ = AsyncMock(return_value=None)

        with patch(
            "app.services.hotpepper_service.httpx.AsyncClient",
            return_value=client_context,
        ):
            with self.assertRaises(HotPepperAPIError):
                await search_restaurants_by_location("渋谷")


if __name__ == "__main__":
    unittest.main()
