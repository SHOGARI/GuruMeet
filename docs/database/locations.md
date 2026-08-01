# Location Tables

地点検索で使うマスタテーブル。

市区町村と駅は、共通項目を `locations` に持ち、種別ごとの固有項目を
`municipality_locations` / `station_locations` に分ける。
現在地や地図ピンのようなユーザー固有の座標は `locations` には登録せず、
[`custom_locations`](./custom-locations.md) に保存する。

## locations

地点の親テーブル。駅・市区町村の候補を選択した一時グループは、この `id` を保持する。

| column | type | null | description |
| --- | --- | --- | --- |
| `id` | `VARCHAR(40)` | no | `municipality:{code}` または `station:{code}`。主キー。 |
| `location_type` | `VARCHAR(32)` | no | `municipality` / `station`。CHECK制約あり。 |
| `name` | `VARCHAR(128)` | no | 駅名または市区町村名。 |
| `name_kana` | `VARCHAR(128)` | yes | 読み仮名。検索補助用。 |
| `normalized_name` | `VARCHAR(128)` | no | 検索用に正規化した名称。 |
| `normalized_kana` | `VARCHAR(128)` | yes | 検索用に正規化した読み。 |
| `display_name` | `VARCHAR(255)` | no | 候補表示用の名称。 |
| `prefecture_name` | `VARCHAR(32)` | no | 都道府県名。 |
| `municipality_name` | `VARCHAR(64)` | yes | 市区町村名。 |
| `latitude` | `FLOAT` | no | 緯度。 |
| `longitude` | `FLOAT` | no | 経度。 |
| `source` | `VARCHAR(32)` | no | `geolonia` / `ekidata`。 |
| `source_updated_at` | `TIMESTAMP WITH TIME ZONE` | yes | 元データ更新日時。 |

## municipality_locations

市区町村の固有情報。

| column | type | null | description |
| --- | --- | --- | --- |
| `location_id` | `VARCHAR(40)` | no | `locations.id` へのFK兼主キー。親削除時CASCADE。 |
| `municipality_code` | `VARCHAR(16)` | no | uniqueな市区町村コード。 |

## station_locations

駅の固有情報。

| column | type | null | description |
| --- | --- | --- | --- |
| `location_id` | `VARCHAR(40)` | no | `locations.id` へのFK兼主キー。親削除時CASCADE。 |
| `station_code` | `VARCHAR(16)` | no | uniqueな駅コード。 |
| `station_group_code` | `VARCHAR(16)` | yes | 路線違いの同一駅を束ねるコード。 |
| `line_name` | `VARCHAR(128)` | yes | 路線名。複数路線の場合は `/` 区切り。 |

## Indexes

検索用indexは `locations.location_type`、`prefecture_name`、
`normalized_name`、`normalized_kana` に設定する。子テーブルは
`municipality_code`、`station_code`、`station_group_code` にindexを持つ。

## temporary_groups への保存

地点候補を選択してグループを作成した場合、`temporary_groups.location_id` に
`locations.id` を保存する。

Hot Pepper検索に必要な地点種別、緯度経度、市区町村コード、駅コードは、
backendが `location_id` から `locations` と子テーブルを引いて解決する。

現在地から入力した場合は `locations` を使わない。
backendはリクエストの緯度経度を `custom_locations` に保存し、
`temporary_groups.custom_location_id` から検索原点を解決する。
