from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.location import LocationSearchResult
from app.services.location_service import (
    DEFAULT_LOCATION_SEARCH_LIMIT,
    MAX_LOCATION_SEARCH_LIMIT,
    InvalidLocationIdError,
    LocationService,
)

router = APIRouter(tags=["locations"])


@router.get(
    "/search",
    response_model=list[LocationSearchResult],
    summary="地点を検索する",
    description="市区町村と駅を同じ候補一覧として検索します。",
)
def search_locations(
    q: Annotated[str, Query(min_length=0, max_length=128)] = "",
    limit: Annotated[
        int,
        Query(ge=1),
    ] = DEFAULT_LOCATION_SEARCH_LIMIT,
    db: Session = Depends(get_db),
) -> list[LocationSearchResult]:
    service = LocationService(db)
    return service.search(q, limit)


@router.get(
    "/{location_id:path}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="地点IDの存在を確認する",
    description="選択後に保持した地点IDが有効な形式か確認します。",
)
def validate_location(
    location_id: str,
    db: Session = Depends(get_db),
) -> None:
    service = LocationService(db)
    try:
        service.validate_location_id(location_id)
    except InvalidLocationIdError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Location not found",
        ) from exc
