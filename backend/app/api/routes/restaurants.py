from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status

from app.services.hotpepper_service import (
    HotPepperAPIError,
    HotPepperAPITimeoutError,
    search_hotpepper_restaurants,
    search_restaurants_by_location,
    test_hotpepper_connection,
)

router = APIRouter(tags=["restaurants"])


@router.get("/test")
async def test_restaurants() -> dict[str, bool | int]:
    try:
        return await test_hotpepper_connection()
    except HotPepperAPITimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Hot Pepper API request timed out",
        ) from None
    except HotPepperAPIError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to communicate with Hot Pepper API",
        ) from None


@router.get("/search-by-location")
async def search_by_location(
    location: Annotated[
        str,
        Query(description="都道府県、市区町村、駅名、地域名"),
    ],
    count: Annotated[
        int,
        Query(ge=1, le=100, description="取得する店舗数"),
    ] = 20,
) -> dict[str, object]:
    normalized_location = location.strip()
    if not normalized_location:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="location must not be blank",
        )

    try:
        return await search_restaurants_by_location(
            location=normalized_location,
            count=count,
        )
    except HotPepperAPITimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Hot Pepper API request timed out",
        ) from None
    except HotPepperAPIError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to communicate with Hot Pepper API",
        ) from None


@router.get("/search")
async def search_restaurants(
    lat: Annotated[float, Query(ge=-90, le=90)],
    lng: Annotated[float, Query(ge=-180, le=180)],
    search_range: Annotated[int, Query(alias="range", ge=1, le=5)] = 3,
    count: Annotated[int, Query(ge=1, le=100)] = 10,
) -> dict[str, object]:
    try:
        return await search_hotpepper_restaurants(
            lat=lat,
            lng=lng,
            search_range=search_range,
            count=count,
        )
    except HotPepperAPITimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Hot Pepper API request timed out",
        ) from None
    except HotPepperAPIError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to communicate with Hot Pepper API",
        ) from None
