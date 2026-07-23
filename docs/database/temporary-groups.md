# temporary_groups

一時グループのUUID、手入力用コード、有効期限、希望条件を保存するテーブル。

| column | type | null | description |
| --- | --- | --- | --- |
| `id` | `UUID` | no | URL共有用の推測困難な識別子。アプリ側で `uuid4` を生成する。 |
| `code` | `CHAR(5)` | no | 手入力参加用の5桁英数字コード。unique制約あり。 |
| `creator_id` | `VARCHAR(128)` | yes | 作成者識別子。認証連携前の任意フィールド。 |
| `participant_count` | `INT` | yes | 参加人数。 |
| `location` | `VARCHAR(255)` | yes | 希望場所。 |
| `budget_min` | `INT` | yes | 予算下限。 |
| `budget_max` | `INT` | yes | 予算上限。 |
| `restaurant` | `JSONB` | yes | 選択済み、または候補の店舗情報。 |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | no | DB側の `now()` で作成日時を保存する。 |
| `expires_at` | `TIMESTAMP WITH TIME ZONE` | no | 有効期限。デフォルトは作成から24時間後。 |

## Constraints and Indexes

| name | target | purpose |
| --- | --- | --- |
| primary key | `id` | UUIDで一意に取得する。 |
| `uq_temporary_groups_code` | `code` | 手入力コードの重複を防ぐ。 |
| `ix_temporary_groups_code` | `code` | コード参加APIの検索用。 |
| `ix_temporary_groups_expires_at` | `expires_at` | 期限切れ判定と削除処理用。 |

## 参加人数

`participant_count` は必要人数を表す。現在の参加人数は `temporary_group_participants` の件数から計算する。

```sql
SELECT COUNT(*)
FROM temporary_group_participants
WHERE temporary_group_id = :group_id;
```

満員判定は `joined_participant_count >= participant_count` で行う。`is_full` はDBカラムとしては持たず、APIレスポンスで返す。

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
backend/alembic/versions/202607230001_add_temporary_group_details.py
```

既存DB構成は `feature/setup-db-etc` の方針に合わせ、`POSTGRES_*` 環境変数からDB URLを組み立てる。
