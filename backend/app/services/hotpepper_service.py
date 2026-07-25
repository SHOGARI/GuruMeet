import json
from dataclasses import dataclass
from datetime import UTC, datetime

import httpx

from app.core.config import settings

HOTPEPPER_GOURMET_SEARCH_URL = (
    "https://webservice.recruit.co.jp/hotpepper/gourmet/v1/"
)
REQUEST_TIMEOUT_SECONDS = 10.0
TEMPORARY_GROUP_RESTAURANT_LIMIT = 10


@dataclass(frozen=True)
class HotPepperBudgetRange:
    code: str
    min_yen: int
    max_yen: int


HOTPEPPER_BUDGET_RANGES = (
    HotPepperBudgetRange(code="B001", min_yen=0, max_yen=2000),
    HotPepperBudgetRange(code="B002", min_yen=2001, max_yen=3000),
    HotPepperBudgetRange(code="B003", min_yen=3001, max_yen=4000),
    HotPepperBudgetRange(code="B008", min_yen=4001, max_yen=5000),
    HotPepperBudgetRange(code="B004", min_yen=5001, max_yen=7000),
    HotPepperBudgetRange(code="B005", min_yen=7001, max_yen=10000),
)


class HotPepperAPIError(Exception):
    """Raised when the Hot Pepper API cannot return a usable response."""


class HotPepperAPITimeoutError(HotPepperAPIError):
    """Raised when the Hot Pepper API request exceeds the timeout."""


class HotPepperBudgetRangeError(ValueError):
    """Raised when a requested budget does not overlap a supported range."""


async def test_hotpepper_connection() -> dict[str, bool | int]:
    params = {
        "key": settings.hotpepper_api_key.get_secret_value(),
        "lat": 35.6812,
        "lng": 139.7671,
        "range": 3,
        "count": 5,
        "format": "json",
    }

    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT_SECONDS) as client:
            response = await client.get(HOTPEPPER_GOURMET_SEARCH_URL, params=params)
            response.raise_for_status()
    except httpx.TimeoutException:
        raise HotPepperAPITimeoutError from None
    except (httpx.HTTPStatusError, httpx.RequestError):
        raise HotPepperAPIError from None

    try:
        payload = response.json()
    except (json.JSONDecodeError, UnicodeDecodeError):
        raise HotPepperAPIError from None

    if not isinstance(payload, dict):
        raise HotPepperAPIError

    results = payload.get("results")
    if not isinstance(results, dict) or results.get("error"):
        raise HotPepperAPIError

    shops = results.get("shop", [])
    if not isinstance(shops, list):
        raise HotPepperAPIError

    return {"success": True, "returned_count": len(shops)}


async def search_hotpepper_restaurants(
    lat: float,
    lng: float,
    search_range: int,
    count: int,
) -> dict[str, object]:
    params = {
        "lat": lat,
        "lng": lng,
        "range": search_range,
        "count": count,
    }
    shops = await _fetch_hotpepper_shops(params)
    return _build_search_response(shops)


async def search_restaurants_by_location(
    location: str,
    count: int = 20,
) -> dict[str, object]:
    normalized_location = location.strip()
    if not normalized_location:
        raise ValueError("location must not be blank")

    params = {
        "keyword": normalized_location,
        "count": count,
    }
    shops = await _fetch_hotpepper_shops(params)
    return _build_search_response(shops)


async def search_restaurants_for_group(
    location: str,
    budget_min: int | None,
    budget_max: int | None,
) -> dict[str, object]:
    normalized_location = location.strip()
    if not normalized_location:
        raise ValueError("location must not be blank")

    budget_codes = select_hotpepper_budget_codes(budget_min, budget_max)
    if (budget_min is not None or budget_max is not None) and not budget_codes:
        raise HotPepperBudgetRangeError(
            "requested budget is outside Hot Pepper supported ranges"
        )

    params: dict[str, object] = {
        "keyword": normalized_location,
        "count": TEMPORARY_GROUP_RESTAURANT_LIMIT,
    }
    if budget_codes:
        params["budget"] = ",".join(budget_codes)

    shops = await _fetch_hotpepper_shops(params)
    return _build_temporary_group_restaurant_result(shops)


def select_hotpepper_budget_codes(
    budget_min: int | None,
    budget_max: int | None,
) -> list[str]:
    if budget_min is None and budget_max is None:
        return []

    requested_min = budget_min if budget_min is not None else 0
    requested_max = budget_max if budget_max is not None else float("inf")

    return [
        budget_range.code
        for budget_range in HOTPEPPER_BUDGET_RANGES
        if budget_range.min_yen <= requested_max
        and budget_range.max_yen >= requested_min
    ]


async def _fetch_hotpepper_shops(
    search_params: dict[str, object],
) -> list[dict[str, object]]:
    params = {
        "key": settings.hotpepper_api_key.get_secret_value(),
        **search_params,
        "format": "json",
    }

    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT_SECONDS) as client:
            response = await client.get(HOTPEPPER_GOURMET_SEARCH_URL, params=params)
            response.raise_for_status()
    except httpx.TimeoutException:
        raise HotPepperAPITimeoutError from None
    except (httpx.HTTPStatusError, httpx.RequestError):
        raise HotPepperAPIError from None

    try:
        payload = response.json()
    except (json.JSONDecodeError, UnicodeDecodeError):
        raise HotPepperAPIError from None

    if not isinstance(payload, dict):
        raise HotPepperAPIError

    results = payload.get("results")
    if not isinstance(results, dict) or results.get("error"):
        raise HotPepperAPIError

    shops = results.get("shop")
    if shops is None:
        return []
    if not isinstance(shops, list):
        raise HotPepperAPIError

    return [shop for shop in shops if isinstance(shop, dict)]


def _build_search_response(
    shops: list[dict[str, object]],
) -> dict[str, object]:
    shop_summaries = []
    for shop in shops:
        photo = shop.get("photo")
        pc_photo = photo.get("pc") if isinstance(photo, dict) else None
        image_url = pc_photo.get("l") if isinstance(pc_photo, dict) else ""

        shop_summaries.append(
            {
                "id": shop.get("id") if isinstance(shop.get("id"), str) else "",
                "name": (
                    shop.get("name") if isinstance(shop.get("name"), str) else ""
                ),
                "address": (
                    shop.get("address")
                    if isinstance(shop.get("address"), str)
                    else ""
                ),
                "image_url": image_url if isinstance(image_url, str) else "",
            }
        )

    return {
        "success": True,
        "count": len(shop_summaries),
        "shops": shop_summaries,
    }


def _build_temporary_group_restaurant_result(
    shops: list[dict[str, object]],
) -> dict[str, object]:
    restaurants: list[dict[str, str]] = []
    seen_shop_ids: set[str] = set()

    for shop in shops:
        shop_id = _string_value(shop.get("id"))
        if shop_id and shop_id in seen_shop_ids:
            continue
        if shop_id:
            seen_shop_ids.add(shop_id)

        restaurants.append(
            {
                "id": shop_id,
                "name": _string_value(shop.get("name")),
                "address": _string_value(shop.get("address")),
                "access": _string_value(shop.get("access")),
                "genre": _nested_string_value(shop.get("genre"), "name"),
                "budget": _nested_string_value(shop.get("budget"), "name"),
                "image_url": _nested_string_value(
                    _nested_mapping_value(shop.get("photo"), "pc"),
                    "l",
                ),
                "shop_url": _nested_string_value(shop.get("urls"), "pc"),
            }
        )
        if len(restaurants) >= TEMPORARY_GROUP_RESTAURANT_LIMIT:
            break

    return {
        "restaurants": restaurants,
        "searched_at": datetime.now(UTC).isoformat(),
    }


def _string_value(value: object) -> str:
    return value if isinstance(value, str) else ""


def _nested_mapping_value(value: object, key: str) -> object:
    return value.get(key) if isinstance(value, dict) else None


def _nested_string_value(value: object, key: str) -> str:
    return _string_value(_nested_mapping_value(value, key))
