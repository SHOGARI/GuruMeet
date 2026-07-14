from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.rate_limit import limit_join_by_ip
from app.db.session import get_db
from app.models.temporary_group import TemporaryGroup
from app.schemas.temporary_group import (
    TemporaryGroupCreate,
    TemporaryGroupDetail,
    TemporaryGroupJoinRequest,
    TemporaryGroupResponse,
)
from app.services.temporary_group_service import (
    TemporaryGroupCodeCollisionError,
    TemporaryGroupService,
)

router = APIRouter(
    tags=["temporary-groups"],
    responses={
        status.HTTP_404_NOT_FOUND: {
            "description": "Temporary group does not exist or has expired."
        }
    },
)


@router.post(
    "",
    response_model=TemporaryGroupResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a temporary group",
    description=(
        "Creates a temporary group, issues a UUID and a five-character manual join code, "
        "and stores an expiration timestamp. The frontend builds share URLs from the returned UUID."
    ),
    responses={
        status.HTTP_201_CREATED: {
            "description": "Temporary group was created.",
            "content": {
                "application/json": {
                    "example": {
                        "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
                        "code": "A7K2F",
                        "expires_at": "2026-07-16T12:00:00Z",
                    }
                }
            },
        },
        status.HTTP_503_SERVICE_UNAVAILABLE: {
            "description": "Join code generation exceeded the retry limit."
        },
    },
)
def create_temporary_group(
    request_body: TemporaryGroupCreate | None = None,
    db: Session = Depends(get_db),
) -> TemporaryGroupResponse:
    service = TemporaryGroupService(db)
    try:
        group = service.create_group(request_body or TemporaryGroupCreate())
    except TemporaryGroupCodeCollisionError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Temporary group code generation failed. Please retry.",
        ) from exc

    return _to_response(group)


@router.get(
    "/{group_id}",
    response_model=TemporaryGroupDetail,
    summary="Get a temporary group by UUID",
    description=(
        "Fetches a temporary group by UUID only when it is still active. "
        "Expired groups return the same 404 response as missing groups."
    ),
    responses={
        status.HTTP_200_OK: {
            "description": "Active temporary group was found.",
            "content": {
                "application/json": {
                    "example": {
                        "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
                        "code": "A7K2F",
                        "expires_at": "2026-07-16T12:00:00Z",
                        "created_at": "2026-07-15T12:00:00Z",
                        "creator_id": "user_123",
                    }
                }
            },
        }
    },
)
def get_temporary_group(
    group_id: UUID,
    db: Session = Depends(get_db),
) -> TemporaryGroupDetail:
    service = TemporaryGroupService(db)
    group = service.get_active_by_id(group_id)
    if group is None:
        raise _not_found()

    return _to_detail(group)


@router.post(
    "/join",
    response_model=TemporaryGroupDetail,
    dependencies=[Depends(limit_join_by_ip)],
    summary="Join a temporary group by code",
    description=(
        "Looks up an active temporary group by a five-character manual join code. "
        "Missing and expired codes intentionally return the same 404 response. "
        "This endpoint is rate-limited by client IP."
    ),
    responses={
        status.HTTP_200_OK: {
            "description": "Active temporary group was found by code.",
            "content": {
                "application/json": {
                    "example": {
                        "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
                        "code": "A7K2F",
                        "expires_at": "2026-07-16T12:00:00Z",
                        "created_at": "2026-07-15T12:00:00Z",
                        "creator_id": "user_123",
                    }
                }
            },
        },
        status.HTTP_429_TOO_MANY_REQUESTS: {
            "description": "Too many join attempts from the same client IP."
        },
    },
)
def join_temporary_group(
    request_body: TemporaryGroupJoinRequest,
    db: Session = Depends(get_db),
) -> TemporaryGroupDetail:
    service = TemporaryGroupService(db)
    group = service.get_active_by_code(request_body.code)
    if group is None:
        raise _not_found()

    return _to_detail(group)


def _to_response(group: TemporaryGroup) -> TemporaryGroupResponse:
    return TemporaryGroupResponse(
        id=group.id,
        code=group.code,
        expires_at=group.expires_at,
    )


def _to_detail(group: TemporaryGroup) -> TemporaryGroupDetail:
    return TemporaryGroupDetail(
        id=group.id,
        code=group.code,
        expires_at=group.expires_at,
        created_at=group.created_at,
        creator_id=group.creator_id,
    )


def _not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Temporary group not found or expired.",
    )
