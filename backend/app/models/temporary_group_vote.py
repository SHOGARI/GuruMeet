import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.db.base import Base


class TemporaryGroupVote(Base):
    __tablename__ = "temporary_group_votes"
    __table_args__ = (
        UniqueConstraint(
            "temporary_group_id",
            "anonymous_user_id",
            "restaurant_id",
            name="uq_temporary_group_votes_group_user_restaurant",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    temporary_group_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("temporary_groups.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    anonymous_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("anonymous_users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    restaurant_id: Mapped[str] = mapped_column(String(128), nullable=False)
    liked: Mapped[bool] = mapped_column(Boolean, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
