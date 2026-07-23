# Database Overview

backendはPostgreSQLを使用する。Redisは使わない。

## 接続方針

DB URLは直接環境変数で渡さず、`POSTGRES_*` から組み立てる。

| env | purpose |
| --- | --- |
| `POSTGRES_DB` | DB名 |
| `POSTGRES_USER` | DBユーザー |
| `POSTGRES_PASSWORD` | DBパスワード |
| `POSTGRES_HOST` | DB host。compose内では `db` |
| `POSTGRES_PORT` | DB port |

実装:

```text
backend/app/db/database_url.py
```

## 現在のテーブル

| table | purpose | detail |
| --- | --- | --- |
| `users` | user情報 | 既存setup-db-etc由来 |
| `anonymous_users` | 登録なし参加者の匿名識別子 | [Anonymous Users Table](./anonymous-users.md) |
| `temporary_groups` | 一時グループのUUID、5桁コード、有効期限、希望条件 | [Temporary Groups Table](./temporary-groups.md) |
| `temporary_group_participants` | 一時グループと匿名参加者の参加関係 | [Temporary Group Participants Table](./temporary-group-participants.md) |

## Migration

DB schema変更はAlembicで管理する。

運用方針は [Migration](../migration/migration.md) を参照。
