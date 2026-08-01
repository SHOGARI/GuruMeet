# Database Overview

backendはPostgreSQLを使用する。Redisは使わない。SQLAlchemy modelと
適用済みAlembic migrationをschemaのsource of truthとする。

## 接続方針

ローカルComposeでは `POSTGRES_*` から接続URLを組み立てる。
staging / productionでは `DATABASE_URL` を優先して使う。

| env | purpose |
| --- | --- |
| `POSTGRES_DB` | DB名 |
| `POSTGRES_USER` | DBユーザー |
| `POSTGRES_PASSWORD` | DBパスワード |
| `POSTGRES_HOST` | DB host。compose内では `db` |
| `POSTGRES_PORT` | DB port |
| `DATABASE_URL` | 指定時は `POSTGRES_*` より優先する完全な接続URL。 |

実装:

```text
backend/app/db/database_url.py
```

## 現在のテーブル

| table | purpose | detail |
| --- | --- | --- |
| `users` | 将来の登録ユーザー用。現行APIでは未使用 | [Users Table](./users.md) |
| `anonymous_users` | 登録なし参加者の匿名識別子 | [Anonymous Users Table](./anonymous-users.md) |
| `locations` | 駅・市区町村の地点マスタ | [Location Tables](./locations.md) |
| `municipality_locations` | 市区町村地点の固有情報 | [Location Tables](./locations.md) |
| `station_locations` | 駅地点の固有情報 | [Location Tables](./locations.md) |
| `custom_locations` | 現在地・地図ピンなど地点マスタ外の検索原点 | [Custom Locations Table](./custom-locations.md) |
| `temporary_groups` | 一時グループのUUID、5桁コード、有効期限、希望条件 | [Temporary Groups Table](./temporary-groups.md) |
| `temporary_group_participants` | 一時グループと匿名参加者の参加関係 | [Temporary Group Participants Table](./temporary-group-participants.md) |
| `temporary_group_votes` | 匿名参加者ごとの店舗候補への投票 | [Temporary Group Votes Table](./temporary-group-votes.md) |
| `alembic_version` | 適用済みAlembic revision | Alembicが管理するためアプリケーションから操作しない。 |

## Migration

DB schema変更はAlembicで管理する。

運用方針は [Migration](../migration/migration.md) を参照。
