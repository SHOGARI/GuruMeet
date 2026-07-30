from typing import cast

from sqlalchemy.orm import Session

from app.models.location import Location
from app.repositories.location_repository import LocationRepository
from app.schemas.location import LocationCandidate, LocationSearchResult
from app.services.location_normalizer import normalize_location_query

MIN_LOCATION_QUERY_LENGTH = 1
MAX_LOCATION_SEARCH_LIMIT = 50
DEFAULT_LOCATION_SEARCH_LIMIT = 20


class InvalidLocationIdError(ValueError):
    pass


class LocationService:
    def __init__(self, db: Session) -> None:
        self.repository = LocationRepository(db)

    def search(
        self,
        query: str,
        limit: int = DEFAULT_LOCATION_SEARCH_LIMIT,
        prefecture: str | None = None,
    ) -> list[LocationSearchResult]:
        normalized_query = normalize_location_query(query)
        if len(normalized_query) < MIN_LOCATION_QUERY_LENGTH:
            return []

        bounded_limit = min(limit, MAX_LOCATION_SEARCH_LIMIT)
        normalized_prefecture = prefecture.strip() if prefecture else None
        entries = self.repository.search(
            normalized_query,
            bounded_limit,
            normalized_prefecture,
        )
        return [self._to_result(entry) for entry in entries]

    def validate_location_id(self, location_id: str) -> None:
        self.get_location(location_id)

    def get_location(self, location_id: str) -> Location:
        if not self.is_valid_location_id_format(location_id):
            raise InvalidLocationIdError("invalid location id")

        entry = self.repository.get_by_location_id(location_id)
        if entry is None:
            raise InvalidLocationIdError("unknown location id")
        return entry

    def list_by_prefecture(self, prefecture: str) -> list[LocationCandidate]:
        normalized_prefecture = prefecture.strip()
        if not normalized_prefecture:
            return []

        entries = self.repository.list_by_prefecture(normalized_prefecture)
        return [self._to_candidate(entry) for entry in entries]

    @staticmethod
    def is_valid_location_id_format(location_id: str) -> bool:
        location_type, separator, source_key = location_id.partition(":")
        return (
            separator == ":"
            and location_type in {"municipality", "station"}
            and bool(source_key)
            and ":" not in source_key
        )

    @staticmethod
    def _to_result(entry: Location) -> LocationSearchResult:
        return LocationSearchResult(
            id=entry.id,
            type=cast("municipality | station", entry.location_type),
            name=entry.name,
            displayName=entry.display_name,
            prefecture=entry.prefecture_name,
            municipality=entry.municipality_name,
            latitude=entry.latitude,
            longitude=entry.longitude,
            lineName=entry.line_name,
        )

    @staticmethod
    def _to_candidate(entry: Location) -> LocationCandidate:
        return LocationCandidate(
            id=entry.id,
            type=cast("municipality | station", entry.location_type),
            name=entry.name,
            kana=entry.name_kana,
            displayName=entry.display_name,
            prefecture=entry.prefecture_name,
            municipality=entry.municipality_name,
            lineName=entry.line_name,
        )
