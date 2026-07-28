# Cloudflare 運用 README

このディレクトリは GuruMeet の Cloudflare デプロイ / 運用コマンドをまとめる場所。

実体の Worker プロジェクトは `app-worker/`。

```text
infra/cloudflare/
  Makefile
  README.md
  app-worker/
    wrangler.jsonc
    src/index.ts
    package.json
```

## 採用構成

```text
フロントエンド:
  Cloudflare Workers Static Assets

入口:
  Cloudflare Worker

バックエンド:
  Cloudflare Workers Container
  FastAPI + uvicorn

データベース:
  Neon PostgreSQL

ファイル置き場:
  Cloudflare R2

アクセス制御:
  Cloudflare Access
```

## 環境対応

```text
develop ブランチ -> staging    -> stg.gurumeet.net -> Neon staging ブランチ
main ブランチ    -> production -> gurumeet.net     -> Neon production ブランチ
```

Cloudflare の env 名は `staging` / `production` に統一する。`product` ではなく `production` を使う。

## 初回セットアップ確認

Cloudflare ログイン確認:

```sh
cd infra/cloudflare
make whoami
```

依存関係の install:

```sh
cd infra/cloudflare
make install
```

R2 bucket 確認:

```sh
cd infra/cloudflare
make r2-list
```

想定する bucket:

```text
gurumeet-staging-assets
gurumeet-assets
```

## ローカル開発環境

通常の backend ローカル開発は `backend/compose.yaml` を使う。

```text
api container
  -> db container
```

この場合、FastAPI から PostgreSQL への接続先は Docker Compose の service 名になる。

```env
DATABASE_URL=postgresql://gurumeet:change_me@db:5432/gurumeet
```

これは `backend/.env.example` 側の値。

一方、`infra/cloudflare/app-worker/.dev.vars` は `wrangler dev` 用。

`wrangler dev` の Worker / Container local runtime は、`backend/compose.yaml` の Docker Compose network と同じとは限らない。そのため `db:5432` が見えない場合がある。

その場合は、ホストマシンに公開されている PostgreSQL を見る。

```env
DATABASE_URL=postgresql://gurumeet:change_me@host.docker.internal:5432/gurumeet
```

整理:

```text
backend/compose.yaml で普通に開発:
  DB host は db

Mac 上の process から直接 DB を見る:
  DB host は localhost

wrangler dev の Container からホスト側 DB を見る:
  DB host は host.docker.internal
```

## シークレット登録

Neon の connection string は Git に書かない。

staging:

```sh
cd infra/cloudflare
make secret-staging
```

入力する値:

```text
Neon staging ブランチの connection string
```

production:

```sh
cd infra/cloudflare
make secret-production
```

入力する値:

```text
Neon production ブランチの connection string
```

## 手動デプロイ

staging:

```sh
cd infra/cloudflare
make deploy-staging
```

内部で行うこと:

```text
frontend/build/web を作る
Worker の型チェックをする
wrangler deploy --env staging を実行する
```

production:

```sh
cd infra/cloudflare
make deploy-production
```

内部で行うこと:

```text
frontend/build/web を作る
Worker の型チェックをする
wrangler deploy --env production を実行する
```

## GitHub Actions

`.github/workflows/deploy-cloudflare.yml` で以下の運用にする。

```text
develop push -> staging デプロイ
main push    -> production デプロイ
```

`.github/workflows/ci.yml` で以下の検証をする。

```text
任意 branch -> develop の pull request
develop -> main の pull request
  -> backend 構文確認
  -> frontend analyze / test
  -> Worker 型チェック
```

GitHub Actions に必要な repository secrets:

```text
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
```

### Cloudflare API Token の作成

Cloudflare Dashboard で作る。

```text
My Profile
  -> API Tokens
  -> Create Token
  -> Custom token
  -> Get started
```

Token name:

```text
gurumeet-github-actions-deploy
```

Permissions:

```text
Account - Workers Scripts - Edit
Account - Containers - Edit
Account - Workers R2 Storage - Edit
Account - Account Settings - Read
Zone - Workers Routes - Edit
Zone - SSL and Certificates - Edit
Zone - Zone - Read
```

Account Resources:

```text
Include -> <Cloudflare account>
```

今回の設定例:

```text
Include -> Med.rk000@gmail.com's Account
```

Zone Resources:

```text
Include -> Specific zone -> gurumeet.net
```

Client IP Address Filtering:

```text
空欄
```

理由:

```text
GitHub Actions の outbound IP は固定しづらいため
```

TTL:

```text
空欄
```

作成後に表示される token は、その場でしか確認できない。コピーして GitHub repository secret に登録する。

```text
Secret name: CLOUDFLARE_API_TOKEN
Secret value: 作成した Cloudflare API token
```

### Cloudflare アカウント ID

確認方法:

```sh
cd infra/cloudflare/app-worker
npx wrangler whoami
```

GitHub repository secret に登録する。

```text
Secret name: CLOUDFLARE_ACCOUNT_ID
Secret value: Cloudflare account ID
```

注意:

```text
前後に空白を入れない
32文字の小文字 hex 文字列だけを入れる
例: abcdef1234567890abcdef1234567890
```

値の例:

```text
<Cloudflare account ID>
```

アプリ用の実行時 secret は GitHub Secrets ではなく Cloudflare Wrangler secret に登録する。

staging / production それぞれで必要:

```text
DATABASE_URL
HOTPEPPER_API_KEY
PARTICIPANT_TOKEN_HASH_SECRET
INTERNAL_TASK_SECRET
```

`PARTICIPANT_TOKEN_HASH_SECRET` と `INTERNAL_TASK_SECRET` は以下のような長いランダム値を使う。

```sh
openssl rand -hex 32
```

登録コマンド:

```sh
cd infra/cloudflare
make secret-staging
make secret-production
```

公開時のCORSは `wrangler.jsonc` の環境別 `CORS_ALLOW_ORIGINS` で制限する。

```text
staging:    https://stg.gurumeet.net
production: https://gurumeet.net
```

## Cloudflare Access

Cloudflare Access は Cloudflare Dashboard で管理する。

```text
Zero Trust
  -> Access controls
  -> Applications
```

Access をかけた domain は、通常の `curl` では確認しづらい。

ブラウザで確認する:

```text
https://stg.gurumeet.net
https://gurumeet.net
```

Access を外す場合:

```text
Zero Trust
  -> Access controls
  -> Applications
  -> 対象 application を disable / delete
```

## ログ確認

staging:

```sh
cd infra/cloudflare
make tail-staging
```

production:

```sh
cd infra/cloudflare
make tail-production
```

Cloudflare Dashboard でも確認できる。

```text
Workers & Pages
  -> gurumeet-staging / gurumeet
  -> Logs / Metrics
```

Container の挙動も Worker 経由で確認する。

## Neon DB を TablePlus で見る

Neon は PostgreSQL なので、TablePlus から接続できる。

Neon Dashboard で connection string を確認する。

```text
Project: gurumeet
  -> Connect
  -> Branch: staging / production
  -> Connection string
```

staging を見る場合:

```text
Branch: staging
```

production を見る場合:

```text
Branch: production
```

connection string は secret なので Git / docs / chat に貼らない。

形式:

```text
postgresql://USER:PASSWORD@HOST/DATABASE?sslmode=require
```

分解:

```text
USER:
  postgresql:// の後から : まで

PASSWORD:
  : の後から @ まで

HOST:
  @ の後から / まで

DATABASE:
  / の後から ? まで
```

例:

```text
postgresql://gurumeet_owner:abc123xyz@ep-example.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
```

TablePlus に入れる値:

```text
Host:
  ep-example.ap-southeast-1.aws.neon.tech

Port:
  5432

User:
  gurumeet_owner

Password:
  abc123xyz

Database:
  neondb

SSL:
  Require
```

おすすめ接続名:

```text
Gurumeet Neon Staging
Gurumeet Neon Production
```

注意:

```text
staging と production の connection string を間違えない
production に TablePlus から直接 UPDATE / DELETE しない
production は将来的に read-only role で見るのが望ましい
```

## 疎通確認

staging:

```text
https://stg.gurumeet.net
https://stg.gurumeet.net/edge/health
https://stg.gurumeet.net/api/health
```

production:

```text
https://gurumeet.net
https://gurumeet.net/edge/health
https://gurumeet.net/api/health
```

確認すること:

```text
Access login が出る
frontend が表示される
/edge/health が Worker から返る
/api/health が FastAPI container から返る
```

注意:

```text
/api/health を外部監視で常時叩かない
監視するなら /edge/health を使う
```

`/api/health` は Container を起こすため、Container active time の課金に影響する。

## 課金ガード

初期方針:

```text
max_instances = 1
instance_type = lite
sleepAfter = 5m
```

Cloudflare Dashboard で billing alert / usage を確認する。

```text
Billing
Workers usage
Containers usage
R2 usage
```

Neon も usage を確認する。

```text
Compute hours
Storage
Branch
```

## 自動削除とバックアップ

一時グループの期限切れデータは Cloudflare Cron Trigger から毎時1回、
Backend Container の `/internal/cleanup-expired-temporary-groups` を呼んで削除する。

Neon PostgreSQL のバックアップ / PITR は Neon Dashboard 側で有効化・確認する。
本番公開前に最低限以下を確認する。

```text
staging branch と production branch が分離されている
production branch のバックアップ / restore 手順を確認済み
復元テスト用 branch を作成して restore できる
```
