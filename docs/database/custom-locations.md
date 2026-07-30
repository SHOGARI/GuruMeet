# custom_locations

現在地や地図ピンなど、地点マスタに登録しない検索原点を保存するテーブル。

`locations` は駅・市区町村のマスタとして扱い、`custom_locations` は一時グループ作成時に発生するユーザー固有の座標として扱う。Hot Pepper検索では、ここに保存した緯度経度をそのまま検索原点にする。

| column | type | null | description |
| --- | --- | --- | --- |
| `id` | `UUID` | no | 検索原点の識別子。backend側で `uuid4` を生成する。 |
| `display_name` | `VARCHAR(255)` | no | 画面表示用の場所名。例: `東京都新宿区付近`。 |
| `prefecture_name` | `VARCHAR(32)` | yes | 逆ジオコーディングなどで取得できた都道府県名。検索には使わない。 |
| `latitude` | `FLOAT` | no | 緯度。 |
| `longitude` | `FLOAT` | no | 経度。 |
| `accuracy_meters` | `FLOAT` | yes | 端末の現在地取得精度。取得できる場合だけ保存する。 |
| `source` | `VARCHAR(32)` | no | `current_location` / `map_pin` のいずれか。 |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | no | DB側の `now()` で作成日時を保存する。 |
| `expires_at` | `TIMESTAMP WITH TIME ZONE` | yes | 関連する一時グループと同じ期限。期限切れ削除の対象。 |

## Constraints and Indexes

| name | target | purpose |
| --- | --- | --- |
| primary key | `id` | UUIDで一意に取得する。 |
| `ck_custom_locations_source` | `source` | 検索原点の発生元を許可値に限定する。 |
| `ix_custom_locations_expires_at` | `expires_at` | 期限切れ削除用。 |

## temporary_groups との関係

現在地から一時グループを作成した場合、backendは `custom_locations` を作成し、
`temporary_groups.custom_location_id` にそのIDを保存する。

地点候補を選択した場合は `temporary_groups.location_id` を使うため、
`custom_locations` は作成しない。

| input | temporary_groups.location_id | temporary_groups.custom_location_id |
| --- | --- | --- |
| 駅・市区町村の選択 | `locations.id` | null |
| 現在地から入力 | null | `custom_locations.id` |

`custom_locations` はマスタではないため、地点検索APIの候補には出さない。
期限切れの一時グループを削除する cleanup で、未使用になった期限切れ行も削除する。

## Alembic

`custom_locations` は以下のmigrationで作成する。

```text
backend/alembic/versions/202607300002_create_custom_locations.py
```
