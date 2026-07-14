# API Overview

backendはFlutter frontendに対してJSON APIを提供する。

## 現在のAPI

| API | purpose | detail |
| --- | --- | --- |
| `POST /temporary-groups` | 一時グループを作成する | [Temporary Group API](./temporary-group.md) |
| `GET /temporary-groups/{group_id}` | UUIDから一時グループを取得する | [Temporary Group API](./temporary-group.md) |
| `POST /temporary-groups/join` | 5桁コードから一時グループを取得する | [Temporary Group API](./temporary-group.md) |

## 基本方針

backendは、DBに保存する識別子と状態を管理する。frontendの画面URLはfrontend側で組み立てる。

そのため、一時グループ作成APIは `id`、`code`、`expires_at` を返すが、`/groups/{id}` のような共有URL文字列は返さない。

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "code": "A7K2F",
  "expires_at": "2026-07-16T12:00:00Z"
}
```

frontendは返却された `id` を使って共有URLを組み立てる。

```text
/groups/{id}
```

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

API説明は日本語で記述する。

