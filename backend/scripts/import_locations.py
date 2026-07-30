#!/usr/bin/env python
from __future__ import annotations

import argparse
import csv
import logging
import sys
from dataclasses import dataclass
from pathlib import Path
from statistics import fmean

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.db.database import SessionLocal  # noqa: E402
from app.models.location import (  # noqa: E402
    LOCATION_TYPE_MUNICIPALITY,
    LOCATION_TYPE_STATION,
    LocationSearchEntry,
    Municipality,
    Station,
)
from app.services.location_normalizer import normalize_location_query  # noqa: E402

LOGGER = logging.getLogger("import_locations")

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
        municipality_count = upsert_municipalities(db, municipality_rows)
        station_count = upsert_stations(db, station_rows)
        index_count = rebuild_location_search(db)
        db.commit()

    LOGGER.info("municipalities upserted: %s", municipality_count)
    LOGGER.info("stations upserted: %s", station_count)
    LOGGER.info("location_search rebuilt: %s", index_count)
    return 0


def load_municipalities(path: Path) -> list[MunicipalityImportRow]:
    grouped: dict[str, list[dict[str, str]]] = {}
    invalid_count = 0

    with path.open(encoding="utf-8-sig", newline="") as file:
        for line_number, row in enumerate(csv.DictReader(file), start=2):
            try:
                normalized = normalize_geolonia_row(row)
                grouped.setdefault(normalized["municipality_code"], []).append(normalized)
            except ValueError as exc:
                invalid_count += 1
                LOGGER.warning("invalid municipality row %s: %s", line_number, exc)

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

    LOGGER.info("invalid municipality rows skipped: %s", invalid_count)
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
    invalid_count = 0

    with path.open(encoding="utf-8-sig", newline="") as file:
        for line_number, row in enumerate(csv.DictReader(file), start=2):
            try:
                station = normalize_station_row(row, line_names)
                grouping_key = station.station_group_code or station.station_code
                grouped.setdefault(grouping_key, []).append(station)
            except ValueError as exc:
                invalid_count += 1
                LOGGER.warning("invalid station row %s: %s", line_number, exc)

    rows = [merge_station_group(stations) for stations in grouped.values()]
    LOGGER.info("invalid station rows skipped: %s", invalid_count)
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
    count = 0
    for row in rows:
        municipality = db.scalar(
            select(Municipality).where(
                Municipality.municipality_code == row.municipality_code
            )
        )
        if municipality is None:
            municipality = Municipality(municipality_code=row.municipality_code)
            db.add(municipality)

        municipality.prefecture_name = row.prefecture_name
        municipality.municipality_name = row.municipality_name
        municipality.name_kana = row.name_kana
        municipality.latitude = row.latitude
        municipality.longitude = row.longitude
        count += 1

    db.flush()
    return count


def upsert_stations(db: Session, rows: list[StationImportRow]) -> int:
    count = 0
    for row in rows:
        station = db.scalar(
            select(Station).where(Station.station_code == row.station_code)
        )
        if station is None:
            station = Station(station_code=row.station_code)
            db.add(station)

        station.station_group_code = row.station_group_code
        station.station_name = row.station_name
        station.name_kana = row.name_kana
        station.prefecture_name = row.prefecture_name
        station.municipality_name = row.municipality_name
        station.latitude = row.latitude
        station.longitude = row.longitude
        station.line_name = row.line_name
        count += 1

    db.flush()
    return count


def rebuild_location_search(db: Session) -> int:
    db.execute(delete(LocationSearchEntry))
    count = 0
    location_ids: set[str] = set()

    for municipality in db.scalars(select(Municipality)):
        db.add(
            LocationSearchEntry(
                id=f"municipality:{municipality.municipality_code}",
                location_type=LOCATION_TYPE_MUNICIPALITY,
                source_id=municipality.id,
                name=municipality.municipality_name,
                name_kana=municipality.name_kana,
                normalized_name=normalize_location_query(municipality.municipality_name),
                normalized_kana=normalize_location_query(municipality.name_kana or ""),
                display_name=(
                    f"{municipality.prefecture_name}{municipality.municipality_name}"
                ),
                prefecture_name=municipality.prefecture_name,
                municipality_name=municipality.municipality_name,
                latitude=municipality.latitude,
                longitude=municipality.longitude,
                municipality_code=municipality.municipality_code,
            )
        )
        count += 1

    for station in db.scalars(select(Station)):
        location_id = f"station:{station.station_group_code or station.station_code}"
        if location_id in location_ids:
            LOGGER.warning("duplicate station location id skipped: %s", location_id)
            continue
        location_ids.add(location_id)
        municipality = station.municipality_name or ""
        display_area = f"{station.prefecture_name}{municipality}"
        db.add(
            LocationSearchEntry(
                id=location_id,
                location_type=LOCATION_TYPE_STATION,
                source_id=station.id,
                name=station.station_name,
                name_kana=station.name_kana,
                normalized_name=normalize_location_query(station.station_name),
                normalized_kana=normalize_location_query(station.name_kana or ""),
                display_name=f"{station.station_name}・{display_area}",
                prefecture_name=station.prefecture_name,
                municipality_name=station.municipality_name,
                latitude=station.latitude,
                longitude=station.longitude,
                station_code=station.station_code,
                station_group_code=station.station_group_code,
                line_name=station.line_name,
            )
        )
        count += 1

    db.flush()
    return count


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
