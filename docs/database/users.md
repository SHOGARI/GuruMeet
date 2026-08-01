# users

将来の登録ユーザー向けに残っている基盤テーブル。現行の一時グループ機能は
`anonymous_users` を使っており、`users` を操作するAPIはまだない。

| column | type | null | description |
| --- | --- | --- | --- |
| `id` | `INTEGER` | no | 自動採番の主キー。 |
| `name` | `VARCHAR(255)` | no | ユーザー名。 |
| `email` | `VARCHAR(255)` | no | メールアドレス。unique制約あり。 |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | no | DB側の `now()` で作成日時を保存する。 |

## Alembic

```text
backend/alembic/versions/6724ca471deb_create_users_table.py
```
