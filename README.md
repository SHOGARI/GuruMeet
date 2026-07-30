<div align="center">

<img src="docs/assets/grumeet-icon.png" width="120" alt="GuruMeet logo">

# GuruMeet

食事会の店選びを、招待リンクとスワイプ投票で決めるアプリ。

<br>

[![Flutter](https://img.shields.io/badge/Flutter-Frontend-46A6FF?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Backend-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Cloudflare](https://img.shields.io/badge/Cloudflare-Deploy-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)](https://www.cloudflare.com)

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
| 🔗 招待URL / 5桁コードによる一時グループ参加 | ✅ implemented |
| 👤 匿名参加者トークンによる参加者識別 | ✅ implemented |
| 🗾 都道府県別の駅・市区町村候補検索 | ✅ implemented |
| 📍 現在地からの店舗検索 | ✅ implemented |
| 🍽️ Hot Pepper Gourmet API による店舗候補取得 | ✅ implemented |
| 👆 スワイプ投票と結果表示 | ✅ implemented |
| 🧹 期限切れ一時グループの cleanup | ✅ implemented |
| ☁️ Cloudflare Workers / Containers デプロイ | ✅ implemented |

## Tech Stack

| layer             | technology                                                  |
| ----------------- | ----------------------------------------------------------- |
| Frontend          | Flutter, Dart, Material 3                                   |
| Backend           | FastAPI, Pydantic, SQLAlchemy                               |
| Database          | PostgreSQL, Alembic                                         |
| Location master   | Geolonia 住所データ, 駅データ.jp                            |
| Restaurant search | Hot Pepper Gourmet API                                      |
| Infrastructure    | Cloudflare Workers, Workers Containers, R2, Neon PostgreSQL |

## Frontend

<div align="center">
  <a href="https://skillicons.dev">
    <img src="https://skillicons.dev/icons?i=flutter,dart&theme=light" alt="Flutter and Dart">
  </a>
</div>

`frontend/` は Flutter アプリです。
グループ作成、招待URL表示、参加、待機室、店舗候補のスワイプ、投票結果、店舗詳細表示を担当します。

使い心地はシンプルに保ちつつ、店選びの画面がちゃんと美味しそうに見えることを重視しています。
暖色を中心にした配色、写真が主役になるカード、迷わず次の操作へ進める導線で、食事会らしい温度感を出しています。

| area                      | files                                          |
| ------------------------- | ---------------------------------------------- |
| Screens                   | `frontend/lib/screens/`                        |
| API client / repositories | `frontend/lib/services/`                       |
| Models                    | `frontend/lib/models/`                         |
| Theme / shared widgets    | `frontend/lib/theme/`, `frontend/lib/widgets/` |

ローカルでは `frontend/.env` の値を `--dart-define` として渡します。
UI確認だけなら mock mode、backend とつなぐ場合は `GURUMEET_ENABLE_MOCKS=false` にします。

## Backend

<div align="center">
  <a href="https://skillicons.dev">
    <img src="https://skillicons.dev/icons?i=py,fastapi,postgres&theme=light" alt="Python, FastAPI, and PostgreSQL">
  </a>
</div>

`backend/` は FastAPI アプリです。
一時グループ、匿名参加者、地点検索、店舗候補取得、投票、期限切れ cleanup を担当します。

backend では、ただ店舗を並べるだけでなく、予算・人数・候補の偏りを考慮したレコメンドアルゴリズムを重視しています。
DB は一時グループ、参加者、投票、地点マスタを素直に扱えるように、PostgreSQL と SQLAlchemy / Alembic を前提に設計しています。

| area            | files                                 |
| --------------- | ------------------------------------- |
| API routes      | `backend/app/api/routes/`             |
| Schemas         | `backend/app/schemas/`                |
| Models          | `backend/app/models/`                 |
| Services        | `backend/app/services/`               |
| DB / migrations | `backend/app/db/`, `backend/alembic/` |

店舗検索はグループ作成時に実行します。
選択地点は `locations`、現在地や地図ピンは `custom_locations` を検索原点として扱います。

## Infra

<div align="center">
  <a href="https://skillicons.dev">
    <img src="https://skillicons.dev/icons?i=cloudflare,workers,docker,githubactions&theme=light" alt="Cloudflare, Workers, Docker, and GitHub Actions">
  </a>
</div>

`infra/` は Cloudflare と周辺運用の設定を置きます。
Flutter Web を Worker Static Assets で配信し、`/api/*` を Workers Container 上の FastAPI に流す構成です。

infra は「楽に開発する」と「Cloudflare を使い倒す」を意識しています。
deploy、環境変数、staging / production の分離を整えつつ、Discord webhook で実際に使われている感覚や障害の兆候を拾える運用にしています。

| area                  | files                          |
| --------------------- | ------------------------------ |
| Cloudflare Worker     | `infra/cloudflare/app-worker/` |
| Deploy commands       | `infra/cloudflare/Makefile`    |
| Cloudflare operations | `infra/cloudflare/README.md`   |
| Discord alerts        | `infra/discord/`               |

staging / production の secret 実値は Git に置かず、GitHub Environment secrets から deploy workflow 経由で渡します。

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
├── frontend/                     # Flutter app
│   ├── lib/
│   │   ├── screens/              # 画面
│   │   ├── services/             # API client / repositories
│   │   ├── models/               # UI/API models
│   │   ├── theme/                # 色・余白・Typography
│   │   └── widgets/              # 共通UI
│   ├── android/                  # Android project
│   ├── ios/                      # iOS project
│   └── web/                      # Web assets
│
├── backend/                      # FastAPI app
│   ├── app/
│   │   ├── api/routes/           # API endpoints
│   │   ├── schemas/              # request / response
│   │   ├── models/               # SQLAlchemy models
│   │   ├── services/             # business logic
│   │   ├── repositories/         # DB access
│   │   └── db/                   # DB session / base
│   ├── alembic/                  # migrations
│   ├── scripts/                  # location import scripts
│   └── tests/                    # backend tests
│
├── infra/                        # deploy / operations
│   ├── cloudflare/
│   │   └── app-worker/           # Worker entrypoint
│   └── discord/                  # Discord webhook integration
│
├── docs/                         # specs / design / reference
│   ├── api/                      # API specs
│   ├── database/                 # ER diagram and table docs
│   ├── designs/                  # design decisions
│   ├── reference/                # setup guides / external services
│   └── assets/                   # README / docs images
│
├── scripts/                      # repo-level helper scripts
└── README.md
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
