# Location Tables

地点検索で使うマスタテーブル。

## municipalities

市区町村の元データ。

| column | description |
| --- | --- |
| `id` | 内部ID |
| `municipality_code` | 市区町村コード |
| `prefecture_name` | 都道府県名 |
| `municipality_name` | 市区町村名 |
| `name_kana` | 市区町村名カナ |
| `latitude` | 代表緯度 |
| `longitude` | 代表経度 |

## stations

駅の元データ。駅グループコードがある場合は import 時に1件へまとめる。

| column | description |
| --- | --- |
| `id` | 内部ID |
| `station_code` | 駅コード |
| `station_group_code` | 駅グループコード |
| `station_name` | 駅名 |
| `name_kana` | 駅名カナ |
| `prefecture_name` | 都道府県名 |
| `municipality_name` | 市区町村名 |
| `latitude` | 緯度 |
| `longitude` | 経度 |
| `line_name` | 路線名。複数路線の場合は `/` 区切り |

## location_search

市区町村と駅を統合した検索用テーブル。

| column | description |
| --- | --- |
| `id` | `municipality:{code}` または `station:{code}` |
| `location_type` | `municipality` / `station` |
| `source_id` | 元テーブルの内部ID |
| `name` | 表示名 |
| `name_kana` | 読み |
| `normalized_name` | 検索用に正規化した名称 |
| `normalized_kana` | 検索用に正規化した読み |
| `display_name` | 候補表示用の名称 |
| `prefecture_name` | 都道府県名 |
| `municipality_name` | 市区町村名 |
| `latitude` | 緯度 |
| `longitude` | 経度 |
| `municipality_code` | 市区町村コード |
| `station_code` | 駅コード |
| `station_group_code` | 駅グループコード |
| `line_name` | 路線名 |
