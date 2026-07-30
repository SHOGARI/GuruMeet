import uuid
from datetime import datetime

from typing import Any

from sqlalchemy import CHAR, CheckConstraint, DateTime, ForeignKey, Integer, JSON, String
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.db.base import Base

RESTAURANT_SEARCH_STATUS_NOT_REQUESTED = "not_requested"
RESTAURANT_SEARCH_STATUS_SUCCEEDED = "succeeded"
RESTAURANT_SEARCH_STATUS_NO_RESULTS = "no_results"
RESTAURANT_SEARCH_STATUSES = (
    RESTAURANT_SEARCH_STATUS_NOT_REQUESTED,
    RESTAURANT_SEARCH_STATUS_SUCCEEDED,
    RESTAURANT_SEARCH_STATUS_NO_RESULTS,
)


class TemporaryGroup(Base):
    __tablename__ = "temporary_groups"
    __table_args__ = (
        CheckConstraint(
            "restaurant_search_status IN "
            "('not_requested', 'succeeded', 'no_results')",
            name="ck_temporary_groups_restaurant_search_status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    code: Mapped[str] = mapped_column(CHAR(5), unique=True, index=True, nullable=False)
    creator_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    participant_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    location: Mapped[str | None] = mapped_column(String(255), nullable=True)
    location_id: Mapped[str | None] = mapped_column(
        String(40),
        ForeignKey("locations.id"),
        nullable=True,
        index=True,
    )
    budget_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    budget_max: Mapped[int | None] = mapped_column(Integer, nullable=True)
    restaurant: Mapped[dict[str, Any] | None] = mapped_column(
        JSONB().with_variant(JSON(), "sqlite"),
        nullable=True,
    )
    restaurant_search_status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default=RESTAURANT_SEARCH_STATUS_NOT_REQUESTED,
        server_default=RESTAURANT_SEARCH_STATUS_NOT_REQUESTED,
    )
    voting_started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )
