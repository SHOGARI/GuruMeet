# Location API

市区町村と駅を同じ候補一覧として検索するAPI。

元データは `municipalities` と `stations` に分けて保持し、検索用に `location_search` へ統合する。選択後の処理では `id` の prefix で市区町村と駅を分ける。

```text
municipality:13121
station:1132005
```

## GET /locations/search

```http
GET /locations/search?q=北千住&limit=20
```

都道府県を先に選択してから地点候補を検索するUIでは、`prefecture` を指定して候補を絞る。

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
`temporary_groups.location_municipality_code` にコードを保存しつつ、代表座標から
3,000m の半径検索を使う。駅は代表座標から 1,000m の半径検索を使う。
