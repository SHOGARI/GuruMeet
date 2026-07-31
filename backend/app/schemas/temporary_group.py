from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import AliasChoices, BaseModel, Field
from pydantic import field_validator
from pydantic import model_validator

TemporaryGroupPhase = Literal["waiting", "swiping", "result"]


class CustomLocationCreate(BaseModel):
    display_name: str = Field(
        validation_alias=AliasChoices("display_name", "displayName"),
        min_length=1,
        max_length=255,
        examples=["東京都新宿区付近"],
    )
    prefecture_name: str | None = Field(
        default=None,
        validation_alias=AliasChoices("prefecture_name", "prefectureName"),
        max_length=32,
        examples=["東京都"],
    )
    latitude: float = Field(ge=-90, le=90, examples=[35.6895])
    longitude: float = Field(ge=-180, le=180, examples=[139.6917])
    accuracy_meters: float | None = Field(
        default=None,
        validation_alias=AliasChoices("accuracy_meters", "accuracyMeters"),
        ge=0,
        examples=[24.5],
    )
    source: Literal["current_location", "map_pin"] = Field(
        default="current_location",
        examples=["current_location"],
    )

    @field_validator("display_name")
    @classmethod
    def require_display_name(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("display_name must not be empty")
        return stripped


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
    custom_location: CustomLocationCreate | None = Field(
        default=None,
        validation_alias=AliasChoices("custom_location", "customLocation"),
        description="現在地や地図ピンなど、地点マスタ外の検索原点。",
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

    @model_validator(mode="after")
    def validate_location_origin(self) -> "TemporaryGroupCreate":
        if self.location_id is not None and self.custom_location is not None:
            raise ValueError("location_id and custom_location cannot be used together")
        return self


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


class TemporaryGroupDissolveRequest(BaseModel):
    participant_token: str = Field(
        min_length=16,
        max_length=256,
        description="グループを解散する作成者の匿名参加者トークン。",
        examples=["8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"],
    )


class TemporaryGroupResponse(BaseModel):
    id: UUID = Field(description="一時グループのUUID。frontend側で共有URLを組み立てるために使う。")
    code: str = Field(description="手入力参加用の5桁コード。", examples=["A7K2F"])
    expires_at: datetime = Field(description="この時刻を過ぎると取得・参加できない。")
    joined_participant_count: int = Field(description="現在参加済みの人数。")
    is_full: bool = Field(description="参加人数が上限に達しているか。")
    phase: TemporaryGroupPhase = Field(
        description="一時グループの進行状態。waiting, swiping, result のいずれか。",
        examples=["waiting"],
    )


class TemporaryGroupDetail(TemporaryGroupResponse):
    created_at: datetime = Field(description="一時グループが作成された時刻。")
    voting_started_at: datetime | None = Field(
        default=None,
        description="投票開始時刻。未開始の場合はnull。",
    )
    voting_completed_at: datetime | None = Field(
        default=None,
        description="グループ全員の投票完了時刻。未完了の場合はnull。",
    )
    creator_id: str | None = Field(default=None, description="任意の作成者ID。")
    participant_count: int | None = Field(default=None, description="参加人数。")
    location: str | None = Field(default=None, description="希望場所。")
    location_id: str | None = Field(default=None, description="選択された地点ID。")
    custom_location_id: UUID | None = Field(
        default=None,
        description="現在地や地図ピンから作成した検索原点ID。",
    )
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
    is_me: bool = False
    is_host: bool = False


class TemporaryGroupVotingProgress(BaseModel):
    voting_started_at: datetime | None
    voting_completed_at: datetime | None
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
    voting_completed_at: datetime | None
    candidate_count: int
    joined_participant_count: int
    completed_participant_count: int
    is_complete: bool
    has_tie: bool
    top_like_count: int
    results: list[TemporaryGroupRestaurantResult]
