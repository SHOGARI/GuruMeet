# Location Data Versions

地点マスタの取得元、取得日、投入環境、件数を記録する台帳。

CSV本体、有料データ、DB接続文字列、API keyはここに貼らない。
ここには「どのデータを、いつ、どの環境へ入れたか」だけを残す。

## 記録ルール

- staging / productionへ投入したら必ず追記する
- local投入は必要な場合だけ追記する
- Geoloniaは取得URL、取得日、checksumを記録する
- 駅データ.jpは無料/有料の種別、取得日、checksumを記録する
- import scriptを実行したGit commit SHAを記録する
- import後の `locations` 件数、駅件数、市区町村件数、不正行skip件数を記録する
- データを加工した場合は加工内容を書く

checksumの取得例:

```sh
shasum -a 256 backend/data/location-master/geolonia/latest.csv
shasum -a 256 backend/data/location-master/ekidata/station.csv
shasum -a 256 backend/data/location-master/ekidata/line.csv
```

件数確認SQL:

```sql
select location_type, count(*)
from locations
group by location_type
order by location_type;

select count(*) from municipality_locations;
select count(*) from station_locations;
```

## Current Production

| item | value |
| --- | --- |
| environment | production |
| status | not recorded |
| last_imported_at | - |
| app_commit_sha | - |
| import_script | `backend/scripts/import_locations.py` |
| Geolonia source URL | https://raw.githubusercontent.com/geolonia/japanese-addresses/master/data/latest.csv |
| Geolonia retrieved_at | - |
| Geolonia checksum | - |
| Ekidata plan | - |
| Ekidata retrieved_at | - |
| station.csv checksum | - |
| line.csv checksum | - |
| locations count | - |
| municipality_locations count | - |
| station_locations count | - |
| invalid municipality rows skipped | - |
| invalid station rows skipped | - |
| notes | - |

## Current Staging

| item | value |
| --- | --- |
| environment | staging |
| status | not recorded |
| last_imported_at | - |
| app_commit_sha | - |
| import_script | `backend/scripts/import_locations.py` |
| Geolonia source URL | https://raw.githubusercontent.com/geolonia/japanese-addresses/master/data/latest.csv |
| Geolonia retrieved_at | - |
| Geolonia checksum | - |
| Ekidata plan | - |
| Ekidata retrieved_at | - |
| station.csv checksum | - |
| line.csv checksum | - |
| locations count | - |
| municipality_locations count | - |
| station_locations count | - |
| invalid municipality rows skipped | - |
| invalid station rows skipped | - |
| notes | - |

## Import History

新しい投入を上に追記する。

### YYYY-MM-DD production

| item | value |
| --- | --- |
| environment | production |
| imported_at | YYYY-MM-DD HH:MM JST |
| operator | - |
| app_commit_sha | - |
| Geolonia retrieved_at | YYYY-MM-DD |
| Geolonia checksum | - |
| Ekidata plan | free / paid |
| Ekidata retrieved_at | YYYY-MM-DD |
| station.csv checksum | - |
| line.csv checksum | - |
| import command | `docker compose run --rm --no-deps ...` |
| locations count | - |
| municipality_locations count | - |
| station_locations count | - |
| invalid municipality rows skipped | - |
| invalid station rows skipped | - |
| data processing notes | Geolonia住所データを市区町村コード単位に集約。駅データは駅グループコード単位に集約。 |
| verification | `/api/locations?prefecture=東京都` で候補返却を確認 |
| rollback note | - |

### YYYY-MM-DD staging

| item | value |
| --- | --- |
| environment | staging |
| imported_at | YYYY-MM-DD HH:MM JST |
| operator | - |
| app_commit_sha | - |
| Geolonia retrieved_at | YYYY-MM-DD |
| Geolonia checksum | - |
| Ekidata plan | free / paid |
| Ekidata retrieved_at | YYYY-MM-DD |
| station.csv checksum | - |
| line.csv checksum | - |
| import command | `docker compose run --rm --no-deps ...` |
| locations count | - |
| municipality_locations count | - |
| station_locations count | - |
| invalid municipality rows skipped | - |
| invalid station rows skipped | - |
| data processing notes | Geolonia住所データを市区町村コード単位に集約。駅データは駅グループコード単位に集約。 |
| verification | `/api/locations?prefecture=東京都` で候補返却を確認 |
| rollback note | - |
