# Cloudflare 利用設計

## 目的

GuruMeet は frontend を Flutter、backend を FastAPI で構成する。デプロイ先は Cloudflare を中心に寄せ、静的配信、API 入口、container 実行、storage、cache、非同期処理を Cloudflare のサービスでできるだけ管理する。

ただし、DB は最初から Cloudflare D1 に寄せない。ユーザー、ミーティング、参加者、予定のようなリレーションを扱うため、backend の主 DB は PostgreSQL を前提にする。

## 採用方針

```text
Frontend
  Cloudflare Pages
    Flutter Web の build/web を配信する

Backend entrypoint
  Cloudflare Worker
    /api/* または api.example.com の入口にする
    request を Workers Container に流す

Backend runtime
  Cloudflare Workers Containers
    FastAPI + uvicorn を Docker image として実行する

Database
  PostgreSQL
    Neon / Supabase / Railway Postgres などの managed PostgreSQL を候補にする
    必要になったら Cloudflare Hyperdrive を挟む

Object storage
  Cloudflare R2
    画像、添付ファイル、生成物などの blob を置く

Cache / lightweight state
  Cloudflare KV
    feature flag、短い cache、頻繁に変わらない設定値を置く

Async jobs
  Cloudflare Queues
    通知、メール送信、重い後処理などを後で逃がす

Scheduled jobs
  Workers Cron Triggers
    定期 cleanup、通知予約、集計などを後で逃がす
```

## 全体像

```text
User
  |
  v
Cloudflare Pages
  |
  | Flutter Web static assets
  v
Browser / App
  |
  | HTTPS JSON API
  v
Cloudflare Worker
  |
  | request forwarding
  v
Workers Container
  |
  | uvicorn
  v
FastAPI
  |
  | SQLAlchemy / Alembic
  v
PostgreSQL
```

## ドメイン案

第一候補:

```text
app.example.com  -> Cloudflare Pages
api.example.com  -> Cloudflare Worker + Workers Container
```

代替:

```text
example.com      -> Cloudflare Pages
api.example.com  -> Cloudflare Worker + Workers Container
```

`/api/*` を同一ドメイン配下にまとめる案もあるが、最初は `api.example.com` を分ける。frontend と backend の責務、CORS、ログ、deploy 単位を分けやすいため。

## Frontend

Flutter Web は build 後に静的ファイルになるため、Cloudflare Pages に載せる。

想定:

```text
frontend/
  build/web/
```

Cloudflare Pages 側では、Flutter の build output を Pages の公開対象にする。

frontend から backend を呼ぶ API base URL は環境ごとに分ける。

```text
local web:
  http://localhost:8000

Android emulator:
  http://10.0.2.2:8000

production:
  https://api.example.com
```

## Backend

backend 本体は FastAPI として保つ。Cloudflare Workers Containers の都合を `backend/app` に混ぜない。

現在の backend の責務:

```text
backend/
  app/          # FastAPI application
  docker/       # local Docker / container image
  Makefile
  requirements.txt
```

Cloudflare 用の Worker entrypoint は別ディレクトリに置く。

```text
cloudflare/
  backend-worker/
    src/
      index.ts
    wrangler.toml
```

理由:

- FastAPI 本体と Cloudflare 接続層を分離する
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

Cloudflare D1 は初期の主 DB にはしない。

理由:

- D1 は Cloudflare native で魅力はあるが、今回の backend は FastAPI + PostgreSQL + ORM 方針
- D1 に寄せると FastAPI の DB 設計より Cloudflare runtime 前提の設計になる
- まずは RDB として一般的な PostgreSQL を source of truth にする

候補:

```text
Neon
Supabase
Railway Postgres
その他 managed PostgreSQL
```

DB 接続が課題になったら Cloudflare Hyperdrive を検討する。

## Cloudflare サービスの使い分け

```text
Pages
  Flutter Web の静的配信

Workers
  API 入口、routing、軽い request 前処理

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

## 初期実装でやること

1. backend は local Docker で FastAPI を動かす
2. backend compose に PostgreSQL を追加する
3. SQLAlchemy / Alembic の導入を検討する
4. Cloudflare deploy layer を `cloudflare/backend-worker/` に追加する
5. Workers Containers で FastAPI container を呼び出す最小構成を作る
6. frontend から `https://api.example.com` を呼ぶ設定を用意する
7. production DB を決める

## 初期実装ではやらないこと

- Cloudflare D1 を主 DB にする
- backend を Pages Functions に寄せる
- FastAPI の中に Cloudflare Worker の都合を混ぜる
- frontend と backend を同じ deploy unit にする
- R2 / KV / Queues を最初から全部実装する

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

ただし、Cloudflare に寄せるのは deploy / routing / storage / cache / async layer であり、backend application code は FastAPI として独立させる。

```text
frontend = Cloudflare Pages
backend entrypoint = Cloudflare Worker
backend runtime = Workers Containers
main DB = PostgreSQL
blob storage = R2
cache = KV
async = Queues
```
