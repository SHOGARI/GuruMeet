import json

import httpx

from app.core.config import settings

HOTPEPPER_GOURMET_SEARCH_URL = (
    "https://webservice.recruit.co.jp/hotpepper/gourmet/v1/"
)
REQUEST_TIMEOUT_SECONDS = 10.0


class HotPepperAPIError(Exception):
    """Raised when the Hot Pepper API cannot return a usable response."""


class HotPepperAPITimeoutError(HotPepperAPIError):
    """Raised when the Hot Pepper API request exceeds the timeout."""


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
        "key": settings.hotpepper_api_key.get_secret_value(),
        "lat": lat,
        "lng": lng,
        "range": search_range,
        "count": count,
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

    shop_summaries = []
    for shop in shops:
        if not isinstance(shop, dict):
            continue

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
