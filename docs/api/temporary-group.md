# Temporary Group API

一時グループの作成、参加、解散、投票、店舗決定を扱うAPI。

backendは共有URLを作らない。frontendが返却された `id` を使って
`/#/join/{id}` を組み立てる。

## Frontend Usage

frontendは初回アクセス時に匿名参加者トークンを用意する。

```text
participant_token = crypto.randomUUID()
```

同じ値をlocalStorageとcookieに保存する。

```text
localStorage:
  gurumeet_participant_token

cookie:
  gurumeet_participant_token
```

起動時はlocalStorageとcookieのどちらかに値があれば復元し、両方なければ新規生成する。backendには `participant_token` を送る。backendは生の値を保存せず、hash化して `anonymous_users.participant_token_hash` に保存する。

グループ作成時に作成者も参加者として登録する場合:

```text
POST /temporary-groups
  participant_token を含める
```

共有URLから参加する場合:

```text
POST /temporary-groups/{group_id}/participants
  participant_token を含める
```

手入力コードから参加する場合:

```text
POST /temporary-groups/join
  code と participant_token を含める
```

人数表示で上限人数まで必要な画面は、詳細取得レスポンスの `joined_participant_count` と `participant_count` を使う。

```text
2 / 4人
```

`is_full` はDBカラムではなくAPI側の計算結果。新規参加者が満員グループへ参加しようとした場合は409を返す。同じ `participant_token` の既存参加者は再実行しても人数を増やさず、既存参加として扱う。

## 設計理由

一時グループには `id` と `code` の2つの識別子を持たせる。

| field | 用途 | 理由 |
| --- | --- | --- |
| `id` | URL共有用 | UUID v4で推測困難。SNS共有やブラウザ遷移など、クリック参加の主導線に使う。 |
| `code` | 手入力参加用 | 5桁で入力しやすい。URLを開けない場面や口頭共有の補助導線に使う。 |

5桁コードだけに寄せない理由は、手入力用コードは短く、総当たりされる前提で扱う必要があるため。

`ABCDEFGHJKLMNPQRSTUVWXYZ23456789` は32文字なので、5桁コードの総数は以下。

```text
32^5 = 33,554,432
```

4桁よりは安全だが、URL共有用の識別子としてはUUIDほど強くない。  
そのため、URL共有はUUID、手入力は5桁コードに分ける。

```text
URL共有:
/#/join/{id}

手入力参加:
A7K2F
```

レート制限は参加系APIに適用する。UUID URLは推測困難な主導線として扱い、5桁コードは総当たり対策つきの補助導線として扱う。

## POST /temporary-groups

一時グループを作成する。

### Why

グループ作成時点でUUIDと5桁コードを同時に発行する。  
同じ一時グループに2つの参加導線を紐づけるため、frontend側で別々の発行APIを呼ばせない。

backendは共有URLを返さない。共有URLはfrontendのroute設計に依存するため、backendは `id` と `code` の発行に責務を絞る。

`location_id` が指定されている場合は、backendが地点マスタから緯度経度を解決する。
`custom_location` が指定されている場合は、現在地や地図ピンの緯度経度を
`custom_locations` に保存し、その座標を検索原点にする。
どちらの場合も作成時にHot Pepper APIで店舗候補を半径検索して
`temporary_groups.restaurant` に保存する。
frontendは作成後に検索APIを実行せず、必要な表示データを
`GET /temporary-groups/{group_id}` で取得する。検索状態は
`restaurant_search_status` に保存する。

### Request

bodyなしでも作成可能。

```json
{}
```

選択場所から作成する場合:

```json
{
  "participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a",
  "creator_id": "user_123",
  "participant_count": 4,
  "location": "渋谷駅・東京都渋谷区",
  "location_id": "station:1130205",
  "budget_min": 2000,
  "budget_max": 3000
}
```

現在地から作成する場合:

```json
{
  "participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a",
  "participant_count": 4,
  "location": "東京都新宿区付近",
  "custom_location": {
    "display_name": "東京都新宿区付近",
    "prefecture_name": "東京都",
    "latitude": 35.6895,
    "longitude": 139.6917,
    "accuracy_meters": 24.5,
    "source": "current_location"
  },
  "budget_min": 2000,
  "budget_max": 3000
}
```

`location_id` と `custom_location` は同時に指定できない。

### Processing

1. `id` にUUID v4を発行する。
2. `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` から5文字の `code` を生成する。
3. リクエストに希望条件があれば保存する。
4. `location_id` があれば、地点マスタの緯度経度と設定値の半径でHot Pepper APIを検索する。
5. `custom_location` があれば、`custom_locations` に保存した緯度経度と設定値の半径でHot Pepper APIを検索する。
6. 検索結果を `restaurant` に保存し、`restaurant_search_status` を更新する。
7. `participant_token` があれば作成者を参加者として登録する。`creator_id` が未指定なら、作成した `anonymous_user_id` の文字列表現を `creator_id` に保存する。
8. `expires_at` に作成時刻 + アプリ設定の一時グループTTLを保存する。
9. `code` のunique制約に衝突した場合はrollbackして再生成する。

`location` だけが指定され、`location_id` も `custom_location` もない場合は400を返す。
自由入力地点によるHot Pepperのkeyword検索は行わない。

作成成功レスポンスは作成結果だけを返す。店舗候補や希望条件は、返却された `id` を使って `GET /temporary-groups/{group_id}` で取得する。

### Response

`201 Created`

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "code": "A7K2F",
  "expires_at": "2026-07-16T12:00:00Z",
  "joined_participant_count": 1,
  "is_full": false,
  "phase": "waiting",
  "restaurant_search_status": "succeeded"
}
```

### Errors

`400 Bad Request`

検索条件が不正な場合。

`503 Service Unavailable`

コード生成が設定回数以内に成功しなかった場合。

`502 Bad Gateway`

Hot Pepper APIとの通信に失敗した場合。

`504 Gateway Timeout`

Hot Pepper APIのリクエストがタイムアウトした場合。

## GET /temporary-groups/{group_id}

UUIDから一時グループを取得する。

### Why

UUID URLから参加する主導線。  
UUIDは推測困難なので、SNS共有やリンク共有ではこのAPIを使う。

存在しないUUIDと期限切れUUIDは同じ404にする。存在確認のための情報を余計に返さないため。

### Processing

1. `group_id` で `temporary_groups.id` を検索する。
2. `expires_at > now` の行だけ有効扱いにする。
3. 存在しない、または期限切れの場合は404を返す。

### Response

`200 OK`

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "code": "A7K2F",
  "expires_at": "2026-07-16T12:00:00Z",
  "joined_participant_count": 2,
  "is_full": false,
  "phase": "waiting",
  "restaurant_search_status": "succeeded",
  "created_at": "2026-07-15T12:00:00Z",
  "voting_started_at": null,
  "voting_completed_at": null,
  "creator_id": "user_123",
  "participant_count": 4,
  "location": "渋谷駅・東京都渋谷区",
  "location_id": "station:1130205",
  "custom_location_id": null,
  "budget_min": 2000,
  "budget_max": 3000,
  "restaurant_search_status": "succeeded",
  "restaurant": {
    "restaurants": [
      {
        "id": "restaurant_123",
        "name": "渋谷ビストロ",
        "address": "東京都渋谷区...",
        "access": "渋谷駅徒歩3分",
        "genre": "ビストロ",
        "budget": "3,000〜5,000円",
        "image_url": "https://example.com/image.jpg",
        "shop_url": "https://example.com/shop"
      }
    ],
    "searched_at": "2026-07-15T12:00:00+00:00"
  }
}
```

### Errors

`404 Not Found`

```json
{
  "detail": "一時グループが存在しない、または期限切れです。"
}
```

## POST /temporary-groups/{group_id}/participants

UUIDから一時グループに参加する。

### Why

共有URLから参加する主導線。frontendはlocalStorageとcookieに保存した同じ `participant_token` を送る。

同じ `participant_token` で再実行した場合は既存参加者として扱い、参加人数を増やさない。

参加成功レスポンスは参加結果だけを返す。店舗候補や希望条件は `GET /temporary-groups/{group_id}` で取得する。

### Request

```json
{
  "participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"
}
```

### Processing

1. `group_id` で有効な一時グループを検索し、行ロックする。
2. `participant_token` をhash化して `anonymous_users` を取得または作成する。
3. 既に `temporary_group_participants` に参加行があれば、人数は増やさず既存参加扱いにする。
4. 未参加の場合は現在参加人数を数える。
5. `participant_count` に達していれば409を返す。
6. 空きがあれば `temporary_group_participants` に参加行を作成する。

### Response

`200 OK`

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "code": "A7K2F",
  "expires_at": "2026-07-16T12:00:00Z",
  "joined_participant_count": 2,
  "is_full": false,
  "phase": "waiting",
  "restaurant_search_status": "succeeded"
}
```

### Errors

`404 Not Found`

```json
{
  "detail": "一時グループが存在しない、または期限切れです。"
}
```

`409 Conflict`

```json
{
  "detail": "一時グループの参加人数が上限に達しています。"
}
```

## POST /temporary-groups/join

5桁コードから一時グループを取得する。

### Why

手入力参加の補助導線。  
5桁コードは入力しやすい一方でUUIDより短く、総当たりの対象になる。そのため、このAPIだけclient IPごとのレート制限をかける。

存在しないコードと期限切れコードは同じ404にする。コードの有効性を推測しやすいレスポンスにしないため。

参加成功レスポンスは参加結果だけを返す。店舗候補や希望条件は、返却された `id` を使って `GET /temporary-groups/{group_id}` で取得する。

### Request

```json
{
  "code": "A7K2F",
  "participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"
}
```

### Processing

1. client IPごとのrate limitを確認する。
2. `code` をuppercaseにして有効な一時グループを検索し、行ロックする。
3. `participant_token` をhash化して `anonymous_users` を取得または作成する。
4. 既に参加済みなら人数を増やさず既存参加扱いにする。
5. 未参加かつ満員なら409を返す。
6. 空きがあれば参加行を作成する。

### Response

`200 OK`

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "code": "A7K2F",
  "expires_at": "2026-07-16T12:00:00Z",
  "joined_participant_count": 2,
  "is_full": false,
  "phase": "waiting",
  "restaurant_search_status": "succeeded"
}
```

### Errors

`404 Not Found`

```json
{
  "detail": "一時グループが存在しない、または期限切れです。"
}
```

`409 Conflict`

```json
{
  "detail": "一時グループの参加人数が上限に達しています。"
}
```

`429 Too Many Requests`

```json
{
  "detail": "参加試行が多すぎます。時間をおいて再試行してください。"
}
```

## 進行状態

`TemporaryGroupResponse.phase` はDBカラムではなく時刻から計算する。

| phase | condition |
| --- | --- |
| `waiting` | `voting_started_at` がnull。 |
| `swiping` | 投票開始済みで `voting_completed_at` がnull。 |
| `result` | `voting_completed_at` が設定済み。 |

## POST /temporary-groups/{group_id}/dissolve

有効なグループを解散する。行はその場で削除せず、`expires_at` を現在時刻へ
更新するため、以後の取得・参加・投票では期限切れとして404になる。

通常は作成時の `participant_token` に対応するホストだけが実行できる。
`creator_id` がnullのグループでは、現行実装は参加者であることだけを確認する。

Request:

```json
{
  "participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"
}
```

主なエラーは、未登録参加者または非ホストの `403`、無効なグループの `404`。

## POST /temporary-groups/{group_id}/voting/start

店舗候補への投票を開始する。グループ参加者であれば実行でき、ホスト限定ではない。
`participant_count` が設定されている場合は、その人数が参加済みになるまで開始できない。
再実行しても最初の `voting_started_at` を保持する。

Request:

```json
{
  "participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a"
}
```

Responseは後述の `TemporaryGroupVotingProgress`。参加予定人数が未達の場合は
`409` を返す。

現行実装では店舗候補が0件でも開始自体は成功し、`candidate_count=0` になる。
ただし投票完了には進めないため、通常フローでは
`restaurant_search_status=succeeded` かつ候補ありのグループだけを開始対象にする。

## POST /temporary-groups/{group_id}/votes

参加者1人の1店舗分の投票を登録する。同じ参加者・店舗への再送は既存行を更新する。
`liked=true` は「食べたい」、`false` は「見送り」。

```json
{
  "participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a",
  "restaurant_id": "restaurant_123",
  "liked": true
}
```

全参加者が全候補へ投票すると `voting_completed_at` を設定する。完了後は、同じ値の
冪等な再送だけ成功し、投票内容の変更は `409` になる。

Response:

```json
{
  "restaurant_id": "restaurant_123",
  "liked": true,
  "progress": {
    "voting_started_at": "2026-08-01T10:00:00Z",
    "voting_completed_at": null,
    "candidate_count": 10,
    "participant_count": 4,
    "joined_participant_count": 4,
    "completed_participant_count": 2,
    "is_complete": false,
    "participants": [
      {
        "anonymous_user_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
        "completed_vote_count": 10,
        "is_complete": true,
        "is_me": true,
        "is_host": true
      }
    ]
  }
}
```

未開始は `409`、未登録参加者は `403`、候補にない店舗IDは `422`。

## GET /temporary-groups/{group_id}/voting/progress

参加者ごとの投票済み候補数と完了状態を返す。

```http
GET /temporary-groups/{group_id}/voting/progress?participant_token=...
```

`participant_token` は任意。指定して匿名ユーザーを解決できた場合だけ、対応する
参加者の `is_me` がtrueになる。`is_host` は `creator_id` と匿名ユーザーIDの一致で判定する。

## GET /temporary-groups/{group_id}/voting/result

全参加者の投票完了後に集計結果を返す。未開始または未完了は `409`。

```json
{
  "voting_started_at": "2026-08-01T10:00:00Z",
  "voting_completed_at": "2026-08-01T10:05:00Z",
  "selected_restaurant_id": null,
  "candidate_count": 3,
  "joined_participant_count": 4,
  "completed_participant_count": 4,
  "is_complete": true,
  "has_tie": false,
  "top_like_count": 4,
  "results": [
    {
      "restaurant": {
        "id": "restaurant_123",
        "name": "渋谷ビストロ",
        "address": "東京都渋谷区...",
        "access": "渋谷駅徒歩3分",
        "genre": "ビストロ",
        "budget": "3,000〜5,000円",
        "image_url": "https://example.com/image.jpg",
        "shop_url": "https://example.com/shop"
      },
      "like_count": 4,
      "reject_count": 0,
      "vote_count": 4,
      "rank": 1,
      "like_rate": 1.0
    }
  ]
}
```

並び順は、いいね数の降順、見送り数の昇順、保存済み候補順。順位は同じ
`like_count` に同順位を付ける。単独1位では `selected_restaurant_id` はnullのままで、
`results[0]` が決定店舗として扱われる。

## POST /temporary-groups/{group_id}/voting/result/decision

1位が複数ある場合だけ、ホストが同率1位の候補から1店舗を決定する。

```json
{
  "participant_token": "8f4d9e5a-13f5-4b67-9c3d-7c3a0e0c1b2a",
  "restaurant_id": "restaurant_456"
}
```

成功時は `selected_restaurant_id` が設定された投票結果を返す。すでに決定済みなら
現在の結果を冪等に返す。非ホストは `403`、未完了は `409`、同率1位以外・
同率でない結果への決定は `422`。

## Rate Limit

参加系APIは1 IPあたり1分10回まで。

対象:

```text
POST /temporary-groups/{group_id}/participants
POST /temporary-groups/join
```

設定:

```env
JOIN_RATE_LIMIT_REQUESTS=10
JOIN_RATE_LIMIT_WINDOW_SECONDS=60
PARTICIPANT_TOKEN_HASH_SECRET=change_me_to_a_long_random_value
```

現時点ではin-memory実装。複数processや複数containerで厳密に共有する必要が出たら、DBまたは外部ストアに差し替える。

## Environment Variables

```env
TEMPORARY_GROUP_CODE_MAX_ATTEMPTS=20
JOIN_RATE_LIMIT_REQUESTS=10
JOIN_RATE_LIMIT_WINDOW_SECONDS=60
PARTICIPANT_TOKEN_HASH_SECRET=change_me_to_a_long_random_value
```

`PARTICIPANT_TOKEN_HASH_SECRET` は本番では長いランダム値に変える。

生成例:

```sh
openssl rand -hex 32
```

staging / production では GitHub Environment secrets に登録する。
Git や `.env` には本番値を書かない。

この値はfrontendへ渡さず、Gitにもコミットしない。途中で変更すると既存の匿名参加者token hashと照合できなくなるため、既存匿名ユーザーを捨てるか移行処理が必要になる。
