from sqlalchemy import CheckConstraint, Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

LOCATION_TYPE_MUNICIPALITY = "municipality"
LOCATION_TYPE_STATION = "station"


class Municipality(Base):
    __tablename__ = "municipalities"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    municipality_code: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        unique=True,
        index=True,
    )
    prefecture_name: Mapped[str] = mapped_column(String(32), nullable=False)
    municipality_name: Mapped[str] = mapped_column(String(64), nullable=False)
    name_kana: Mapped[str | None] = mapped_column(String(128), nullable=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)


class Station(Base):
    __tablename__ = "stations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
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
    station_name: Mapped[str] = mapped_column(String(128), nullable=False)
    name_kana: Mapped[str | None] = mapped_column(String(128), nullable=True)
    prefecture_name: Mapped[str] = mapped_column(String(32), nullable=False)
    municipality_name: Mapped[str | None] = mapped_column(String(64), nullable=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    line_name: Mapped[str | None] = mapped_column(String(128), nullable=True)


class LocationSearchEntry(Base):
    __tablename__ = "location_search"
    __table_args__ = (
        CheckConstraint(
            "location_type IN ('municipality', 'station')",
            name="ck_location_search_location_type",
        ),
    )

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    location_type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    source_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    name_kana: Mapped[str | None] = mapped_column(String(128), nullable=True)
    normalized_name: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    normalized_kana: Mapped[str | None] = mapped_column(
        String(128),
        nullable=True,
        index=True,
    )
    display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    prefecture_name: Mapped[str] = mapped_column(String(32), nullable=False)
    municipality_name: Mapped[str | None] = mapped_column(String(64), nullable=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    municipality_code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    station_code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    station_group_code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    line_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
