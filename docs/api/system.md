# System API

backendの疎通確認と、運用タスク用の内部API。

## GET /

FastAPI applicationが応答できることを確認する。

```json
{
  "status": "ok",
  "service": "gurumeet-backend"
}
```

## GET /health

backend processのhealth check。

```json
{
  "status": "healthy"
}
```

DBや外部APIの疎通までは検査しない。Cloudflare WorkerとR2のhealthは
`GET /edge/health` が担当する。

## POST /internal/cleanup-expired-temporary-groups

期限切れ一時グループを物理削除し、期限切れのcustom locationも削除する。
Discord slash command `/delete staging` / `/delete production` からWorker経由で実行する。

Request header:

```http
X-Internal-Task-Secret: <INTERNAL_TASK_SECRET>
```

secretは必須で、欠落または不一致の場合は `401 Unauthorized`。

Response:

```json
{
  "deleted_expired_temporary_groups": 12
}
```

レスポンス件数は削除した `temporary_groups` の数だけを表す。関連する
participants / votesはFKのCASCADEで削除する。削除した `custom_locations` の件数は返さない。

このendpointは一般クライアント用ではない。Workerは `/api/internal/*` を
containerへ転送し得るため、backend側で `X-Internal-Task-Secret` を必ず検証する。
Workerは `http://container/internal/...` を直接呼ぶ。
