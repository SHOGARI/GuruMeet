import json
from dataclasses import dataclass
from datetime import UTC, datetime

import httpx

from app.core.config import settings

HOTPEPPER_GOURMET_SEARCH_URL = (
    "https://webservice.recruit.co.jp/hotpepper/gourmet/v1/"
)
REQUEST_TIMEOUT_SECONDS = 10.0
TEMPORARY_GROUP_RESTAURANT_CANDIDATE_LIMIT = 30
TEMPORARY_GROUP_RESTAURANT_RESULT_LIMIT = 10
MAX_HOTPEPPER_BUDGET_CODES = 2
MAX_RESTAURANTS_PER_GENRE = 2
HOTPEPPER_SEARCH_RANGE_BY_RADIUS_METERS = (
    (300, 1),
    (500, 2),
    (1000, 3),
    (2000, 4),
    (3000, 5),
)

UNKNOWN_GENRE_NAME = "不明"

BUDGET_SCORE_RULES = (
    (300, 70),
    (600, 63),
    (900, 56),
    (1200, 49),
    (1500, 42),
)
BUDGET_SCORE_FALLBACK = 28

CAPACITY_SCORE_RULES = (
    (1, 0),
    (2, 12),
    (4, 21),
    (8, 27),
)
CAPACITY_SCORE_MAX = 30
CAPACITY_SCORE_FALLBACK = 9


@dataclass(frozen=True)
class HotPepperBudgetRange:
    code: str
    min_yen: int
    max_yen: int | None


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


class HotPepperConfigurationError(HotPepperAPIError):
    """Raised when the Hot Pepper API key is not configured."""


class HotPepperBudgetRangeError(ValueError):
    """Raised when a requested budget does not overlap a supported range."""


async def test_hotpepper_connection() -> dict[str, bool | int]:
    params = {
        "key": _get_hotpepper_api_key(),
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
    participant_count: int | None = None,
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
        "count": TEMPORARY_GROUP_RESTAURANT_CANDIDATE_LIMIT,
    }
    if budget_codes:
        params["budget"] = ",".join(budget_codes)

    shops = await _fetch_hotpepper_shops(params)
    unique_shops = _deduplicate_shops(shops)
    ranked_restaurants = _rank_restaurants(
        unique_shops,
        budget_min=budget_min,
        budget_max=budget_max,
        participant_count=participant_count,
    )
    selected_shops = _select_restaurants_with_genre_limit(ranked_restaurants)
    return _build_temporary_group_restaurant_result(selected_shops)


async def search_restaurants_for_group_by_coordinates(
    latitude: float,
    longitude: float,
    radius_meters: int,
    budget_min: int | None,
    budget_max: int | None,
    participant_count: int | None = None,
) -> dict[str, object]:
    budget_codes = select_hotpepper_budget_codes(budget_min, budget_max)
    if (budget_min is not None or budget_max is not None) and not budget_codes:
        raise HotPepperBudgetRangeError(
            "requested budget is outside Hot Pepper supported ranges"
        )

    params: dict[str, object] = {
        "lat": latitude,
        "lng": longitude,
        "range": hotpepper_range_for_radius(radius_meters),
        "count": TEMPORARY_GROUP_RESTAURANT_CANDIDATE_LIMIT,
    }
    if budget_codes:
        params["budget"] = ",".join(budget_codes)

    shops = await _fetch_hotpepper_shops(params)
    unique_shops = _deduplicate_shops(shops)
    ranked_restaurants = _rank_restaurants(
        unique_shops,
        budget_min=budget_min,
        budget_max=budget_max,
        participant_count=participant_count,
    )
    selected_shops = _select_restaurants_with_genre_limit(ranked_restaurants)
    return _build_temporary_group_restaurant_result(selected_shops)


def hotpepper_range_for_radius(radius_meters: int) -> int:
    for maximum_radius, search_range in HOTPEPPER_SEARCH_RANGE_BY_RADIUS_METERS:
        if radius_meters <= maximum_radius:
            return search_range
    return HOTPEPPER_SEARCH_RANGE_BY_RADIUS_METERS[-1][1]


def select_hotpepper_budget_codes(
    budget_min: int | None,
    budget_max: int | None,
) -> list[str]:
    if budget_min is None and budget_max is None:
        return []

    requested_min = budget_min if budget_min is not None else 0
    requested_max = budget_max if budget_max is not None else float("inf")

    overlapping_ranges = [
        budget_range
        for budget_range in HOTPEPPER_BUDGET_RANGES
        if budget_range.min_yen <= requested_max
        and (
            budget_range.max_yen is None
            or budget_range.max_yen >= requested_min
        )
    ]
    if len(overlapping_ranges) <= MAX_HOTPEPPER_BUDGET_CODES:
        return [budget_range.code for budget_range in overlapping_ranges]

    if _is_valid_non_negative_number(budget_min) and (
        _is_valid_non_negative_number(budget_max)
    ):
        group_midpoint = (budget_min + budget_max) / 2
        indexed_ranges = list(enumerate(overlapping_ranges))
        indexed_ranges.sort(
            key=lambda item: (
                _budget_range_midpoint_difference(item[1], group_midpoint),
                item[0],
            )
        )
        overlapping_ranges = [
            budget_range for _, budget_range in indexed_ranges
        ]

    return [
        budget_range.code
        for budget_range in overlapping_ranges[:MAX_HOTPEPPER_BUDGET_CODES]
    ]


async def _fetch_hotpepper_shops(
    search_params: dict[str, object],
) -> list[dict[str, object]]:
    params = {
        "key": _get_hotpepper_api_key(),
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


def _get_hotpepper_api_key() -> str:
    api_key = settings.hotpepper_api_key
    if api_key is None:
        raise HotPepperConfigurationError(
            "HOTPEPPER_API_KEY is not configured"
        )

    secret_value = api_key.get_secret_value()
    if not secret_value.strip():
        raise HotPepperConfigurationError(
            "HOTPEPPER_API_KEY is not configured"
        )

    return secret_value


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

    for shop in shops:
        shop_id = _string_value(shop.get("id"))
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
        if len(restaurants) >= TEMPORARY_GROUP_RESTAURANT_RESULT_LIMIT:
            break

    return {
        "restaurants": restaurants,
        "searched_at": datetime.now(UTC).isoformat(),
    }


def _deduplicate_shops(
    shops: list[dict[str, object]],
) -> list[dict[str, object]]:
    unique_shops: list[dict[str, object]] = []
    seen_shop_ids: set[str] = set()

    for shop in shops:
        shop_id = _string_value(shop.get("id"))
        if shop_id and shop_id in seen_shop_ids:
            continue
        if shop_id:
            seen_shop_ids.add(shop_id)
        unique_shops.append(shop)

    return unique_shops


def _get_restaurant_budget_range(
    shop: dict[str, object],
) -> HotPepperBudgetRange | None:
    budget_code = _nested_string_value(shop.get("budget"), "code")
    if not budget_code:
        return None

    for budget_range in HOTPEPPER_BUDGET_RANGES:
        if (
            budget_range.code == budget_code
            and budget_range.max_yen is not None
            and budget_range.min_yen <= budget_range.max_yen
        ):
            return budget_range

    return None


def _calculate_budget_score(
    budget_min: object,
    budget_max: object,
    shop: dict[str, object],
) -> int:
    if not _is_valid_non_negative_number(
        budget_min
    ) or not _is_valid_non_negative_number(budget_max):
        return BUDGET_SCORE_FALLBACK
    if budget_min > budget_max:
        return BUDGET_SCORE_FALLBACK

    budget_range = _get_restaurant_budget_range(shop)
    if budget_range is None or budget_range.max_yen is None:
        return BUDGET_SCORE_FALLBACK

    group_midpoint = (budget_min + budget_max) / 2
    shop_midpoint = (budget_range.min_yen + budget_range.max_yen) / 2
    budget_difference = abs(group_midpoint - shop_midpoint)

    for maximum_difference, score in BUDGET_SCORE_RULES:
        if budget_difference <= maximum_difference:
            return score

    return BUDGET_SCORE_FALLBACK


def _parse_capacity(value: object) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if value > 0 else None
    if isinstance(value, str):
        normalized_value = value.strip()
        if not normalized_value:
            return None
        try:
            capacity = int(normalized_value)
        except ValueError:
            return None
        return capacity if capacity > 0 else None
    return None


def _calculate_capacity_score(
    participant_count: object,
    capacity: object,
) -> int:
    parsed_participant_count = _parse_capacity(participant_count)
    parsed_capacity = _parse_capacity(capacity)
    if parsed_participant_count is None or parsed_capacity is None:
        return CAPACITY_SCORE_FALLBACK

    for multiplier, score in CAPACITY_SCORE_RULES:
        if parsed_capacity < parsed_participant_count * multiplier:
            return score

    return CAPACITY_SCORE_MAX


def _normalize_genre_name(shop: dict[str, object]) -> str:
    genre_name = _nested_string_value(shop.get("genre"), "name").strip()
    return genre_name or UNKNOWN_GENRE_NAME


def _rank_restaurants(
    shops: list[dict[str, object]],
    budget_min: object,
    budget_max: object,
    participant_count: object,
) -> list[dict[str, object]]:
    ranked_restaurants: list[dict[str, object]] = []

    for original_index, shop in enumerate(shops):
        budget_score = _calculate_budget_score(budget_min, budget_max, shop)
        capacity_score = _calculate_capacity_score(
            participant_count,
            shop.get("capacity"),
        )
        ranked_restaurants.append(
            {
                "shop": shop,
                "budget_score": budget_score,
                "capacity_score": capacity_score,
                "total_score": budget_score + capacity_score,
                "original_index": original_index,
            }
        )

    ranked_restaurants.sort(
        key=lambda restaurant: (
            -int(restaurant["total_score"]),
            -int(restaurant["budget_score"]),
            -int(restaurant["capacity_score"]),
            int(restaurant["original_index"]),
        )
    )
    return ranked_restaurants


def _select_restaurants_with_genre_limit(
    ranked_restaurants: list[dict[str, object]],
) -> list[dict[str, object]]:
    selected_shops: list[dict[str, object]] = []
    selected_indexes: set[int] = set()
    genre_counts: dict[str, int] = {}

    for restaurant in ranked_restaurants:
        shop = restaurant["shop"]
        if not isinstance(shop, dict):
            continue
        genre_name = _normalize_genre_name(shop)
        if genre_counts.get(genre_name, 0) >= MAX_RESTAURANTS_PER_GENRE:
            continue

        selected_shops.append(shop)
        selected_indexes.add(int(restaurant["original_index"]))
        genre_counts[genre_name] = genre_counts.get(genre_name, 0) + 1
        if len(selected_shops) >= TEMPORARY_GROUP_RESTAURANT_RESULT_LIMIT:
            return selected_shops

    for restaurant in ranked_restaurants:
        original_index = int(restaurant["original_index"])
        if original_index in selected_indexes:
            continue
        shop = restaurant["shop"]
        if not isinstance(shop, dict):
            continue
        selected_shops.append(shop)
        if len(selected_shops) >= TEMPORARY_GROUP_RESTAURANT_RESULT_LIMIT:
            break

    return selected_shops


def _is_valid_non_negative_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and value >= 0
    )


def _budget_range_midpoint_difference(
    budget_range: HotPepperBudgetRange,
    group_midpoint: float,
) -> float:
    if budget_range.max_yen is None:
        return float("inf")
    budget_midpoint = (budget_range.min_yen + budget_range.max_yen) / 2
    return abs(group_midpoint - budget_midpoint)


def _string_value(value: object) -> str:
    return value if isinstance(value, str) else ""


def _nested_mapping_value(value: object, key: str) -> object:
    return value.get(key) if isinstance(value, dict) else None


def _nested_string_value(value: object, key: str) -> str:
    return _string_value(_nested_mapping_value(value, key))
