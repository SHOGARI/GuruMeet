# Location API

市区町村と駅を同じ候補一覧として扱うAPI。

DBでは共通項目を `locations` に保持し、種別ごとの固有項目を
`municipality_locations` / `station_locations` に分ける。
選択後の処理では `id` の prefix で市区町村と駅を分ける。

```text
municipality:13121
station:1132005
```

## GET /locations

都道府県を指定して、その都道府県内の市区町村・駅候補を一括取得する。
フロントエンドはこのレスポンスを保持し、入力中の候補絞り込みはローカルで行う。

```http
GET /locations?prefecture=東京都
```

レスポンスには候補表示と選択ID保持に必要な項目だけを返す。
緯度経度は返さず、Hot Pepper API連携などの後続処理では
backendが `location_id` からDBを引いて解決する。
現在地検索はこのAPIとは別物として扱い、frontendが取得した緯度経度を
`POST /temporary-groups` の `custom_location` として送る。

レスポンス:

```json
[
  {
    "id": "station:1132005",
    "type": "station",
    "name": "北千住駅",
    "kana": "キタセンジュ",
    "displayName": "北千住駅・東京都足立区",
    "prefecture": "東京都",
    "municipality": "足立区",
    "lineName": "JR常磐線 / 東京メトロ千代田線"
  },
  {
    "id": "municipality:13121",
    "type": "municipality",
    "name": "足立区",
    "kana": "アダチク",
    "displayName": "東京都足立区",
    "prefecture": "東京都",
    "municipality": "足立区",
    "lineName": null
  }
]
```

## GET /locations/search

```http
GET /locations/search?q=北千住&limit=20
```

backend側で直接検索するためのAPI。県別候補を一括取得するUIでは、
基本的に `GET /locations?prefecture=東京都` を使い、入力絞り込みは
frontend側で行う。

都道府県を先に選択してからbackend検索する場合は、`prefecture` を指定して候補を絞る。

```http
GET /locations/search?prefecture=東京都&q=北千住&limit=20
```

`q` は前後空白、全角半角、ひらがな・カタカナ差を正規化して検索する。空文字では全件を返さない。

`limit` は最大50件に制限する。

レスポンス:

```json
[
  {
    "id": "station:1132005",
    "type": "station",
    "name": "北千住駅",
    "displayName": "北千住駅・東京都足立区",
    "prefecture": "東京都",
    "municipality": "足立区",
    "latitude": 35.7494,
    "longitude": 139.805,
    "lineName": "JR常磐線 / 東京メトロ千代田線"
  },
  {
    "id": "municipality:13121",
    "type": "municipality",
    "name": "足立区",
    "displayName": "東京都足立区",
    "prefecture": "東京都",
    "municipality": "足立区",
    "latitude": 35.7757,
    "longitude": 139.8048,
    "lineName": null
  }
]
```

## GET /locations/{location_id}

地点IDが存在するか確認する。存在する場合は204、形式不正または未登録の場合は404。

## 選択後の扱い

一時グループ作成時は、検索欄の表示名だけでなく `location_id` を送る。

```json
{
  "location": "北千住駅・東京都足立区",
  "location_id": "station:1132005"
}
```

駅:

```json
{
  "locationId": "station:1132005",
  "radiusMeters": 1000
}
```

市区町村:

```json
{
  "locationId": "municipality:13121"
}
```

市区町村は市区町村コードによる区域検索を基本にする。外部APIが区域検索に対応しない場合は、代表座標と半径検索に fallback できるようにする。

現行の Hot Pepper 連携では市区町村コードによる区域検索ができないため、
`temporary_groups.location_id` から `locations` と子テーブルを引き、代表座標から
半径検索を使う。駅と市区町村の半径は設定値で分ける。

現在地から入力した場合は `location_id` を送らない。
`POST /temporary-groups` に `custom_location` を送り、backendが
`custom_locations` に保存した緯度経度を検索原点にする。
