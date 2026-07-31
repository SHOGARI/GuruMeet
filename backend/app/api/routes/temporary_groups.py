from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.core.rate_limit import limit_join_by_ip
from app.db.database import SessionLocal
from app.db.session import get_db
from app.models.temporary_group import TemporaryGroup
from app.schemas.temporary_group import (
    TemporaryGroupCreate,
    TemporaryGroupDetail,
    TemporaryGroupJoinRequest,
    TemporaryGroupParticipantJoinRequest,
    TemporaryGroupResponse,
    TemporaryGroupVoteSubmitRequest,
    TemporaryGroupVoteSubmitResponse,
    TemporaryGroupVotingProgress,
    TemporaryGroupVotingResult,
    TemporaryGroupVotingStartRequest,
)
from app.services.discord_alert_service import (
    notify_group_created,
)
from app.services.hotpepper_service import (
    HotPepperAPIError,
    HotPepperAPITimeoutError,
)
from app.services.temporary_group_service import (
    TemporaryGroupCodeCollisionError,
    TemporaryGroupFullError,
    TemporaryGroupNotFoundError,
    TemporaryGroupParticipantNotFoundError,
    TemporaryGroupRestaurantNotFoundError,
    TemporaryGroupSearchCriteriaError,
    TemporaryGroupService,
    TemporaryGroupVotingCandidatesError,
    TemporaryGroupVotingCompleteError,
    TemporaryGroupVotingNotCompleteError,
    TemporaryGroupVotingNotReadyError,
    TemporaryGroupVotingNotStartedError,
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
        "location_idがある場合は、地点マスタの緯度経度から店舗候補を検索して保存します。"
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
                        "joined_participant_count": 1,
                        "is_full": False,
                    }
                }
            },
        },
        status.HTTP_503_SERVICE_UNAVAILABLE: {
            "description": "参加コード生成がリトライ上限を超えました。"
        },
        status.HTTP_502_BAD_GATEWAY: {
            "description": "Hot Pepper APIとの通信に失敗しました。"
        },
        status.HTTP_504_GATEWAY_TIMEOUT: {
            "description": "Hot Pepper APIのリクエストがタイムアウトしました。"
        },
    },
)
async def create_temporary_group(
    request_body: TemporaryGroupCreate | None = None,
    db: Session = Depends(get_db),
) -> TemporaryGroupResponse:
    data = request_body or TemporaryGroupCreate()
    try:
        restaurant, restaurant_search_status = (
            await TemporaryGroupService.search_restaurants_for_create(data, db)
        )
        return await run_in_threadpool(
            _create_temporary_group_response,
            data,
            restaurant,
            restaurant_search_status,
        )
    except TemporaryGroupCodeCollisionError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="一時グループのコード生成に失敗しました。再試行してください。",
        ) from exc
    except TemporaryGroupFullError as exc:
        raise _full() from exc
    except TemporaryGroupSearchCriteriaError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
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
                        "joined_participant_count": 2,
                        "is_full": False,
                        "created_at": "2026-07-15T12:00:00Z",
                        "creator_id": "user_123",
                        "participant_count": 4,
                        "location": "渋谷駅・東京都渋谷区",
                        "location_id": "station:1130205",
                        "budget_min": 2000,
                        "budget_max": 3000,
                        "restaurant_search_status": "succeeded",
                        "restaurant": {
                            "id": "restaurant_123",
                            "name": "渋谷ビストロ",
                        },
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

    return _to_detail(group, service)


@router.post(
    "/{group_id}/voting/start",
    response_model=TemporaryGroupVotingProgress,
    summary="一時グループの投票を開始する",
)
def start_temporary_group_voting(
    group_id: UUID,
    request_body: TemporaryGroupVotingStartRequest,
    db: Session = Depends(get_db),
) -> TemporaryGroupVotingProgress:
    service = TemporaryGroupService(db)
    try:
        return service.start_voting(group_id, request_body.participant_token)
    except TemporaryGroupNotFoundError:
        raise _not_found() from None
    except TemporaryGroupParticipantNotFoundError:
        raise _participant_not_found() from None
    except TemporaryGroupVotingNotReadyError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="参加予定人数がそろうまで投票を開始できません。",
        ) from None
    except TemporaryGroupVotingCandidatesError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.post(
    "/{group_id}/votes",
    response_model=TemporaryGroupVoteSubmitResponse,
    summary="一時グループの店舗候補へ投票する",
)
def submit_temporary_group_vote(
    group_id: UUID,
    request_body: TemporaryGroupVoteSubmitRequest,
    db: Session = Depends(get_db),
) -> TemporaryGroupVoteSubmitResponse:
    service = TemporaryGroupService(db)
    try:
        return service.submit_vote(
            group_id=group_id,
            participant_token=request_body.participant_token,
            restaurant_id=request_body.restaurant_id,
            liked=request_body.liked,
        )
    except TemporaryGroupNotFoundError:
        raise _not_found() from None
    except TemporaryGroupVotingNotStartedError:
        raise _voting_not_started() from None
    except TemporaryGroupVotingCompleteError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="投票はすでに完了しています。",
        ) from None
    except TemporaryGroupParticipantNotFoundError:
        raise _participant_not_found() from None
    except TemporaryGroupRestaurantNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="指定された店舗候補が存在しません。",
        ) from exc
    except TemporaryGroupVotingCandidatesError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.get(
    "/{group_id}/voting/progress",
    response_model=TemporaryGroupVotingProgress,
    summary="一時グループの投票進捗を取得する",
)
def get_temporary_group_voting_progress(
    group_id: UUID,
    db: Session = Depends(get_db),
) -> TemporaryGroupVotingProgress:
    service = TemporaryGroupService(db)
    try:
        return service.get_voting_progress(group_id)
    except TemporaryGroupNotFoundError:
        raise _not_found() from None
    except TemporaryGroupVotingCandidatesError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.get(
    "/{group_id}/voting/result",
    response_model=TemporaryGroupVotingResult,
    summary="一時グループの投票結果を取得する",
)
def get_temporary_group_voting_result(
    group_id: UUID,
    db: Session = Depends(get_db),
) -> TemporaryGroupVotingResult:
    service = TemporaryGroupService(db)
    try:
        return service.get_voting_result(group_id)
    except TemporaryGroupNotFoundError:
        raise _not_found() from None
    except TemporaryGroupVotingNotStartedError:
        raise _voting_not_started() from None
    except TemporaryGroupVotingNotCompleteError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="全員の投票が完了するまで結果を表示できません。",
        ) from None
    except TemporaryGroupVotingCandidatesError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.post(
    "/{group_id}/participants",
    response_model=TemporaryGroupResponse,
    dependencies=[Depends(limit_join_by_ip)],
    summary="UUIDから一時グループに参加する",
    description=(
        "UUIDで有効な一時グループを検索し、匿名参加者トークンを参加者として登録します。"
        "同じ匿名参加者トークンで再実行した場合は既存参加者として扱い、人数は増やしません。"
    ),
    responses={
        status.HTTP_200_OK: {
            "description": "一時グループへ参加しました。",
            "content": {
                "application/json": {
                    "example": {
                        "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
                        "code": "A7K2F",
                        "expires_at": "2026-07-16T12:00:00Z",
                        "joined_participant_count": 2,
                        "is_full": False,
                    }
                }
            },
        },
        status.HTTP_409_CONFLICT: {
            "description": "一時グループの参加人数が上限に達しています。"
        },
        status.HTTP_429_TOO_MANY_REQUESTS: {
            "description": "同じclient IPからの参加試行が多すぎます。"
        },
    },
)
def join_temporary_group_by_id(
    group_id: UUID,
    request_body: TemporaryGroupParticipantJoinRequest,
    db: Session = Depends(get_db),
) -> TemporaryGroupResponse:
    service = TemporaryGroupService(db)
    try:
        group = service.join_active_by_id(group_id, request_body.participant_token)
    except TemporaryGroupFullError as exc:
        raise _full() from exc

    if group is None:
        raise _not_found()

    return _to_response(group, service)


@router.post(
    "/join",
    response_model=TemporaryGroupResponse,
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
                        "joined_participant_count": 2,
                        "is_full": False,
                    }
                }
            },
        },
        status.HTTP_409_CONFLICT: {
            "description": "一時グループの参加人数が上限に達しています。"
        },
        status.HTTP_429_TOO_MANY_REQUESTS: {
            "description": "同じclient IPからの参加試行が多すぎます。"
        },
    },
)
def join_temporary_group(
    request_body: TemporaryGroupJoinRequest,
    db: Session = Depends(get_db),
) -> TemporaryGroupResponse:
    service = TemporaryGroupService(db)
    try:
        group = service.join_active_by_code(
            request_body.code,
            request_body.participant_token,
        )
    except TemporaryGroupFullError as exc:
        raise _full() from exc

    if group is None:
        raise _not_found()

    return _to_response(group, service)


def _to_detail(
    group: TemporaryGroup,
    service: TemporaryGroupService,
) -> TemporaryGroupDetail:
    joined_participant_count = service.count_participants(group.id)
    return TemporaryGroupDetail(
        id=group.id,
        code=group.code,
        expires_at=group.expires_at,
        joined_participant_count=joined_participant_count,
        is_full=service.is_full(group, joined_participant_count),
        created_at=group.created_at,
        voting_started_at=group.voting_started_at,
        voting_completed_at=group.voting_completed_at,
        creator_id=group.creator_id,
        participant_count=group.participant_count,
        location=group.location,
        location_id=group.location_id,
        custom_location_id=group.custom_location_id,
        budget_min=group.budget_min,
        budget_max=group.budget_max,
        restaurant_search_status=group.restaurant_search_status,
        restaurant=group.restaurant,
    )


def _to_response(
    group: TemporaryGroup,
    service: TemporaryGroupService,
) -> TemporaryGroupResponse:
    joined_participant_count = service.count_participants(group.id)
    return TemporaryGroupResponse(
        id=group.id,
        code=group.code,
        expires_at=group.expires_at,
        joined_participant_count=joined_participant_count,
        is_full=service.is_full(group, joined_participant_count),
    )


def _create_temporary_group_response(
    data: TemporaryGroupCreate,
    restaurant: dict[str, object] | None,
    restaurant_search_status: str,
) -> TemporaryGroupResponse:
    with SessionLocal() as db:
        service = TemporaryGroupService(db)
        group = service.create_group(
            data,
            restaurant=restaurant,
            restaurant_search_status=restaurant_search_status,
        )
        response = _to_response(group, service)
        notify_group_created(group)
        return response


def _not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="一時グループが存在しない、または期限切れです。",
    )


def _full() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail="一時グループの参加人数が上限に達しています。",
    )


def _participant_not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="この一時グループの参加者ではありません。",
    )


def _voting_not_started() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail="投票がまだ開始されていません。",
    )
