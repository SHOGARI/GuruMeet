import unittest

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.models.location import (
    LOCATION_SOURCE_EKIDATA,
    LOCATION_SOURCE_GEOLONIA,
    Location,
    MunicipalityLocation,
    StationLocation,
)
from scripts.import_locations import normalize_geolonia_row
from app.services.location_normalizer import normalize_location_query
from app.services.location_service import (
    MAX_LOCATION_SEARCH_LIMIT,
    InvalidLocationIdError,
    LocationService,
)


class LocationSearchServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        engine = create_engine("sqlite+pysqlite:///:memory:")
        Location.__table__.create(engine)
        MunicipalityLocation.__table__.create(engine)
        StationLocation.__table__.create(engine)
        self.SessionLocal = sessionmaker(
            bind=engine,
            class_=Session,
            autoflush=False,
            expire_on_commit=False,
        )
        self.db = self.SessionLocal()
        self._seed()

    def tearDown(self) -> None:
        self.db.close()

    def test_search_station_by_kanji(self) -> None:
        results = LocationService(self.db).search("北千住")

        self.assertEqual(results[0].id, "station:1132005")
        self.assertEqual(results[0].type, "station")

    def test_search_station_by_hiragana(self) -> None:
        results = LocationService(self.db).search("きたせんじゅ")

        self.assertEqual(results[0].id, "station:1132005")

    def test_search_municipality(self) -> None:
        results = LocationService(self.db).search("足立")

        self.assertIn("municipality:13121", [result.id for result in results])

    def test_same_station_names_can_be_distinguished(self) -> None:
        results = LocationService(self.db).search("高田")
        station_results = [result for result in results if result.type == "station"]

        self.assertEqual(
            [result.id for result in station_results],
            ["station:9950101", "station:1163401"],
        )
        self.assertNotEqual(
            station_results[0].municipality,
            station_results[1].municipality,
        )
        self.assertNotEqual(station_results[0].lineName, station_results[1].lineName)

    def test_search_can_filter_by_prefecture(self) -> None:
        results = LocationService(self.db).search("高田", prefecture="神奈川県")

        self.assertEqual([result.id for result in results], ["station:9950101"])

    def test_list_by_prefecture_returns_candidates_without_coordinates(self) -> None:
        results = LocationService(self.db).list_by_prefecture("東京都")

        self.assertEqual(
            [result.id for result in results],
            ["station:1132005", "municipality:13121"],
        )
        self.assertEqual(results[0].kana, "キタセンジュ")
        self.assertEqual(results[0].lineName, "JR常磐線 / 東京メトロ千代田線")

    def test_blank_query_does_not_return_all_rows(self) -> None:
        self.assertEqual(LocationService(self.db).search("   "), [])

    def test_invalid_location_id_is_rejected(self) -> None:
        with self.assertRaises(InvalidLocationIdError):
            LocationService(self.db).validate_location_id("station:")

        with self.assertRaises(InvalidLocationIdError):
            LocationService(self.db).validate_location_id("station:does-not-exist")

    def test_sql_injection_like_query_is_handled_as_plain_text(self) -> None:
        results = LocationService(self.db).search("' OR 1=1 --")

        self.assertEqual(results, [])

    def test_limit_is_capped(self) -> None:
        results = LocationService(self.db).search(
            "駅",
            limit=MAX_LOCATION_SEARCH_LIMIT + 100,
        )

        self.assertLessEqual(len(results), MAX_LOCATION_SEARCH_LIMIT)

    def test_query_normalization_handles_width_and_kana(self) -> None:
        self.assertEqual(
            normalize_location_query(" ｷﾀｾﾝｼﾞｭ "),
            normalize_location_query("きたせんじゅ"),
        )

    def test_geolonia_row_accepts_latest_csv_coordinate_columns(self) -> None:
        row = normalize_geolonia_row(
            {
                "市区町村コード": "13121",
                "都道府県名": "東京都",
                "市区町村名": "足立区",
                "市区町村名カナ": "アダチク",
                "緯度": "35.7757",
                "経度": "139.8048",
            }
        )

        self.assertEqual(row["municipality_code"], "13121")
        self.assertEqual(row["latitude"], "35.7757")

    def _seed(self) -> None:
        self.db.add_all(
            [
                Location(
                    id="station:1132005",
                    location_type="station",
                    name="北千住駅",
                    name_kana="キタセンジュ",
                    normalized_name=normalize_location_query("北千住駅"),
                    normalized_kana=normalize_location_query("キタセンジュ"),
                    display_name="北千住駅・東京都足立区",
                    prefecture_name="東京都",
                    municipality_name="足立区",
                    latitude=35.7494,
                    longitude=139.805,
                    source=LOCATION_SOURCE_EKIDATA,
                    station=StationLocation(
                        station_code="1132005",
                        station_group_code="1132005",
                        line_name="JR常磐線 / 東京メトロ千代田線",
                    ),
                ),
                Location(
                    id="municipality:13121",
                    location_type="municipality",
                    name="足立区",
                    name_kana="アダチク",
                    normalized_name=normalize_location_query("足立区"),
                    normalized_kana=normalize_location_query("アダチク"),
                    display_name="東京都足立区",
                    prefecture_name="東京都",
                    municipality_name="足立区",
                    latitude=35.7757,
                    longitude=139.8048,
                    source=LOCATION_SOURCE_GEOLONIA,
                    municipality=MunicipalityLocation(municipality_code="13121"),
                ),
                Location(
                    id="station:9950101",
                    location_type="station",
                    name="高田駅",
                    name_kana="タカタ",
                    normalized_name=normalize_location_query("高田駅"),
                    normalized_kana=normalize_location_query("タカタ"),
                    display_name="高田駅・神奈川県横浜市港北区",
                    prefecture_name="神奈川県",
                    municipality_name="横浜市港北区",
                    latitude=35.549,
                    longitude=139.62,
                    source=LOCATION_SOURCE_EKIDATA,
                    station=StationLocation(
                        station_code="9950101",
                        station_group_code="9950101",
                        line_name="横浜市営地下鉄グリーンライン",
                    ),
                ),
                Location(
                    id="station:1163401",
                    location_type="station",
                    name="高田駅",
                    name_kana="タカダ",
                    normalized_name=normalize_location_query("高田駅"),
                    normalized_kana=normalize_location_query("タカダ"),
                    display_name="高田駅・奈良県大和高田市",
                    prefecture_name="奈良県",
                    municipality_name="大和高田市",
                    latitude=34.516,
                    longitude=135.742,
                    source=LOCATION_SOURCE_EKIDATA,
                    station=StationLocation(
                        station_code="1163401",
                        station_group_code="1163401",
                        line_name="JR和歌山線",
                    ),
                ),
            ]
        )
        self.db.commit()


if __name__ == "__main__":
    unittest.main()
