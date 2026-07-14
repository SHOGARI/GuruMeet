# Temporary Group API

一時グループ作成、UUID取得、コード参加のAPI。

backendは共有URLを作らない。frontendが返却された `id` を使って `/groups/{id}` のようなURLを組み立てる。

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
/groups/{id}

手入力参加:
A7K2F
```

レート制限は `POST /temporary-groups/join` にだけ適用する。UUID URLは推測困難な主導線として扱い、5桁コードは総当たり対策つきの補助導線として扱う。

## POST /temporary-groups

一時グループを作成する。

### Why

グループ作成時点でUUIDと5桁コードを同時に発行する。  
同じ一時グループに2つの参加導線を紐づけるため、frontend側で別々の発行APIを呼ばせない。

backendは共有URLを返さない。共有URLはfrontendのroute設計に依存するため、backendは `id` と `code` の発行に責務を絞る。

### Request

bodyなしでも作成可能。

```json
{}
```

作成者を渡す場合:

```json
{
  "creator_id": "user_123"
}
```

### Processing

1. `id` にUUID v4を発行する。
2. `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` から5文字の `code` を生成する。
3. `expires_at` に作成時刻 + `TEMPORARY_GROUP_TTL_MINUTES` を保存する。
4. `code` のunique制約に衝突した場合はrollbackして再生成する。

### Response

`201 Created`

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "code": "A7K2F",
  "expires_at": "2026-07-16T12:00:00Z"
}
```

### Errors

`503 Service Unavailable`

コード生成が設定回数以内に成功しなかった場合。

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
  "created_at": "2026-07-15T12:00:00Z",
  "creator_id": "user_123"
}
```

### Errors

`404 Not Found`

```json
{
  "detail": "一時グループが存在しない、または期限切れです。"
}
```

## POST /temporary-groups/join

5桁コードから一時グループを取得する。

### Why

手入力参加の補助導線。  
5桁コードは入力しやすい一方でUUIDより短く、総当たりの対象になる。そのため、このAPIだけclient IPごとのレート制限をかける。

存在しないコードと期限切れコードは同じ404にする。コードの有効性を推測しやすいレスポンスにしないため。

### Request

```json
{
  "code": "A7K2F"
}
```

### Processing

1. client IPごとのrate limitを確認する。
2. `code` をuppercaseにして検索する。
3. `expires_at > now` の行だけ有効扱いにする。
4. 存在しないコードと期限切れコードは同じ404を返す。

### Response

`200 OK`

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "code": "A7K2F",
  "expires_at": "2026-07-16T12:00:00Z",
  "created_at": "2026-07-15T12:00:00Z",
  "creator_id": "user_123"
}
```

### Errors

`404 Not Found`

```json
{
  "detail": "一時グループが存在しない、または期限切れです。"
}
```

`429 Too Many Requests`

```json
{
  "detail": "参加試行が多すぎます。時間をおいて再試行してください。"
}
```

## Rate Limit

`POST /temporary-groups/join` は1 IPあたり1分10回まで。

設定:

```env
JOIN_RATE_LIMIT_REQUESTS=10
JOIN_RATE_LIMIT_WINDOW_SECONDS=60
```

現時点ではin-memory実装。複数processや複数containerで厳密に共有する必要が出たら、DBまたは外部ストアに差し替える。

## Environment Variables

```env
TEMPORARY_GROUP_TTL_MINUTES=1440
TEMPORARY_GROUP_CODE_MAX_ATTEMPTS=20
JOIN_RATE_LIMIT_REQUESTS=10
JOIN_RATE_LIMIT_WINDOW_SECONDS=60
```

