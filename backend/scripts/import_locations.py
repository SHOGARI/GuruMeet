#!/usr/bin/env python
from __future__ import annotations

import argparse
import csv
import logging
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from statistics import fmean

from sqlalchemy import select
from sqlalchemy.orm import Session

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.db.database import SessionLocal  # noqa: E402
from app.models.location import (  # noqa: E402
    LOCATION_SOURCE_EKIDATA,
    LOCATION_SOURCE_GEOLONIA,
    LOCATION_TYPE_MUNICIPALITY,
    LOCATION_TYPE_STATION,
    Location,
    MunicipalityLocation,
    StationLocation,
)
from app.services.location_normalizer import normalize_location_query  # noqa: E402

LOGGER = logging.getLogger("import_locations")
INVALID_ROW_LOG_LIMIT = 20

PREFECTURES = (
    "北海道",
    "青森県",
    "岩手県",
    "宮城県",
    "秋田県",
    "山形県",
    "福島県",
    "茨城県",
    "栃木県",
    "群馬県",
    "埼玉県",
    "千葉県",
    "東京都",
    "神奈川県",
    "新潟県",
    "富山県",
    "石川県",
    "福井県",
    "山梨県",
    "長野県",
    "岐阜県",
    "静岡県",
    "愛知県",
    "三重県",
    "滋賀県",
    "京都府",
    "大阪府",
    "兵庫県",
    "奈良県",
    "和歌山県",
    "鳥取県",
    "島根県",
    "岡山県",
    "広島県",
    "山口県",
    "徳島県",
    "香川県",
    "愛媛県",
    "高知県",
    "福岡県",
    "佐賀県",
    "長崎県",
    "熊本県",
    "大分県",
    "宮崎県",
    "鹿児島県",
    "沖縄県",
)

PREFECTURE_BY_CODE = {str(index): name for index, name in enumerate(PREFECTURES, 1)}


@dataclass(frozen=True)
class MunicipalityImportRow:
    municipality_code: str
    prefecture_name: str
    municipality_name: str
    name_kana: str | None
    latitude: float
    longitude: float


@dataclass(frozen=True)
class StationImportRow:
    station_code: str
    station_group_code: str | None
    station_name: str
    name_kana: str | None
    prefecture_name: str
    municipality_name: str | None
    latitude: float
    longitude: float
    line_name: str | None


def main() -> int:
    parser = argparse.ArgumentParser(description="Import location master CSVs.")
    parser.add_argument("--municipalities-csv", type=Path, required=True)
    parser.add_argument("--stations-csv", type=Path, required=True)
    parser.add_argument("--station-lines-csv", type=Path)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    line_names = load_line_names(args.station_lines_csv) if args.station_lines_csv else {}
    municipality_rows = load_municipalities(args.municipalities_csv)
    station_rows = load_stations(args.stations_csv, line_names)

    with SessionLocal() as db:
        LOGGER.info("upserting municipalities: %s", len(municipality_rows))
        municipality_count = upsert_municipalities(db, municipality_rows)
        LOGGER.info("upserting stations: %s", len(station_rows))
        station_count = upsert_stations(db, station_rows)
        LOGGER.info("committing location master import")
        db.commit()

    LOGGER.info("municipalities upserted: %s", municipality_count)
    LOGGER.info("stations upserted: %s", station_count)
    return 0


def load_municipalities(path: Path) -> list[MunicipalityImportRow]:
    grouped: dict[str, list[dict[str, str]]] = {}
    invalid_reasons: Counter[str] = Counter()

    with path.open(encoding="utf-8-sig", newline="") as file:
        for line_number, row in enumerate(csv.DictReader(file), start=2):
            try:
                normalized = normalize_geolonia_row(row)
                grouped.setdefault(normalized["municipality_code"], []).append(normalized)
            except ValueError as exc:
                record_invalid_row(
                    invalid_reasons,
                    "municipality",
                    line_number,
                    str(exc),
                )

    rows: list[MunicipalityImportRow] = []
    for municipality_code, municipality_rows in grouped.items():
        latitudes = [float(row["latitude"]) for row in municipality_rows]
        longitudes = [float(row["longitude"]) for row in municipality_rows]
        first = municipality_rows[0]
        rows.append(
            MunicipalityImportRow(
                municipality_code=municipality_code,
                prefecture_name=first["prefecture_name"],
                municipality_name=first["municipality_name"],
                name_kana=first.get("name_kana") or None,
                latitude=fmean(latitudes),
                longitude=fmean(longitudes),
            )
        )

    log_invalid_summary("municipality", invalid_reasons)
    return rows


def normalize_geolonia_row(row: dict[str, str]) -> dict[str, str]:
    municipality_code = first_present(row, "市区町村コード", "city_code")
    prefecture_name = first_present(row, "都道府県名", "prefecture_name")
    municipality_name = first_present(row, "市区町村名", "city_name")
    name_kana = first_present(row, "市区町村名カナ", "city_name_kana", required=False)
    latitude = first_present(row, "緯度（代表点）", "緯度", "latitude", "lat")
    longitude = first_present(row, "経度（代表点）", "経度", "longitude", "lng")

    float(latitude)
    float(longitude)
    if not municipality_code or not prefecture_name or not municipality_name:
        raise ValueError("missing municipality identity")

    return {
        "municipality_code": municipality_code,
        "prefecture_name": prefecture_name,
        "municipality_name": municipality_name,
        "name_kana": name_kana,
        "latitude": latitude,
        "longitude": longitude,
    }


def load_line_names(path: Path) -> dict[str, str]:
    line_names: dict[str, str] = {}
    with path.open(encoding="utf-8-sig", newline="") as file:
        for row in csv.DictReader(file):
            line_code = first_present(row, "line_cd", "路線コード", required=False)
            line_name = first_present(row, "line_name", "路線名", required=False)
            if line_code and line_name:
                line_names[line_code] = line_name
    return line_names


def load_stations(path: Path, line_names: dict[str, str]) -> list[StationImportRow]:
    grouped: dict[str, list[StationImportRow]] = {}
    invalid_reasons: Counter[str] = Counter()

    with path.open(encoding="utf-8-sig", newline="") as file:
        for line_number, row in enumerate(csv.DictReader(file), start=2):
            try:
                station = normalize_station_row(row, line_names)
                grouping_key = station.station_group_code or station.station_code
                grouped.setdefault(grouping_key, []).append(station)
            except ValueError as exc:
                record_invalid_row(invalid_reasons, "station", line_number, str(exc))

    rows = [merge_station_group(stations) for stations in grouped.values()]
    log_invalid_summary("station", invalid_reasons)
    return rows


def normalize_station_row(
    row: dict[str, str],
    line_names: dict[str, str],
) -> StationImportRow:
    status = first_present(row, "e_status", "状態", required=False)
    if status and status != "0":
        raise ValueError("station is not active")

    station_code = first_present(row, "station_cd", "駅コード")
    station_group_code = first_present(row, "station_g_cd", "駅グループコード", required=False)
    station_name = first_present(row, "station_name", "駅名称", "駅名")
    name_kana = first_present(row, "station_name_k", "駅名称(カナ)", "駅名カナ", required=False)
    pref_code = first_present(row, "pref_cd", "都道府県コード", required=False)
    address = first_present(row, "add", "address", "住所", required=False)
    line_code = first_present(row, "line_cd", "路線コード", required=False)
    latitude = first_present(row, "lat", "緯度")
    longitude = first_present(row, "lon", "経度")

    float(latitude)
    float(longitude)
    prefecture_name = PREFECTURE_BY_CODE.get(pref_code) if pref_code else None
    address_prefecture, municipality_name = split_prefecture_municipality(address)
    prefecture_name = prefecture_name or address_prefecture
    if not prefecture_name:
        raise ValueError("missing prefecture")

    return StationImportRow(
        station_code=station_code,
        station_group_code=station_group_code or None,
        station_name=append_station_suffix(station_name),
        name_kana=name_kana or None,
        prefecture_name=prefecture_name,
        municipality_name=municipality_name,
        latitude=float(latitude),
        longitude=float(longitude),
        line_name=line_names.get(line_code),
    )


def merge_station_group(stations: list[StationImportRow]) -> StationImportRow:
    representative = sorted(stations, key=lambda station: station.station_code)[0]
    line_names = sorted(
        {
            station.line_name
            for station in stations
            if station.line_name and station.line_name.strip()
        }
    )
    return StationImportRow(
        station_code=representative.station_code,
        station_group_code=representative.station_group_code,
        station_name=representative.station_name,
        name_kana=representative.name_kana,
        prefecture_name=representative.prefecture_name,
        municipality_name=representative.municipality_name,
        latitude=fmean(station.latitude for station in stations),
        longitude=fmean(station.longitude for station in stations),
        line_name=" / ".join(line_names) if line_names else representative.line_name,
    )


def upsert_municipalities(
    db: Session,
    rows: list[MunicipalityImportRow],
) -> int:
    location_ids = [f"municipality:{row.municipality_code}" for row in rows]
    existing_locations = {
        location.id: location
        for location in db.scalars(
            select(Location).where(Location.id.in_(location_ids))
        )
    }
    existing_municipalities = {
        municipality.location_id: municipality
        for municipality in db.scalars(
            select(MunicipalityLocation).where(
                MunicipalityLocation.location_id.in_(location_ids)
            )
        )
    }

    count = 0
    for row in rows:
        location_id = f"municipality:{row.municipality_code}"
        location = existing_locations.get(location_id)
        if location is None:
            location = Location(
                id=location_id,
                location_type=LOCATION_TYPE_MUNICIPALITY,
                source=LOCATION_SOURCE_GEOLONIA,
            )
            existing_locations[location_id] = location
            db.add(location)

        location.name = row.municipality_name
        location.name_kana = row.name_kana
        location.normalized_name = normalize_location_query(row.municipality_name)
        location.normalized_kana = normalize_location_query(row.name_kana or "")
        location.display_name = f"{row.prefecture_name}{row.municipality_name}"
        location.prefecture_name = row.prefecture_name
        location.municipality_name = row.municipality_name
        location.latitude = row.latitude
        location.longitude = row.longitude
        location.source = LOCATION_SOURCE_GEOLONIA

        municipality = existing_municipalities.get(location_id)
        if municipality is None:
            municipality = MunicipalityLocation(
                location_id=location_id,
                municipality_code=row.municipality_code,
            )
            existing_municipalities[location_id] = municipality
            db.add(municipality)
        else:
            municipality.municipality_code = row.municipality_code
        count += 1

    db.flush()
    return count


def upsert_stations(db: Session, rows: list[StationImportRow]) -> int:
    location_ids = [
        f"station:{row.station_group_code or row.station_code}" for row in rows
    ]
    existing_locations = {
        location.id: location
        for location in db.scalars(
            select(Location).where(Location.id.in_(location_ids))
        )
    }
    existing_stations = {
        station.location_id: station
        for station in db.scalars(
            select(StationLocation).where(StationLocation.location_id.in_(location_ids))
        )
    }

    count = 0
    for row in rows:
        location_id = f"station:{row.station_group_code or row.station_code}"
        location = existing_locations.get(location_id)
        if location is None:
            location = Location(
                id=location_id,
                location_type=LOCATION_TYPE_STATION,
                source=LOCATION_SOURCE_EKIDATA,
            )
            existing_locations[location_id] = location
            db.add(location)

        municipality = row.municipality_name or ""
        location.name = row.station_name
        location.name_kana = row.name_kana
        location.normalized_name = normalize_location_query(row.station_name)
        location.normalized_kana = normalize_location_query(row.name_kana or "")
        location.display_name = f"{row.station_name}・{row.prefecture_name}{municipality}"
        location.prefecture_name = row.prefecture_name
        location.municipality_name = row.municipality_name
        location.latitude = row.latitude
        location.longitude = row.longitude
        location.source = LOCATION_SOURCE_EKIDATA

        station = existing_stations.get(location_id)
        if station is None:
            station = StationLocation(
                location_id=location_id,
                station_code=row.station_code,
            )
            existing_stations[location_id] = station
            db.add(station)

        station.station_group_code = row.station_group_code
        station.station_code = row.station_code
        station.line_name = row.line_name
        count += 1

    db.flush()
    return count


def record_invalid_row(
    invalid_reasons: Counter[str],
    row_type: str,
    line_number: int,
    reason: str,
) -> None:
    invalid_reasons[reason] += 1
    if sum(invalid_reasons.values()) <= INVALID_ROW_LOG_LIMIT:
        LOGGER.warning("invalid %s row %s: %s", row_type, line_number, reason)


def log_invalid_summary(row_type: str, invalid_reasons: Counter[str]) -> None:
    invalid_count = sum(invalid_reasons.values())
    LOGGER.info("invalid %s rows skipped: %s", row_type, invalid_count)
    if invalid_count <= INVALID_ROW_LOG_LIMIT:
        return

    LOGGER.warning(
        "invalid %s row log truncated after %s rows",
        row_type,
        INVALID_ROW_LOG_LIMIT,
    )
    for reason, count in invalid_reasons.most_common():
        LOGGER.warning("invalid %s rows by reason: %s -> %s", row_type, reason, count)


def first_present(
    row: dict[str, str],
    *names: str,
    required: bool = True,
) -> str:
    for name in names:
        value = row.get(name)
        if value is not None and value.strip():
            return value.strip()

    if required:
        raise ValueError(f"missing field: {'/'.join(names)}")
    return ""


def append_station_suffix(station_name: str) -> str:
    if "駅" in station_name:
        return station_name
    return f"{station_name}駅"


def split_prefecture_municipality(address: str) -> tuple[str | None, str | None]:
    prefecture_name = next(
        (prefecture for prefecture in PREFECTURES if address.startswith(prefecture)),
        None,
    )
    rest = address.removeprefix(prefecture_name) if prefecture_name else address

    city_index = rest.find("市")
    if city_index >= 0:
        after_city = rest[city_index + 1 :]
        ward_index = after_city.find("区")
        if 0 <= ward_index <= 8:
            return prefecture_name, rest[: city_index + ward_index + 2]
        return prefecture_name, rest[: city_index + 1]

    for marker in ("区", "町", "村"):
        index = rest.find(marker)
        if index >= 0:
            return prefecture_name, rest[: index + 1]

    return prefecture_name, None


if __name__ == "__main__":
    raise SystemExit(main())
