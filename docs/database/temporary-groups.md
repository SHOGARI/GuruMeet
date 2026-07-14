# temporary_groups

一時グループのUUID、手入力用コード、有効期限を保存するテーブル。

| column | type | null | description |
| --- | --- | --- | --- |
| `id` | `UUID` | no | URL共有用の推測困難な識別子。アプリ側で `uuid4` を生成する。 |
| `code` | `CHAR(5)` | no | 手入力参加用の5桁英数字コード。unique制約あり。 |
| `creator_id` | `VARCHAR(128)` | yes | 作成者識別子。認証連携前の任意フィールド。 |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | no | DB側の `now()` で作成日時を保存する。 |
| `expires_at` | `TIMESTAMP WITH TIME ZONE` | no | 有効期限。デフォルトは作成から24時間後。 |

## Constraints and Indexes

| name | target | purpose |
| --- | --- | --- |
| primary key | `id` | UUIDで一意に取得する。 |
| `uq_temporary_groups_code` | `code` | 手入力コードの重複を防ぐ。 |
| `ix_temporary_groups_code` | `code` | コード参加APIの検索用。 |
| `ix_temporary_groups_expires_at` | `expires_at` | 期限切れ判定と削除処理用。 |

## 有効期限

一時グループは `expires_at > now` の場合のみ有効。

API検索では必ず `expires_at > now` を条件に含める。期限切れ行がDBに残っていても、取得・参加はできない。

## 期限切れ行の削除

期限切れ行は後処理で物理削除する。

```sh
cd backend
make cleanup-temporary-groups
```

内部ではSQLAlchemy ORMで以下の条件に一致する行を削除する。

```python
TemporaryGroup.expires_at <= datetime.now(UTC)
```

削除ジョブが遅れても、API側の有効期限判定により期限切れグループは利用不可のまま。

## Alembic

`temporary_groups` は以下のmigrationで作成する。

```text
backend/alembic/versions/202607150001_create_temporary_groups.py
```

既存DB構成は `feature/setup-db-etc` の方針に合わせ、`POSTGRES_*` 環境変数からDB URLを組み立てる。

