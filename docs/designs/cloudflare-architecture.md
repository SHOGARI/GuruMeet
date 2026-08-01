# Cloudflare 利用設計

## 目的

GuruMeet は frontend を Flutter、backend を FastAPI で構成する。現在はCloudflare
Worker 1本に静的配信、API入口、container実行、R2配信、定期cleanupをまとめている。

ただし、DB は最初から Cloudflare D1 に寄せない。ユーザー、ミーティング、参加者、予定のようなリレーションを扱うため、backend の主 DB は PostgreSQL を前提にする。

## 採用方針

```text
Entrypoint
  Cloudflare Worker
    Flutter Web の build/web を Workers Static Assets で配信する
    /api/* を FastAPI container に流す
    /files/* で R2 object を返す
    request を Workers Container に流す

Backend runtime
  Cloudflare Workers Containers
    FastAPI + uvicorn を Docker image として実行する

Database
  PostgreSQL
    Neon PostgreSQL を使う
    必要になったら Cloudflare Hyperdrive を挟む

Object storage
  Cloudflare R2
    画像、添付ファイル、生成物などの blob を置く

Cache / lightweight state
  Cloudflare KV
    現在は未使用。feature flagや短いcacheが必要になった場合の候補

Async jobs
  Cloudflare Queues
    現在は未使用。通知、メール送信、重い後処理を逃がす場合の候補

Scheduled jobs
  Workers Cron Triggers
    毎日12:00 UTC（21:00 JST）に期限切れ一時グループをcleanup
```

## 全体像

```text
User
  |
  v
Cloudflare Worker
  |-- /             -> Flutter Web static assets
  |-- /api/*        -> Workers Container -> FastAPI -> PostgreSQL
  |-- /files/*      -> R2
  |-- /edge/health  -> Worker health
```

## ドメイン案

現在:

```text
stg.gurumeet.net  -> staging Worker
gurumeet.net      -> production Worker
```

Pages を分ける場合の将来案:

```text
gurumeet.net      -> Cloudflare Pages
api.gurumeet.net  -> Cloudflare Worker + Workers Container
```

staging / productionとも `/api/*` を同一ドメイン配下にまとめている。Workerは
`/api` prefixを外してFastAPI containerへ転送する。

## Frontend

Flutter Web は build 後に静的ファイルになるため、Workers Static Assets に載せる。

想定:

```text
frontend/
  build/web/
```

`infra/cloudflare/app-worker/wrangler.jsonc` の `assets.directory` で、Flutter の build output を Worker の配信対象にする。

frontend から backend を呼ぶ API base URL は環境ごとに分ける。

```text
local web:
  http://localhost:8000

Android emulator:
  http://10.0.2.2:8000

staging:
  /api

production:
  /api
```

## Backend

backend 本体は FastAPI として保つ。Cloudflare Workers Containers の都合を `backend/app` に混ぜない。

現在の backend の責務:

```text
backend/
  app/          # FastAPI application
  compose.yaml  # backend local development
  docker/       # backend image build files
  Makefile
  requirements.txt
```

Cloudflare 用の Worker entrypoint は `infra/` 配下に置く。

```text
infra/
  cloudflare/
    app-worker/
      package.json
      wrangler.jsonc
      src/
        index.ts
```

理由:

- FastAPI 本体と Cloudflare 接続層を分離する
- infrastructure 関連の設定を `infra/` に寄せる
- local Docker 開発と Cloudflare deploy の責務を混ぜない
- 将来 Cloud Run / Fly.io などへ逃がす余地を残す

## Workers Containers の役割

Workers Containers は、Worker から container instance を起動・呼び出す。FastAPI は container 内で `uvicorn` として動く。

概念:

```text
Worker TypeScript code
  -> Container class
  -> FastAPI container
```

Cloudflare 公式ドキュメントでは、Containers は Workers と組み合わせて任意言語・任意 runtime の container image を動かす仕組みとして説明されている。

参考:

- Cloudflare Containers: https://developers.cloudflare.com/containers/
- Getting started: https://developers.cloudflare.com/containers/get-started/
- Limits and instance types: https://developers.cloudflare.com/containers/platform-details/limits/

## DB 方針

主 DB は PostgreSQL にする。

理由:

- ユーザー、ミーティング、参加者、予定はリレーショナルに扱う方が自然
- FastAPI + SQLAlchemy / Alembic と相性がよい
- migration と運用の選択肢が広い

Cloudflare D1 は主DBにはしない。

理由:

- D1 は Cloudflare native で魅力はあるが、今回の backend は FastAPI + PostgreSQL + ORM 方針
- D1 に寄せると FastAPI の DB 設計より Cloudflare runtime 前提の設計になる
- まずは RDB として一般的な PostgreSQL を source of truth にする

採用:

```text
Neon
```

DB 接続が課題になったら Cloudflare Hyperdrive を検討する。

## Cloudflare サービスの使い分け

```text
Workers
  Flutter Web 静的配信、API 入口、routing、軽い request 前処理

Workers Containers
  FastAPI runtime

R2
  画像、添付、アップロードファイル

KV
  軽い cache、feature flag、設定値

Queues
  非同期処理

Cron Triggers
  定期処理

Access
  管理画面や internal endpoint を保護する場合に使う
```

## 現在の実装

1. Flutter WebをWorkers Static Assetsで配信する
2. staging / productionでは `/api/*` のprefixを外してFastAPI containerへ転送する
3. `/api` と `/api/` はAPI rootとして404にする
4. staging / productionともNeon PostgreSQLへ接続する
5. `/files/*` で環境別R2 bucketのobjectを返す
6. `/edge/health` でWorkerとR2のhealthを返す
7. Cron Triggerから内部cleanup APIをsecret付きで呼ぶ
8. containerの5xx、cleanup失敗、利用イベントをDiscordへ通知する

## 現在やっていないこと

- Cloudflare D1 を主 DB にする
- backend を Pages Functions に寄せる
- FastAPI の中に Cloudflare Worker の都合を混ぜる
- frontend を Cloudflare Pages に分ける
- KV / Queuesを利用する

## リスク

Workers Containers は通常の container hosting より構成が特殊になる。

注意点:

- Workers Paid plan が必要
- Worker entrypoint と container runtime の両方を管理する必要がある
- `wrangler deploy` 時に Docker build / image push が絡む
- instance type、cold start、routing、DB 接続の検証が必要

そのため、FastAPI 本体は Cloudflare 依存にしない。Cloudflare 側が詰まった場合でも、同じ Docker image を Cloud Run / Fly.io / Render / VPS に逃がせる状態を保つ。

## 現時点の結論

Cloudflare を使い倒す方針で進める。

ただし、Cloudflare に寄せるのは deploy / routing / storage layerであり、
backend application codeはFastAPIとして独立させる。cache / async layerは将来必要になった場合に追加する。

```text
frontend = Workers Static Assets
entrypoint = Cloudflare Worker
backend runtime = Workers Containers
main DB = Neon PostgreSQL
blob storage = R2
cache = unused (KV is a future option)
async = unused (Queues is a future option)
```
