from __future__ import annotations

from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

LOCATION_TYPE_MUNICIPALITY = "municipality"
LOCATION_TYPE_STATION = "station"
LOCATION_SOURCE_GEOLONIA = "geolonia"
LOCATION_SOURCE_EKIDATA = "ekidata"


class Location(Base):
    __tablename__ = "locations"
    __table_args__ = (
        CheckConstraint(
            "location_type IN ('municipality', 'station')",
            name="ck_locations_location_type",
        ),
    )

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    location_type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    name_kana: Mapped[str | None] = mapped_column(String(128), nullable=True)
    normalized_name: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    normalized_kana: Mapped[str | None] = mapped_column(
        String(128),
        nullable=True,
        index=True,
    )
    display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    prefecture_name: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    municipality_name: Mapped[str | None] = mapped_column(String(64), nullable=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    source_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    municipality: Mapped[MunicipalityLocation | None] = relationship(
        back_populates="location",
        cascade="all, delete-orphan",
        uselist=False,
    )
    station: Mapped[StationLocation | None] = relationship(
        back_populates="location",
        cascade="all, delete-orphan",
        uselist=False,
    )

    @property
    def municipality_code(self) -> str | None:
        return self.municipality.municipality_code if self.municipality else None

    @property
    def station_code(self) -> str | None:
        return self.station.station_code if self.station else None

    @property
    def station_group_code(self) -> str | None:
        return self.station.station_group_code if self.station else None

    @property
    def line_name(self) -> str | None:
        return self.station.line_name if self.station else None


class MunicipalityLocation(Base):
    __tablename__ = "municipality_locations"

    location_id: Mapped[str] = mapped_column(
        String(40),
        ForeignKey("locations.id", ondelete="CASCADE"),
        primary_key=True,
    )
    municipality_code: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        unique=True,
        index=True,
    )

    location: Mapped[Location] = relationship(back_populates="municipality")


class StationLocation(Base):
    __tablename__ = "station_locations"

    location_id: Mapped[str] = mapped_column(
        String(40),
        ForeignKey("locations.id", ondelete="CASCADE"),
        primary_key=True,
    )
    station_code: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        unique=True,
        index=True,
    )
    station_group_code: Mapped[str | None] = mapped_column(
        String(16),
        nullable=True,
        index=True,
    )
    line_name: Mapped[str | None] = mapped_column(String(128), nullable=True)

    location: Mapped[Location] = relationship(back_populates="station")


# Temporary alias while service/repository code is migrated in step 2.
LocationSearchEntry = Location
