from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import AliasChoices, BaseModel, Field


class TemporaryGroupCreate(BaseModel):
    participant_token: str | None = Field(
        default=None,
        min_length=16,
        max_length=256,
        description=(
            "匿名参加者トークン。作成者を参加者として登録する場合に指定する。"
        ),
        examples=["8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"],
    )
    creator_id: str | None = Field(
        default=None,
        max_length=128,
        description="任意の作成者ID。認証連携後は認証情報から設定する想定。",
        examples=["user_123"],
    )
    participant_count: int | None = Field(
        default=None,
        gt=0,
        description="参加人数。",
        examples=[4],
    )
    location: str | None = Field(
        default=None,
        max_length=255,
        description="希望場所。",
        examples=["渋谷"],
    )
    location_id: str | None = Field(
        default=None,
        validation_alias=AliasChoices("location_id", "locationId"),
        max_length=40,
        description="地点検索APIで選択した地点ID。",
        examples=["station:1132005"],
    )
    budget_min: int | None = Field(
        default=None,
        ge=0,
        description="予算下限。",
        examples=[2000],
    )
    budget_max: int | None = Field(
        default=None,
        ge=0,
        description="予算上限。",
        examples=[3000],
    )


class TemporaryGroupJoinRequest(BaseModel):
    code: str = Field(
        min_length=5,
        max_length=5,
        description="手入力参加用の5桁コード。使用文字は ABCDEFGHJKLMNPQRSTUVWXYZ23456789。",
        examples=["A7K2F"],
    )
    participant_token: str = Field(
        min_length=16,
        max_length=256,
        description="匿名参加者トークン。localStorageとcookieに同じ値を保存して送る。",
        examples=["8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"],
    )


class TemporaryGroupParticipantJoinRequest(BaseModel):
    participant_token: str = Field(
        min_length=16,
        max_length=256,
        description="匿名参加者トークン。localStorageとcookieに同じ値を保存して送る。",
        examples=["8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"],
    )


class TemporaryGroupResponse(BaseModel):
    id: UUID = Field(description="一時グループのUUID。frontend側で共有URLを組み立てるために使う。")
    code: str = Field(description="手入力参加用の5桁コード。", examples=["A7K2F"])
    expires_at: datetime = Field(description="この時刻を過ぎると取得・参加できない。")
    joined_participant_count: int = Field(description="現在参加済みの人数。")
    is_full: bool = Field(description="参加人数が上限に達しているか。")


class TemporaryGroupDetail(TemporaryGroupResponse):
    created_at: datetime = Field(description="一時グループが作成された時刻。")
    voting_started_at: datetime | None = Field(
        default=None,
        description="投票開始時刻。未開始の場合はnull。",
    )
    creator_id: str | None = Field(default=None, description="任意の作成者ID。")
    participant_count: int | None = Field(default=None, description="参加人数。")
    location: str | None = Field(default=None, description="希望場所。")
    location_id: str | None = Field(default=None, description="選択された地点ID。")
    location_type: str | None = Field(
        default=None,
        description="地点種別。municipality または station。",
    )
    location_radius_meters: int | None = Field(
        default=None,
        description="座標検索に利用する半径。市区町村は区域検索不可時のfallback。",
    )
    location_municipality_code: str | None = Field(
        default=None,
        description="市区町村検索に利用する市区町村コード。",
    )
    location_latitude: float | None = Field(default=None, description="地点緯度。")
    location_longitude: float | None = Field(default=None, description="地点経度。")
    budget_min: int | None = Field(default=None, description="予算下限。")
    budget_max: int | None = Field(default=None, description="予算上限。")
    restaurant_search_status: str = Field(
        description=(
            "Hot Pepper店舗検索の状態。not_requested, succeeded, no_results のいずれか。"
        )
    )
    restaurant: dict[str, Any] | None = Field(
        default=None,
        description="選択済み、または候補の店舗情報。",
    )


class TemporaryGroupRestaurant(BaseModel):
    id: str
    name: str
    address: str
    access: str
    genre: str
    budget: str
    image_url: str
    shop_url: str


class TemporaryGroupVotingStartRequest(BaseModel):
    participant_token: str = Field(
        min_length=16,
        max_length=256,
        description="投票開始を行う参加者の匿名参加者トークン。",
    )


class TemporaryGroupVoteSubmitRequest(BaseModel):
    participant_token: str = Field(
        min_length=16,
        max_length=256,
        description="投票する参加者の匿名参加者トークン。",
    )
    restaurant_id: str = Field(
        min_length=1,
        max_length=128,
        description="店舗候補ID。",
    )
    liked: bool = Field(description="食べたい場合はtrue、見送りの場合はfalse。")


class TemporaryGroupParticipantVotingProgress(BaseModel):
    anonymous_user_id: UUID
    completed_vote_count: int
    is_complete: bool


class TemporaryGroupVotingProgress(BaseModel):
    voting_started_at: datetime | None
    candidate_count: int
    participant_count: int | None
    joined_participant_count: int
    completed_participant_count: int
    is_complete: bool
    participants: list[TemporaryGroupParticipantVotingProgress]


class TemporaryGroupVoteSubmitResponse(BaseModel):
    restaurant_id: str
    liked: bool
    progress: TemporaryGroupVotingProgress


class TemporaryGroupRestaurantResult(BaseModel):
    restaurant: TemporaryGroupRestaurant
    like_count: int
    reject_count: int
    vote_count: int
    rank: int
    like_rate: float


class TemporaryGroupVotingResult(BaseModel):
    voting_started_at: datetime | None
    candidate_count: int
    joined_participant_count: int
    completed_participant_count: int
    is_complete: bool
    has_tie: bool
    top_like_count: int
    results: list[TemporaryGroupRestaurantResult]
