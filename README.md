<div align="center">

<img src="docs/assets/grumeet-icon.png" width="120" alt="GuruMeet logo">

# GuruMeet

食事会の店選びを、招待リンクとスワイプ投票で決めるアプリ。

<br>

<a href="https://skillicons.dev">
  <img
    src="https://skillicons.dev/icons?i=flutter,dart,py,fastapi,postgres,cloudflare,workers,docker,githubactions&theme=light&perline=9"
    alt="Flutter, Dart, Python, FastAPI, PostgreSQL, Cloudflare Workers, Docker, GitHub Actions"
  >
</a>

</div>

---

## Overview

GuruMeet は、複数人で飲食店を決めるための一時グループアプリです。

幹事が人数・場所・予算を入れてグループを作成し、参加者は共有URLから入室します。
backend は地点情報と Hot Pepper Gourmet API を使って店舗候補を取得し、
frontend は候補をスワイプして投票・結果表示までを担当します。

```text
グループ作成
  -> 招待URLを共有
  -> 参加者が入室
  -> 店舗候補をスワイプ
  -> 投票結果から店を決定
  -> 店舗詳細 / Google Maps を確認
```

## Features

| feature | status |
| --- | --- |
| 招待URL / 5桁コードによる一時グループ参加 | implemented |
| 匿名参加者トークンによる参加者識別 | implemented |
| 都道府県別の駅・市区町村候補検索 | implemented |
| 現在地からの店舗検索 | implemented |
| Hot Pepper Gourmet API による店舗候補取得 | implemented |
| スワイプ投票と結果表示 | implemented |
| 期限切れ一時グループの cleanup | implemented |
| Cloudflare Workers / Containers デプロイ | in progress |

## Architecture

```text
Flutter Web / iOS / Android
        |
        | JSON API
        v
FastAPI backend
        |
        | SQLAlchemy / Alembic
        v
PostgreSQL

External services:
  Hot Pepper Gourmet API
  Geolonia address data
  Ekidata station data

Deploy target:
  Cloudflare Worker
  Cloudflare Workers Container
  Cloudflare R2
  Neon PostgreSQL
```

## Tech Stack

| layer | technology |
| --- | --- |
| Frontend | Flutter, Dart, Material 3 |
| Backend | FastAPI, Pydantic, SQLAlchemy |
| Database | PostgreSQL, Alembic |
| Location master | Geolonia 住所データ, 駅データ.jp |
| Restaurant search | Hot Pepper Gourmet API |
| Infrastructure | Cloudflare Workers, Workers Containers, R2, Neon PostgreSQL |

## Quick Start

### Backend

```sh
cd backend
cp .env.example .env
make dev
make migrate
```

API:

```text
http://localhost:8000
http://localhost:8000/docs
```

Hot Pepper API を使わずにローカル確認する場合は、`backend/.env` の
`GURUMEET_ENABLE_MOCK_RESTAURANTS=true` を使います。

### Frontend

```sh
cd frontend
cp .env.example .env
make install
make dev
```

Chrome で起動する場合:

```sh
cd frontend
make dev-chrome
```

## Environment Check

ローカル起動前に、必要な環境変数が空でないか確認できます。
値そのものは表示しません。

```sh
cd backend
make check-env

cd ../frontend
make check-env
```

本番・staging の secret 実値は Git に書きません。
GitHub Actions / Cloudflare / Neon の設定は [infra/cloudflare/README.md](./infra/cloudflare/README.md) を参照してください。

## Location Master

地点検索は `locations` を親テーブルにし、駅と市区町村の固有情報を分けて保存します。
CSV本体や有料データは Git 管理しません。

```sh
cd backend
./scripts/import_location_master_local.sh
```

詳細:

- [External Data And Services](./docs/reference/external-services.md)
- [Location Data Import](./docs/reference/location-data-import.md)
- [Location Data Versions](./docs/reference/location-data-versions.md)

## Project Layout

```text
gurumeet/
  frontend/          Flutter app
  backend/           FastAPI app, SQLAlchemy models, Alembic migrations
  infra/
    cloudflare/      Worker / Container deploy settings
    discord/         Discord alert integration
  docs/
    api/             API specs
    database/        ER diagram and table docs
    designs/         design decisions
    reference/       setup guides, external services, operation notes
```

## Documentation

- [Docs Index](./docs/README.md)
- [API](./docs/api/)
- [Database](./docs/database/)
- [Designs](./docs/designs/)
- [Reference](./docs/reference/)
- [Backend README](./backend/README.md)
- [Frontend README](./frontend/README.md)
- [Cloudflare README](./infra/cloudflare/README.md)

## Quality Checks

Backend:

```sh
cd backend
python -m unittest discover -s tests
```

Frontend:

```sh
cd frontend
make format
make analyze
make test
```

backend tests は Python 依存を入れた環境で実行してください。
