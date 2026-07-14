# API

## Temporary Groups

一時グループ作成、UUID取得、コード参加のAPI。

backendは共有URLを作らない。frontendが返却された `id` を使って `/groups/{id}` のようなURLを組み立てる。

## POST /temporary-groups

一時グループを作成する。

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
  "detail": "Temporary group not found or expired."
}
```

## POST /temporary-groups/join

5桁コードから一時グループを取得する。

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
  "detail": "Temporary group not found or expired."
}
```

`429 Too Many Requests`

```json
{
  "detail": "Too many join attempts. Please try again later."
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
