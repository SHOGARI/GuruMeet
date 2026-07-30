from sqlalchemy import case, or_, select
from sqlalchemy.orm import Session, joinedload

from app.models.location import (
    LOCATION_TYPE_MUNICIPALITY,
    LOCATION_TYPE_STATION,
    Location,
    StationLocation,
)


class LocationRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def search(
        self,
        normalized_query: str,
        limit: int,
        prefecture: str | None = None,
    ) -> list[Location]:
        escaped_query = _escape_like(normalized_query)
        prefix = f"{escaped_query}%"
        contains = f"%{escaped_query}%"
        name = Location.normalized_name
        kana = Location.normalized_kana

        match_rank = case(
            (or_(name == normalized_query, kana == normalized_query), 0),
            (
                or_(
                    name.like(prefix, escape="\\"),
                    kana.like(prefix, escape="\\"),
                ),
                1,
            ),
            else_=2,
        )
        type_rank = case(
            (Location.location_type == LOCATION_TYPE_STATION, 0),
            (Location.location_type == LOCATION_TYPE_MUNICIPALITY, 1),
            else_=2,
        )

        conditions = [
            or_(
                name.like(contains, escape="\\"),
                kana.like(contains, escape="\\"),
            )
        ]
        if prefecture:
            conditions.append(Location.prefecture_name == prefecture)

        statement = (
            select(Location)
            .options(
                joinedload(Location.municipality),
                joinedload(Location.station),
            )
            .outerjoin(StationLocation)
            .where(*conditions)
            .order_by(
                match_rank,
                type_rank,
                Location.prefecture_name,
                Location.municipality_name,
                Location.name,
                StationLocation.line_name,
            )
            .limit(limit)
        )
        return list(self.db.scalars(statement).all())

    def list_by_prefecture(self, prefecture: str) -> list[Location]:
        type_rank = case(
            (Location.location_type == LOCATION_TYPE_STATION, 0),
            (Location.location_type == LOCATION_TYPE_MUNICIPALITY, 1),
            else_=2,
        )
        statement = (
            select(Location)
            .options(
                joinedload(Location.municipality),
                joinedload(Location.station),
            )
            .outerjoin(StationLocation)
            .where(Location.prefecture_name == prefecture)
            .order_by(
                type_rank,
                Location.municipality_name,
                Location.name,
                StationLocation.line_name,
            )
        )
        return list(self.db.scalars(statement).all())

    def exists_by_location_id(self, location_id: str) -> bool:
        statement = select(Location.id).where(Location.id == location_id)
        return self.db.scalar(statement) is not None

    def get_by_location_id(self, location_id: str) -> Location | None:
        statement = (
            select(Location)
            .options(
                joinedload(Location.municipality),
                joinedload(Location.station),
            )
            .where(Location.id == location_id)
        )
        return self.db.scalar(statement)


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
