from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class TemporaryGroupCreate(BaseModel):
    creator_id: str | None = Field(
        default=None,
        max_length=128,
        description="Optional creator identifier. Authentication integration can replace this later.",
        examples=["user_123"],
    )


class TemporaryGroupJoinRequest(BaseModel):
    code: str = Field(
        min_length=5,
        max_length=5,
        description="Five-character join code generated from ABCDEFGHJKLMNPQRSTUVWXYZ23456789.",
        examples=["A7K2F"],
    )


class TemporaryGroupResponse(BaseModel):
    id: UUID = Field(description="Temporary group UUID used by the frontend route.")
    code: str = Field(description="Five-character code for manual join.", examples=["A7K2F"])
    expires_at: datetime = Field(description="Timestamp after which this group cannot be fetched or joined.")


class TemporaryGroupDetail(TemporaryGroupResponse):
    created_at: datetime = Field(description="Timestamp when the temporary group was created.")
    creator_id: str | None = Field(default=None, description="Optional creator identifier.")
