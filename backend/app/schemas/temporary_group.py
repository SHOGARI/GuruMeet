from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class TemporaryGroupCreate(BaseModel):
    creator_id: str | None = Field(
        default=None,
        max_length=128,
        description="任意の作成者ID。認証連携後は認証情報から設定する想定。",
        examples=["user_123"],
    )


class TemporaryGroupJoinRequest(BaseModel):
    code: str = Field(
        min_length=5,
        max_length=5,
        description="手入力参加用の5桁コード。使用文字は ABCDEFGHJKLMNPQRSTUVWXYZ23456789。",
        examples=["A7K2F"],
    )


class TemporaryGroupResponse(BaseModel):
    id: UUID = Field(description="一時グループのUUID。frontend側で共有URLを組み立てるために使う。")
    code: str = Field(description="手入力参加用の5桁コード。", examples=["A7K2F"])
    expires_at: datetime = Field(description="この時刻を過ぎると取得・参加できない。")


class TemporaryGroupDetail(TemporaryGroupResponse):
    created_at: datetime = Field(description="一時グループが作成された時刻。")
    creator_id: str | None = Field(default=None, description="任意の作成者ID。")
