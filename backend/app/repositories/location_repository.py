from sqlalchemy import case, or_, select
from sqlalchemy.orm import Session

from app.models.location import (
    LOCATION_TYPE_MUNICIPALITY,
    LOCATION_TYPE_STATION,
    LocationSearchEntry,
)


class LocationRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def search(
        self,
        normalized_query: str,
        limit: int,
        prefecture: str | None = None,
    ) -> list[LocationSearchEntry]:
        escaped_query = _escape_like(normalized_query)
        prefix = f"{escaped_query}%"
        contains = f"%{escaped_query}%"
        name = LocationSearchEntry.normalized_name
        kana = LocationSearchEntry.normalized_kana

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
            (LocationSearchEntry.location_type == LOCATION_TYPE_STATION, 0),
            (LocationSearchEntry.location_type == LOCATION_TYPE_MUNICIPALITY, 1),
            else_=2,
        )

        conditions = [
            or_(
                name.like(contains, escape="\\"),
                kana.like(contains, escape="\\"),
            )
        ]
        if prefecture:
            conditions.append(LocationSearchEntry.prefecture_name == prefecture)

        statement = (
            select(LocationSearchEntry)
            .where(*conditions)
            .order_by(
                match_rank,
                type_rank,
                LocationSearchEntry.prefecture_name,
                LocationSearchEntry.municipality_name,
                LocationSearchEntry.name,
                LocationSearchEntry.line_name,
            )
            .limit(limit)
        )
        return list(self.db.scalars(statement).all())

    def exists_by_location_id(self, location_id: str) -> bool:
        statement = select(LocationSearchEntry.id).where(
            LocationSearchEntry.id == location_id
        )
        return self.db.scalar(statement) is not None

    def get_by_location_id(self, location_id: str) -> LocationSearchEntry | None:
        statement = select(LocationSearchEntry).where(
            LocationSearchEntry.id == location_id
        )
        return self.db.scalar(statement)


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
