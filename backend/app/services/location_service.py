from typing import cast

from sqlalchemy.orm import Session

from app.models.location import LocationSearchEntry
from app.repositories.location_repository import LocationRepository
from app.schemas.location import LocationSearchResult
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
    ) -> list[LocationSearchResult]:
        normalized_query = normalize_location_query(query)
        if len(normalized_query) < MIN_LOCATION_QUERY_LENGTH:
            return []

        bounded_limit = min(limit, MAX_LOCATION_SEARCH_LIMIT)
        entries = self.repository.search(normalized_query, bounded_limit)
        return [self._to_result(entry) for entry in entries]

    def validate_location_id(self, location_id: str) -> None:
        location_type, _, source_key = location_id.partition(":")
        if location_type not in {"municipality", "station"} or not source_key:
            raise InvalidLocationIdError("invalid location id")

        if not self.repository.exists_by_location_id(location_id):
            raise InvalidLocationIdError("unknown location id")

    @staticmethod
    def _to_result(entry: LocationSearchEntry) -> LocationSearchResult:
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
