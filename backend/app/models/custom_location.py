import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Float, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.db.base import Base

CUSTOM_LOCATION_SOURCE_CURRENT_LOCATION = "current_location"
CUSTOM_LOCATION_SOURCE_MAP_PIN = "map_pin"
CUSTOM_LOCATION_SOURCES = (
    CUSTOM_LOCATION_SOURCE_CURRENT_LOCATION,
    CUSTOM_LOCATION_SOURCE_MAP_PIN,
)


class CustomLocation(Base):
    __tablename__ = "custom_locations"
    __table_args__ = (
        CheckConstraint(
            "source IN ('current_location', 'map_pin')",
            name="ck_custom_locations_source",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    prefecture_name: Mapped[str | None] = mapped_column(String(32), nullable=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    accuracy_meters: Mapped[float | None] = mapped_column(Float, nullable=True)
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
    )
