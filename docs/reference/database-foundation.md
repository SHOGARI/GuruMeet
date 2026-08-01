# Database Foundation

FastAPI、SQLAlchemy、Alembic、PostgreSQLの現在の接続構成。
テーブル定義は [`../database/`](../database/) を参照する。

## 構成

```text
FastAPI route
  -> get_db / SessionLocal
  -> service
  -> repository
  -> SQLAlchemy model
  -> PostgreSQL

Alembic
  -> Base.metadata
  -> versions/*
  -> PostgreSQL schema
```

| path | role |
| --- | --- |
| `backend/app/db/database_url.py` | `DATABASE_URL` または `POSTGRES_*` から接続URLを作る。 |
| `backend/app/db/database.py` | SQLAlchemy engineと `SessionLocal` を作る。 |
| `backend/app/db/session.py` | FastAPI dependencyとしてSessionを提供する。 |
| `backend/app/db/base.py` | ORM model共通の `Base`。 |
| `backend/app/models/` | 現行テーブルに対応するORM model。 |
| `backend/app/repositories/` | query、lock、集計、永続化処理。 |
| `backend/alembic/env.py` | AlembicからmetadataとDB接続を読む。 |
| `backend/alembic/versions/` | schema変更履歴。 |

## 接続URL

`DATABASE_URL` があれば最優先する。`postgresql://` は実行時に
`postgresql+psycopg://` へ変換する。

`DATABASE_URL` がなければ以下から組み立てる。

```text
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_HOST
POSTGRES_PORT
POSTGRES_DB
```

ローカルComposeは `POSTGRES_*`、Cloudflare ContainerはNeonの
`DATABASE_URL` を使う。

## Session

通常のrouteでは `Depends(get_db)` を使い、request終了時にSessionを閉じる。
一時グループ作成ではHot Pepper API待ちの間にDB Sessionを保持しないため、
外部検索後の同期処理をthread poolへ移し、その内部で `SessionLocal` を開く。

transactionのcommit / rollbackはservice層が処理単位で行う。

## Models

現行model:

```text
User
AnonymousUser
Location
MunicipalityLocation
StationLocation
CustomLocation
TemporaryGroup
TemporaryGroupParticipant
TemporaryGroupVote
```

`Meeting` modelとusers / meetings routerには、現在有効な機能実装はない。

## Migration

適用:

```sh
cd backend
make migrate
```

現在のheadは `202608010001`。空DBではusers作成から一時グループ、地点、投票、
店舗決定カラムまで順番に適用する。

既存migrationを編集できる条件やshared環境でのforward migration方針は
[`../migration/migration.md`](../migration/migration.md) を参照する。

## 現在のテーブル

```text
users
anonymous_users
locations
municipality_locations
station_locations
custom_locations
temporary_groups
temporary_group_participants
temporary_group_votes
alembic_version
```
