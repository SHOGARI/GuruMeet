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
            "description": "一時グループが存在しない、または期限切れです。"
        }
    },
)


@router.post(
    "",
    response_model=TemporaryGroupResponse,
    status_code=status.HTTP_201_CREATED,
    summary="一時グループを作成する",
    description=(
        "一時グループを作成し、UUIDと手入力参加用の5桁コードを発行します。"
        "共有URLはbackendでは作らず、返却されたUUIDを使ってfrontend側で組み立てます。"
    ),
    responses={
        status.HTTP_201_CREATED: {
            "description": "一時グループを作成しました。",
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
            "description": "参加コード生成がリトライ上限を超えました。"
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
            detail="一時グループのコード生成に失敗しました。再試行してください。",
        ) from exc

    return _to_response(group)


@router.get(
    "/{group_id}",
    response_model=TemporaryGroupDetail,
    summary="UUIDから一時グループを取得する",
    description=(
        "UUIDで一時グループを取得します。取得できるのは有効期限内のグループだけです。"
        "存在しないグループと期限切れグループは同じ404を返します。"
    ),
    responses={
        status.HTTP_200_OK: {
            "description": "有効な一時グループを取得しました。",
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
    summary="コードから一時グループに参加する",
    description=(
        "手入力参加用の5桁コードで有効な一時グループを検索します。"
        "存在しないコードと期限切れコードは同じ404を返します。"
        "総当たり対策として、client IPごとにレート制限します。"
    ),
    responses={
        status.HTTP_200_OK: {
            "description": "コードに対応する有効な一時グループを取得しました。",
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
            "description": "同じclient IPからの参加試行が多すぎます。"
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
        detail="一時グループが存在しない、または期限切れです。",
    )
