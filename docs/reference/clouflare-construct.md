# Cloudflare Workers 構築手順

## このドキュメントの読み方

GuruMeet を Cloudflare に載せるための手順書。

最初の方針は以下にする。

```text
フロントエンド: Flutter Web -> Workers Static Assets
API入口:        Cloudflare Worker
バックエンド:  FastAPI -> Workers Container
ファイル:      R2
DB:      Neon PostgreSQL
staging: Cloudflare Access で保護
```

このファイルでは、実際にどのファイルへ何を書くかを先に説明し、その後に Cloudflare 側で作るもの、最後に deploy 順を説明する。

## まず決めること

環境は Git branch と対応させる。

```text
develop ブランチ -> staging    -> stg.gurumeet.net
main ブランチ    -> production -> gurumeet.net
```

Cloudflare resource は staging と production で分ける。

```text
staging
  Worker: gurumeet-staging
  R2:     gurumeet-staging-assets
  DB:     Neon staging
  Domain: stg.gurumeet.net

production
  Worker: gurumeet
  R2:     gurumeet-assets
  DB:     Neon production
  Domain: gurumeet.net
```

staging と production で同じ R2 bucket や DB を共有しない。事故った時に本番データへ触らないため。

## 全体像

```text
Browser / iOS app
  |
  | HTTPS
  v
Cloudflare Worker
  |-- /                 -> Flutter Web static assets
  |-- /api/*            -> FastAPI container
  |-- /files/*          -> R2 object delivery
  |-- /edge/health      -> Worker health check
  |
  v
Workers Container
  |
  v
FastAPI
  |
  v
Neon PostgreSQL
```

Worker は Cloudflare 側の入口。FastAPI の代替ではない。

Worker の役割:

- Flutter Web の静的ファイルを配信する
- `/api/*` を FastAPI container に流す
- `/files/*` で R2 の画像や添付を返す
- staging は Cloudflare Access の入口にする

FastAPI の役割:

- アプリの業務ロジック
- 認証、ユーザー、グループ、ミーティング等の API
- PostgreSQL への読み書き

## 推奨フォルダ構成

マーカーの意味:

```text
[既存]  既存のまま使う
[追加]  今回の Cloudflare 化で追加する
[移動]  既存ファイルを移動する予定
[生成]  build や install で生成される。手書きしない
```

```text
gurumeet/
  frontend/                              # [既存]
    lib/                                 # [既存]
    web/                                 # [既存]
    pubspec.yaml                         # [既存]
    build/                               # [生成]
      web/                               # [生成] flutter build web の出力
    .env.example                         # [既存] ローカル frontend 用

  backend/                               # [既存]
    app/                                 # [既存] FastAPI 本体
      main.py                            # [既存]
      api/                               # [既存]
      core/                              # [既存]
      db/                                # [既存]
      models/                            # [既存]
      schemas/                           # [既存]
      services/                          # [既存]
    requirements.txt                     # [既存]
    .env.example                         # [追加] ローカル backend 用
    compose.yaml                         # [移動] backend/docker/compose.yaml から移動予定
    docker/                              # [既存]
      Dockerfile                         # [既存] ローカル開発用
      Dockerfile.dockerignore            # [既存]
    Dockerfile.cloudflare                # [追加] Workers Container 用

  infra/                                 # [追加]
    cloudflare/                          # [追加]
      app-worker/                        # [追加] Cloudflare Worker プロジェクト
        src/
          index.ts                       # [追加] Worker の入口
        .dev.vars.sample                 # [追加] wrangler dev 用サンプル
        package.json                     # [追加] wrangler / TypeScript 管理
        package-lock.json                # [生成] npm install で更新
        tsconfig.json                    # [追加] TypeScript 設定
        wrangler.jsonc                   # [追加] Worker / Container / R2 / domain 設定
        node_modules/                    # [生成] commit しない

  docs/
    reference/
      clouflare-construct.md             # [追加] この手順書
```

Cloudflare 固有の設定は `infra/cloudflare/app-worker/` に寄せる。`backend/app` には Cloudflare の都合を混ぜない。

## いま作るファイル

ここは repo に置くファイル。Cloudflare の GUI 操作や deploy はまだしない。

### 1. Worker プロジェクト

場所:

```text
infra/cloudflare/app-worker/
```

作るファイル:

```text
infra/cloudflare/app-worker/package.json
infra/cloudflare/app-worker/tsconfig.json
infra/cloudflare/app-worker/wrangler.jsonc
infra/cloudflare/app-worker/src/index.ts
infra/cloudflare/app-worker/.dev.vars.sample
```

`npm create cloudflare` は使わない。モノレポ root で実行すると既存の `frontend/` と `backend/` に余計な構成が混ざりやすいため。

初回だけ実行するコマンド:

```sh
mkdir -p infra/cloudflare/app-worker/src
cd infra/cloudflare/app-worker
npm init -y
npm install @cloudflare/containers
npm install -D wrangler typescript @cloudflare/workers-types
```

`package.json` に置くもの:

```json
{
  "name": "gurumeet-app-worker",
  "private": true,
  "type": "module",
  "scripts": {
    "check": "tsc --noEmit",
    "dev:staging": "wrangler dev --env staging",
    "deploy:staging": "wrangler deploy --env staging",
    "deploy:production": "wrangler deploy --env production"
  },
  "dependencies": {
    "@cloudflare/containers": "^0.3.7"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^5.20260714.1",
    "typescript": "^7.0.2",
    "wrangler": "^4.112.0"
  }
}
```

`@cloudflare/workers-types` は Cloudflare Worker 専用の型定義。`R2Bucket`、`Fetcher`、`DurableObjectNamespace` などを TypeScript が理解するために入れる。

`typescript` は Worker を TypeScript で書くために入れる。FastAPI を TypeScript 化するものではない。

### 2. tsconfig.json

場所:

```text
infra/cloudflare/app-worker/tsconfig.json
```

中身:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "Bundler",
    "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*.ts"]
}
```

これは手書きでよい。`npm` が自動生成するファイルではない。

### 3. wrangler.jsonc

場所:

```text
infra/cloudflare/app-worker/wrangler.jsonc
```

このファイルに書くもの:

- Worker 名
- Worker の入口
- Flutter Web build の場所
- Container image の場所
- R2 bucket binding
- staging / production の環境差分
- custom domain route

最初の中身:

```jsonc
{
  "name": "gurumeet",
  "main": "src/index.ts",
  "compatibility_date": "2026-07-21",
  "workers_dev": true,
  "assets": {
    "directory": "../../../frontend/build/web",
    "binding": "ASSETS",
    "not_found_handling": "single-page-application",
    "run_worker_first": ["/api/*", "/files/*", "/edge/*"]
  },
  "containers": [
    {
      "class_name": "BackendContainer",
      "image": "../../../backend/Dockerfile.cloudflare",
      "max_instances": 1,
      "instance_type": "lite"
    }
  ],
  "durable_objects": {
    "bindings": [
      {
        "name": "BACKEND_CONTAINER",
        "class_name": "BackendContainer"
      }
    ]
  },
  "migrations": [
    {
      "tag": "v1",
      "new_sqlite_classes": ["BackendContainer"]
    }
  ],
  "env": {
    "staging": {
      "name": "gurumeet-staging",
      "workers_dev": true,
      "vars": {
        "ENVIRONMENT": "staging"
      },
      "routes": [
        {
          "pattern": "stg.gurumeet.net",
          "custom_domain": true
        }
      ],
      "r2_buckets": [
        {
          "binding": "ASSETS_BUCKET",
          "bucket_name": "gurumeet-staging-assets"
        }
      ]
    },
    "production": {
      "name": "gurumeet",
      "workers_dev": false,
      "vars": {
        "ENVIRONMENT": "production"
      },
      "routes": [
        {
          "pattern": "gurumeet.net",
          "custom_domain": true
        }
      ],
      "r2_buckets": [
        {
          "binding": "ASSETS_BUCKET",
          "bucket_name": "gurumeet-assets"
        }
      ]
    }
  }
}
```

重要:

- `assets.directory` は `wrangler.jsonc` から見た相対 path
- `r2_buckets.bucket_name` は Cloudflare に実際に作る bucket 名と一致させる
- `binding: "ASSETS_BUCKET"` は Worker code 側の `env.ASSETS_BUCKET` と一致させる
- `migrations.new_sqlite_classes` は Containers 用の Durable Object migration。D1 migration ではない

### 4. Worker の入口

場所:

```text
infra/cloudflare/app-worker/src/index.ts
```

このファイルに書くもの:

- `/edge/health` の返却
- `/files/*` の R2 配信
- `/api/*` の FastAPI container 転送
- その他の path の Flutter Web 配信

最小実装:

```ts
import { Container, getRandom } from "@cloudflare/containers";

const INSTANCE_COUNT = 1;

export class BackendContainer extends Container {
  defaultPort = 8000;
  sleepAfter = "30m";
}

interface Env {
  ASSETS: Fetcher;
  BACKEND_CONTAINER: DurableObjectNamespace<BackendContainer>;
  ASSETS_BUCKET: R2Bucket;
  ENVIRONMENT?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/edge/health") {
      return edgeHealth(env);
    }

    if (url.pathname.startsWith("/files/")) {
      return handleFileRequest(request, env);
    }

    if (url.pathname.startsWith("/api/")) {
      const container = await getRandom(env.BACKEND_CONTAINER, INSTANCE_COUNT);
      return container.fetch(stripApiPrefix(request));
    }

    return env.ASSETS.fetch(request);
  },
};

async function edgeHealth(env: Env): Promise<Response> {
  const checks = {
    environment: env.ENVIRONMENT ?? "unknown",
    worker: "healthy",
    r2: "unknown",
  };

  try {
    await env.ASSETS_BUCKET.head("__healthcheck__");
    checks.r2 = "healthy";
  } catch {
    checks.r2 = "unhealthy";
  }

  return json(checks);
}

async function handleFileRequest(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const key = decodeURIComponent(url.pathname.replace(/^\/files\//, ""));

  if (!key || key.includes("..")) {
    return new Response("Bad request", { status: 400 });
  }

  const object = await env.ASSETS_BUCKET.get(key);

  if (!object) {
    return new Response("Not found", { status: 404 });
  }

  return new Response(object.body, {
    headers: {
      "Content-Type": object.httpMetadata?.contentType ?? "application/octet-stream",
      "Cache-Control": "public, max-age=3600",
      "ETag": object.httpEtag,
    },
  });
}

function stripApiPrefix(request: Request): Request {
  const url = new URL(request.url);
  url.pathname = url.pathname.replace(/^\/api/, "") || "/";
  return new Request(url, request);
}

function json(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...init.headers,
    },
  });
}
```

`/api/health` は FastAPI 側には `/health` として届く。既存 API を `/api` prefix なしで保てる。

### 5. Cloudflare Container 用 Dockerfile

場所:

```text
backend/Dockerfile.cloudflare
```

このファイルに書くもの:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

これは Cloudflare Container に載せるための Dockerfile。local 開発の Dockerfile と分けてよい。

### 6. env サンプル

Git に置くのは sample だけ。本体 `.env` や `.dev.vars` は commit しない。

置く sample:

```text
frontend/.env.example
backend/.env.example
infra/cloudflare/app-worker/.dev.vars.sample
```

local で各自が作る本体:

```text
frontend/.env
backend/.env
infra/cloudflare/app-worker/.dev.vars
```

`infra/cloudflare/app-worker/.dev.vars.sample`:

```env
ENVIRONMENT=development
DATABASE_URL=postgresql://gurumeet:change_me@host.docker.internal:5432/gurumeet
```

staging / production の secret は `.dev.vars` ではなく GitHub Environment secrets に入れる。

## Cloudflare 側で作るもの

ここからは Cloudflare / Neon の外部 resource。ファイルを作るだけでは存在しない。

### 1. Cloudflare account と zone

GUI でやる。

やること:

```text
Cloudflare に gurumeet.net の zone を追加する
DNS を Cloudflare 管理にする
```

必要な理由:

- `stg.gurumeet.net` と `gurumeet.net` を Worker に向けるため
- staging に Cloudflare Access をかけるため

### 2. Workers Paid plan

GUI で確認する。

Workers Containers は Workers Paid plan 前提。完全無料で FastAPI container を Cloudflare に載せる前提にはしない。

### 3. R2 bucket

CLI で作る。

作るもの:

```text
gurumeet-staging-assets
gurumeet-assets
```

実行場所:

```text
infra/cloudflare/app-worker/
```

コマンド:

```sh
npx wrangler r2 bucket create gurumeet-staging-assets
npx wrangler r2 bucket create gurumeet-assets
```

この bucket 名は `wrangler.jsonc` のここに対応する。

```jsonc
"r2_buckets": [
  {
    "binding": "ASSETS_BUCKET",
    "bucket_name": "gurumeet-staging-assets"
  }
]
```

R2 は repo 内に専用ディレクトリを作るものではない。実体は Cloudflare 側の object storage。

アプリの DB に保存するのは file body ではなく R2 key。

```text
avatars/user_123.png
meetings/meeting_456/materials/file_789.pdf
```

frontend には R2 の実 URL を渡さない。Worker 経由の path を渡す。

```json
{
  "avatarUrl": "/files/avatars/user_123.png"
}
```

### 4. Neon PostgreSQL

GUI で作る。

作るもの:

```text
staging DB
production DB
```

FastAPI からは `DATABASE_URL` で接続する。

local:

```text
backend/compose.yaml の PostgreSQL container
```

staging / production:

```text
Neon PostgreSQL
```

本番用の `DATABASE_URL` は repo の `.env` に書かない。GitHub Environment secrets に入れる。

### 5. GitHub Environment secrets

GitHub repository settings で登録する。

登録場所:

```text
Settings
  -> Environments
  -> staging / production
  -> Environment secrets
```

staging / production それぞれに登録する値:

```text
DATABASE_URL
HOTPEPPER_API_KEY
PARTICIPANT_TOKEN_HASH_SECRET
INTERNAL_TASK_SECRET
```

値の作り方:

```sh
openssl rand -hex 32
```

GitHub Environment vars に登録する値:

```text
CORS_ALLOW_ORIGINS
GURUMEET_ENABLE_MOCK_RESTAURANTS
```

`PARTICIPANT_TOKEN_HASH_SECRET` と `INTERNAL_TASK_SECRET` は上のような長いランダム値を使う。
`DATABASE_URL` は各環境の Neon PostgreSQL connection string を使う。

deploy workflow が GitHub Environment secrets を `wrangler deploy --secrets-file` で、
GitHub Environment vars を `wrangler deploy --var` で Cloudflare に渡す。Git には残らない。

### 6. Cloudflare Access

GUI でやる。

対象:

```text
stg.gurumeet.net
```

やること:

```text
Zero Trust
  -> Access
  -> Applications
  -> Add application
  -> Self-hosted
  -> Domain: stg.gurumeet.net
  -> Policy: 許可する email / Google / GitHub など
```

初期公開前は production の `gurumeet.net` にも Access をかけてよい。一般ユーザーへ公開する段階で Access を外し、アプリ側のユーザー認証へ切り替える。

## デプロイ前にローカルでやること

### 1. frontend build

実行場所:

```text
frontend/
```

コマンド:

```sh
flutter build web
```

できるもの:

```text
frontend/build/web
```

`wrangler.jsonc` の `assets.directory` がこの directory を見ている。

### 2. Worker の型チェック

実行場所:

```text
infra/cloudflare/app-worker/
```

コマンド:

```sh
npm run check
```

何を確認するか:

- `src/index.ts` の TypeScript が壊れていないか
- `R2Bucket` など Cloudflare binding の型が解決できるか

### 3. backend DB migration

現時点では Alembic 等の migration 方針が固まったら具体化する。

本番 deploy 前には必ず app code と DB schema を合わせる。

## デプロイの順序

`wrangler deploy` は最後に実行する。

理由は、`wrangler deploy` が以下をまとめて Cloudflare に反映するため。

```text
Worker code
Workers Static Assets
Container image
R2 binding
env vars
routes
```

逆に、`wrangler deploy` では以下は作られない。

```text
Cloudflare zone
Cloudflare Access policy
R2 bucket
Neon PostgreSQL DB
DATABASE_URL の中身
DB migration
```

だから順番はこうなる。

```text
1. repo に必要ファイルを作る
2. Cloudflare / Neon 側の resource を作る
3. GitHub Environment secrets を登録する
4. frontend build を作る
5. Worker の型チェックを通す
6. DB migration を必要なら実行する
7. wrangler deploy する
8. 疎通確認する
```

## 実際に行った staging 初回デプロイ作業

この節は、相談メモではなく実際に staging を開ける状態まで進めた作業ログ。

### 1. Cloudflare Workers Paid を有効化

Workers Containers を使うため、Cloudflare Workers Paid を有効化した。

目的:

```text
Workers Containers を利用できるようにする
```

注意:

```text
Container は active running time に応じて従量課金が乗る可能性がある
billing alert / usage monitoring は必須
```

### 2. R2 を有効化

Cloudflare Dashboard の R2 画面で R2 subscription を account に追加した。

画面上の表示:

```text
Total Due Now: $0.00
Due Monthly: $0.00 + additional usage
```

無料枠:

```text
Storage: 10GB/month
Class A operations: 1M/month
Class B operations: 10M/month
```

### 3. R2 bucket を作成

`infra/cloudflare/app-worker/` で実行した。

```sh
npx wrangler r2 bucket create gurumeet-staging-assets
npx wrangler r2 bucket create gurumeet-assets
```

作成後の bucket:

```text
gurumeet-staging-assets
gurumeet-assets
```

Wrangler が `r2_buckets` を自動追加するか聞いてきた場合は `n` でよい。

理由:

```text
wrangler.jsonc では env.staging / env.production に分けて明示管理するため
binding 名を Worker code 側の env.ASSETS_BUCKET と一致させるため
```

### 4. Neon project を作成

Neon で project を作成した。

設定:

```text
Project name: gurumeet
Postgres version: 16
Region: AWS Asia Pacific 1 (Singapore)
Neon Auth: OFF
```

Postgres version は local の `backend/compose.yaml` に合わせて 16 にした。

```yaml
image: postgres:16-alpine
```

### 5. Neon branch を staging / production に分離

Neon project 内で branch を分けた。

```text
production
staging
```

対応:

```text
develop ブランチ -> Cloudflare staging -> Neon staging ブランチ
main ブランチ    -> Cloudflare production -> Neon production ブランチ
```

staging ブランチ作成時の設定:

```text
Name: staging
Parent branch: production
Data: Branch data and schema
Auto-delete: Never / No auto-delete
```

staging は共有確認用なので、auto-delete は使わない。

### 6. GitHub Environment secrets を登録

Neon の connection string は Git / `.env` / `wrangler.jsonc` に書かない。

登録場所:

```text
Settings
  -> Environments
  -> staging / production
  -> Environment secrets
```

staging / production それぞれに登録する値:

```text
DATABASE_URL
HOTPEPPER_API_KEY
PARTICIPANT_TOKEN_HASH_SECRET
INTERNAL_TASK_SECRET
```

GitHub Environment vars に登録する値:

```text
CORS_ALLOW_ORIGINS
GURUMEET_ENABLE_MOCK_RESTAURANTS
```

`DATABASE_URL` は各環境の Neon connection string を使う。

### 7. Cloudflare Access を staging に設定

Cloudflare Dashboard で設定した。

場所:

```text
Zero Trust
  -> Access controls
  -> Applications
  -> Create new application
  -> Self-hosted and private
  -> Workers
```

接続先:

```text
Subdomain: stg
Domain: gurumeet.net
Path: 空欄
```

対象:

```text
stg.gurumeet.net
```

Access policy の設定:

```text
Policy name: Allow developers
Action: Allow
Include: Emails
Value: 許可する開発者メールアドレス
```

認証設定:

```text
Accept all available identity providers: ON
```

Application details の設定:

```text
Name: Gurumeet Staging
Session duration: 24 hours
```

初期公開前は production の `gurumeet.net` にも Access を設定してよい。一般公開する段階で Access を外す。

### 8. Worker / Container 設定を確認

`wrangler.jsonc` では `env.staging` / `env.production` に以下を明示する。

```text
containers
durable_objects
migrations
r2_buckets
routes
vars
```

理由:

```text
Wrangler の environment では top-level containers / durable_objects が期待通り継承されないため
```

Container には GitHub Environment secrets / vars から deploy 時に渡された実行時設定を環境変数として渡す。

```ts
import { env as workerEnv } from "cloudflare:workers";

const runtimeEnv = workerEnv as {
  DATABASE_URL: string;
  HOTPEPPER_API_KEY?: string;
  CORS_ALLOW_ORIGINS?: string;
  PARTICIPANT_TOKEN_HASH_SECRET?: string;
  INTERNAL_TASK_SECRET?: string;
  GURUMEET_ENABLE_MOCK_RESTAURANTS?: string;
  ENVIRONMENT?: string;
};

export class BackendContainer extends Container {
  defaultPort = 8000;
  sleepAfter = "5m";
  envVars = {
    DATABASE_URL: runtimeEnv.DATABASE_URL,
    HOTPEPPER_API_KEY: runtimeEnv.HOTPEPPER_API_KEY,
    CORS_ALLOW_ORIGINS: runtimeEnv.CORS_ALLOW_ORIGINS,
    PARTICIPANT_TOKEN_HASH_SECRET: runtimeEnv.PARTICIPANT_TOKEN_HASH_SECRET,
    INTERNAL_TASK_SECRET: runtimeEnv.INTERNAL_TASK_SECRET,
    GURUMEET_ENABLE_MOCK_RESTAURANTS:
      runtimeEnv.GURUMEET_ENABLE_MOCK_RESTAURANTS ?? "false",
    ENVIRONMENT: runtimeEnv.ENVIRONMENT ?? "production",
  };
}
```

### 9. frontend build を作成

repo root から:

```sh
cd frontend
flutter build web
```

生成物:

```text
frontend/build/web
```

### 10. Worker の型チェック

```sh
cd infra/cloudflare/app-worker
npm install
npm run check
```

`@cloudflare/workers-types` が見つからない場合は、`node_modules` が壊れている可能性があるため `npm install` で修復する。

### 11. staging deploy

```sh
cd infra/cloudflare/app-worker
npm run deploy:staging
```

内部では以下が実行される。

```sh
wrangler deploy --env staging
```

実際に起きたこと:

```text
frontend/build/web の静的 assets が upload された
gurumeet-staging Worker が upload された
backend/Dockerfile.cloudflare から container image が build された
Cloudflare container registry に image が push された
gurumeet-staging-backendcontainer-staging container application が作成された
stg.gurumeet.net custom domain に deploy された
```

deploy 後に表示された staging endpoint:

```text
https://gurumeet-staging.<account-subdomain>.workers.dev
stg.gurumeet.net
```

production の `gurumeet.net` は `npm run deploy:production` を実行するまで deploy されない。

### 12. staging 動作確認

確認済み:

```text
https://stg.gurumeet.net にアクセスできた
Cloudflare Access の対象として staging を保護できた
```

追加で見る項目:

```text
https://stg.gurumeet.net/edge/health
https://stg.gurumeet.net/api/health
```

注意:

```text
/api/health を外部監視で常時叩かない
監視するなら /edge/health を使う
```

## staging デプロイ

`develop` branch の状態を `stg.gurumeet.net` に出す。

### 事前に終わっているべきこと

```text
Cloudflare zone: gurumeet.net
R2 bucket:       gurumeet-staging-assets
Neon DB:         staging
GitHub Environment secrets: staging
  DATABASE_URL
  HOTPEPPER_API_KEY
  PARTICIPANT_TOKEN_HASH_SECRET
  INTERNAL_TASK_SECRET
GitHub Environment vars: staging
  CORS_ALLOW_ORIGINS
  GURUMEET_ENABLE_MOCK_RESTAURANTS
Access:          stg.gurumeet.net
```

### deploy 直前

```sh
cd frontend
flutter build web
```

```sh
cd infra/cloudflare/app-worker
npm run check
```

### deploy

```sh
cd infra/cloudflare/app-worker
npm run deploy:staging
```

内部ではこれが実行される。

```sh
wrangler deploy --env staging
```

起きること:

- `src/index.ts` が `gurumeet-staging` Worker として deploy される
- `frontend/build/web` が Workers Static Assets として upload される
- `backend/Dockerfile.cloudflare` から container image が build / publish される
- `ASSETS_BUCKET` が `gurumeet-staging-assets` に紐づく
- `stg.gurumeet.net` が Worker に紐づく

### staging 確認

見る順番:

```text
1. https://stg.gurumeet.net で Cloudflare Access login が出る
2. login 後に Flutter Web が表示される
3. https://stg.gurumeet.net/edge/health が返る
4. https://stg.gurumeet.net/api/health が FastAPI から返る
5. FastAPI が staging DB に接続できる
6. /files/<known-key> が R2 staging bucket から返る
```

Access 配下の URL は普通の `curl` では確認しづらい。自動の疎通確認を作る時は Cloudflare Access service token を使う。

## production デプロイ

`main` branch の状態を `gurumeet.net` に出す。

production は staging の確認が終わってから進める。

### 事前に終わっているべきこと

```text
branch:          main
R2 bucket:       gurumeet-assets
Neon DB:         production
GitHub Environment secrets: production
  DATABASE_URL
  HOTPEPPER_API_KEY
  PARTICIPANT_TOKEN_HASH_SECRET
  INTERNAL_TASK_SECRET
GitHub Environment vars: production
  CORS_ALLOW_ORIGINS
  GURUMEET_ENABLE_MOCK_RESTAURANTS
Access:          初期公開前は gurumeet.net にもかけてよい。一般公開時に外す
```

### deploy 直前

```sh
cd frontend
flutter build web
```

```sh
cd infra/cloudflare/app-worker
npm run check
```

DB migration がある場合は production DB に適用する。

### deploy

```sh
cd infra/cloudflare/app-worker
npm run deploy:production
```

内部ではこれが実行される。

```sh
wrangler deploy --env production
```

起きること:

- `src/index.ts` が `gurumeet` Worker として deploy される
- `frontend/build/web` が Workers Static Assets として upload される
- FastAPI container image が build / publish される
- `ASSETS_BUCKET` が `gurumeet-assets` に紐づく
- `gurumeet.net` が Worker に紐づく

### production 確認

見る順番:

```text
1. https://gurumeet.net で Flutter Web が表示される
2. https://gurumeet.net/edge/health が返る
3. https://gurumeet.net/api/health が FastAPI から返る
4. FastAPI が production DB に接続できる
5. /files/<known-key> が R2 production bucket から返る
6. 初期公開前は Cloudflare Access login が出る。一般公開後は Access login が出ない
```

## ローカル開発

ローカルでは Cloudflare に deploy しない。

基本:

```text
frontend dev server
FastAPI
PostgreSQL container
```

通常のローカル開発では、`backend/compose.yaml` で FastAPI コンテナと PostgreSQL コンテナを立て、frontend から FastAPI を直接呼ぶ。

ローカルの `.env`:

```text
frontend/.env
backend/.env
infra/cloudflare/app-worker/.dev.vars
```

`.env` 本体は commit しない。

通常のローカル開発:

```env
FRONTEND_PORT=3000
GURUMEET_API_BASE_URL=http://localhost:8000
```

frontend は `frontend/` で `make dev` を実行すると、`FRONTEND_PORT` のポートで起動する。

```sh
cd frontend
make dev
```

Worker 経由も含めて確認したい場合:

```env
GURUMEET_API_BASE_URL=http://localhost:8787/api
```

この場合だけ `infra/cloudflare/app-worker/` で `wrangler dev` を起動する。

`localhost:8787` の `wrangler dev` は通常 Cloudflare 本番アクセス数には入らない。`stg.gurumeet.net` や `gurumeet.net` を叩く確認は Cloudflare 上の Worker / Container / R2 を使うため課金対象になる。

## R2 の扱い

R2 は画像、PDF、添付ファイルなどの置き場所。

R2 に置くもの:

```text
avatar image
meeting material
export file
temporary upload
```

R2 に置かないもの:

```text
user table
meeting table
participant table
schedule table
```

DB には R2 key だけ保存する。

```text
users.avatar_r2_key = avatars/user_123.png
```

frontend は `/files/*` を読む。

```text
GET /files/avatars/user_123.png
```

Worker が `env.ASSETS_BUCKET.get("avatars/user_123.png")` で R2 から取得して返す。

upload は初期は API 経由でよい。

```text
POST /api/uploads/avatar
  -> FastAPI で認証と validation
  -> Worker または FastAPI から R2 put
  -> DB に R2 key を保存
```

大きいファイルや upload 頻度が増えたら署名付き URL を検討する。

## D1 について

現方針では主 DB は Neon PostgreSQL。

D1 は Cloudflare native な SQL DB なので魅力はある。ただし FastAPI container から `DATABASE_URL` と SQLAlchemy でそのまま使う DB ではない。

D1 が向くもの:

- Worker-only の小さい設定
- maintenance mode
- edge 側の軽い audit
- Worker だけで完結する小さい SQL データ

今回の主 DB にしにくい理由:

- FastAPI の DB 層を PostgreSQL / SQLAlchemy 前提で育てたい
- D1 は Worker binding 経由で使うのが自然
- Container から使うと Worker 経由の adapter が必要になりやすい
- migration と local dev の考えることが増える

D1 を採用するなら、最初から backend を Workers-native に寄せる判断が必要。FastAPI 資産を活かす方針とは別の設計になる。

## インフラ選定比較

候補は以下の4つ。

```text
1. Cloudflare Worker-only + D1
2. Cloudflare Container + Neon
3. Render only
4. Render + Neon
```

現時点の推奨は `2. Cloudflare Container + Neon`。

理由は、FastAPI / SQLAlchemy / Docker 開発を活かしつつ、Cloudflare の Worker / R2 / Access / WAF / Static Assets も使えるため。

### 比較表

| 案 | 構成 | 月額の目安 | メリット | デメリット | 向いている判断 |
| --- | --- | ---: | --- | --- | --- |
| 1. Worker-only + D1 | Cloudflare Worker + Python FastAPI + D1 + R2 | Free〜$5/月中心 | Cloudflare-native。Container課金なし。D1/R2/KV/Accessを自然に使える | SQLAlchemy/Alembicを捨てる寄り。raw SQL運用。Python Workerのライブラリ制限あり | Cloudflare学習最優先。DB層を作り直せる |
| 2. Container + Neon | Cloudflare Worker + Workers Container + FastAPI + Neon + R2 | $5〜$10/月目安 | FastAPI/SQLAlchemy/Dockerを活かせる。Cloudflareも使い倒せる。NeonはPostgresなので逃げやすい | Workers Paid $5必須。Container active timeで従量。Neonも無料枠超過あり | 今の第一候補。Cloudflareも既存backendも活かしたい |
| 3. Render only | Render Web Service + Render Postgres | $13/月〜目安 | 一番素直。FastAPI/SQLAlchemy/Docker/Postgresが自然。料金が読みやすい | Cloudflare活用は薄い。無料枠は本番向きではない。最小有料がやや高い | とにかく普通に早く出したい |
| 4. Render + Neon | Render Web Service + Neon Postgres | $7/月〜目安 | Renderの素直さとNeon無料枠を使える。Postgresなので移行しやすい | Render/Neon/Cloudflareで管理先が分かれる。無料枠の監視が必要 | Renderの簡単さを取りつつDBコストを抑えたい |

### 料金の見方

`1. Worker-only + D1`:

```text
Cloudflare Workers Free:
  100,000 requests/day

Cloudflare Workers Paid:
  $5/month
  10,000,000 requests/month included
  30,000,000 CPU ms/month included

D1:
  Free/Paid とも初期には十分な無料枠がある
```

Container を使わないため、Cloudflare Containers の active time 課金はない。

`2. Container + Neon`:

```text
Cloudflare Workers Paid:
  $5/month required

Cloudflare Containers:
  active running time に応じて memory / CPU / disk が従量課金
  included usage 内なら追加なしの可能性あり

Neon Free:
  100 CU-hours/month/project
  0.5 GB storage/project
  idle after 5 minutes
```

初期は $5 近くで収まる可能性はあるが、production traffic が継続的に来ると $5固定では見ない。

`3. Render only`:

```text
Render Web Service:
  Starter $7/month 目安

Render Postgres:
  Basic-256mb $6/month 目安

合計:
  $13/month 目安
```

追加で outbound bandwidth、build pipeline minutes、Postgres storage が増える可能性がある。

`4. Render + Neon`:

```text
Render Web Service:
  Starter $7/month 目安

Neon:
  Free枠内なら $0

合計:
  $7/month 目安
```

Neon が足りなくなったら Launch plan の usage-based billing へ移る。Postgres なので `pg_dump` / `pg_restore` や logical replication で逃げやすい。

### 重要な注意点

- `1. Worker-only + D1` は安くて Cloudflare-native だが、SQLAlchemy ORM は基本使わない。D1 binding + raw SQL + repository の設計になる。
- `2. Container + Neon` は今の backend 資産を活かせるが、billing alert は必須。`max_instances = 1`、最小 instance、短め `sleepAfter` から始める。
- `3. Render only` は一番わかりやすいが、無料枠は本番前提にしない。Free Web Service は idle sleep、Free Postgres は期限つき。
- `4. Render + Neon` は安く始めやすいが、管理先が Render と Neon に分かれる。Cloudflare を使うならさらに Cloudflare も加わる。
- R2 を使う場合、どの案でも DB には file body ではなく R2 key を保存する。
- 将来移行しやすいのは Postgres 系の `2`, `3`, `4`。D1 の `1` は Cloudflare-native だが、Postgres へ戻す時は DB層の作り替えが大きい。
- 複数人開発では、shared staging DB を日常開発に使わせない。local DB / preview DB / staging DB / production DB を分ける。

### 判断

今の優先順位が以下なら `2. Container + Neon` で進める。

```text
Cloudflareを使いたい
FastAPI/SQLAlchemyを活かしたい
Docker開発を捨てたくない
$5〜$10/month 程度の初期コストは許容できる
```

以下なら `3. Render only` にする。

```text
Cloudflareの学習より、普通に早く出す方を優先する
料金の読みやすさを優先する
Render内でWeb ServiceとPostgresをまとめたい
```

以下なら `1. Worker-only + D1` にする。

```text
SQLAlchemyを捨ててもよい
raw SQL運用を受け入れる
Cloudflare-native を最優先する
Container課金を避けたい
```

## Pages に分ける判断

今は Pages を使わず Worker 一本で始める。

Pages に分けるべきタイミング:

- frontend だけを頻繁に deploy / rollback したい
- PR ごとの frontend preview URL が必要
- frontend と backend の担当者やレビュー責任者が分かれる
- UI 修正を API / container deploy と独立させたい
- staging frontend と staging API の組み合わせを QA したい

分けないメリット:

- Cloudflare project が少ない
- deploy pipeline が少ない
- frontend と API が同一 origin になる
- CORS が楽
- staging 全体を Access で守りやすい

分けないデメリット:

- UI だけの変更でも Worker deploy になる
- frontend preview が弱い
- frontend rollback と backend rollback が一体になりやすい

今の規模では Worker 一本で始めてよい。frontend 運用が重くなったら Pages に分ける。

## 最初の PR でやる範囲

最初の PR は repo 側の土台だけでよい。

含める:

```text
backend/Dockerfile.cloudflare
backend/.env.example
infra/cloudflare/app-worker/package.json
infra/cloudflare/app-worker/tsconfig.json
infra/cloudflare/app-worker/wrangler.jsonc
infra/cloudflare/app-worker/src/index.ts
infra/cloudflare/app-worker/.dev.vars.sample
docs/reference/clouflare-construct.md
```

まだやらなくてよい:

```text
production deploy
GitHub Actions 化
D1 migration
Queues / Cron / KV
Pages project 作成
R2 helper の過剰な分割
署名付き URL
Terraform / Pulumi
```

まずは staging に手動 deploy できるところまで持っていく。
