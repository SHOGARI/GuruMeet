from fastapi import APIRouter, HTTPException, status

from app.services.hotpepper_service import (
    HotPepperAPIError,
    HotPepperAPITimeoutError,
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
