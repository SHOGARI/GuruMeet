# API Overview

backendはFlutter frontendに対してJSON APIを提供する。

## 現在のAPI

| API | purpose | detail |
| --- | --- | --- |
| `GET /` | backendの疎通確認 | [System API](./system.md) |
| `GET /health` | backendのhealth check | [System API](./system.md) |
| `GET /locations?prefecture=...` | 都道府県内の地点候補を一括取得する | [Location API](./locations.md) |
| `GET /locations/search` | 市区町村と駅を統合検索する | [Location API](./locations.md) |
| `GET /locations/{location_id}` | 地点IDの存在確認 | [Location API](./locations.md) |
| `POST /temporary-groups` | 一時グループを作成する | [Temporary Group API](./temporary-group.md) |
| `GET /temporary-groups/{group_id}` | UUIDから一時グループを取得する | [Temporary Group API](./temporary-group.md) |
| `POST /temporary-groups/{group_id}/participants` | UUIDから参加する | [Temporary Group API](./temporary-group.md) |
| `POST /temporary-groups/join` | 5桁コードから一時グループを取得する | [Temporary Group API](./temporary-group.md) |
| `POST /temporary-groups/{group_id}/dissolve` | 一時グループを解散する | [Temporary Group API](./temporary-group.md) |
| `POST /temporary-groups/{group_id}/voting/start` | 投票を開始する | [Temporary Group API](./temporary-group.md) |
| `POST /temporary-groups/{group_id}/votes` | 店舗候補へ投票する | [Temporary Group API](./temporary-group.md) |
| `GET /temporary-groups/{group_id}/voting/progress` | 投票進捗を取得する | [Temporary Group API](./temporary-group.md) |
| `GET /temporary-groups/{group_id}/voting/result` | 完了済み投票の結果を取得する | [Temporary Group API](./temporary-group.md) |
| `POST /temporary-groups/{group_id}/voting/result/decision` | 同率1位から店舗を決定する | [Temporary Group API](./temporary-group.md) |
| `POST /internal/cleanup-expired-temporary-groups` | 期限切れデータを削除する内部API | [System API](./system.md) |

TemporaryGroup作成時のHot Pepper店舗検索と推薦仕様は
[TemporaryGroup x Restaurant](./temporary-group-restaurant.md) を参照する。

## 基本方針

backendは、DBに保存する識別子と状態を管理する。frontendの画面URLはfrontend側で組み立てる。

そのため、一時グループ作成APIは識別子、期限、人数・進行状態の要約を返すが、
`/#/join/{id}` のような共有URL文字列は返さない。

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

frontendは返却された `id` を使って共有URLを組み立てる。

```text
/#/join/{id}
```

APIレスポンスのJSON fieldは原則 `snake_case`。地点候補の
`displayName` / `lineName` はFlutter側の既存モデルに合わせた例外。

## URL prefix

ローカルではFastAPIへ直接接続するため、上表のpathをそのまま使う。

```text
http://localhost:8000/temporary-groups
```

Cloudflare stagingではWorkerが `/api/*` を受け、`/api` prefixを外して
FastAPI containerへ転送する。

```text
https://stg.gurumeet.net/api/temporary-groups
```

現行Workerは `ENVIRONMENT=production` の場合、`/api` と `/api/*` を
containerへ転送せず404にする。したがって `https://gurumeet.net/api/*` は現在非公開。

## エラーポリシー

存在しない一時グループと期限切れの一時グループは、同じ404レスポンスにする。

```json
{
  "detail": "一時グループが存在しない、または期限切れです。"
}
```

理由は、UUIDやコードの存在確認に使える情報を余計に返さないため。

## OpenAPI

FastAPIのOpenAPIは以下で確認できる。

```text
http://localhost:8000/docs
```

OpenAPI UIはdevelopment系環境だけで有効。`ENVIRONMENT=production` または
`product` では `/docs`、`/redoc`、`/openapi.json` を公開しない。

API説明は日本語で記述する。実装上のsource of truthは
`backend/app/api/routes/` と `backend/app/schemas/`。
