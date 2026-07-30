# Location Tables

地点検索で使うマスタテーブル。

市区町村と駅は、共通項目を `locations` に持ち、種別ごとの固有項目を
`municipality_locations` / `station_locations` に分ける。

## locations

地点の親テーブル。フロントエンドや一時グループは、この `id` を保持する。

| column | description |
| --- | --- |
| `id` | `municipality:{code}` または `station:{code}` |
| `location_type` | `municipality` / `station` |
| `name` | 駅名または市区町村名 |
| `name_kana` | 読み仮名。検索補助用 |
| `normalized_name` | 検索用に正規化した名称 |
| `normalized_kana` | 検索用に正規化した読み |
| `display_name` | 候補表示用の名称 |
| `prefecture_name` | 都道府県名 |
| `municipality_name` | 市区町村名 |
| `latitude` | 緯度 |
| `longitude` | 経度 |
| `source` | `geolonia` / `ekidata` |
| `source_updated_at` | 元データ更新日時。取得できる場合だけ入れる |

## municipality_locations

市区町村の固有情報。

| column | description |
| --- | --- |
| `location_id` | `locations.id` へのFK |
| `municipality_code` | 市区町村コード |

## station_locations

駅の固有情報。

| column | description |
| --- | --- |
| `location_id` | `locations.id` へのFK |
| `station_code` | 駅コード |
| `station_group_code` | 駅グループコード |
| `line_name` | 路線名。複数路線の場合は `/` 区切り |

## temporary_groups への保存

地点候補を選択してグループを作成した場合、`temporary_groups` には
`location_id` だけを保存する。

Hot Pepper検索に必要な地点種別、緯度経度、市区町村コード、駅コードは、
backendが `location_id` から `locations` と子テーブルを引いて解決する。
