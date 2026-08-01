# Migration

DB定義を変更するときのAlembic運用メモ。

現在のrevision headは `202608010001`。現行schemaは
[`../database/`](../database/) を参照する。

このrepoでは、**merge前のfeature branchではmigrationを最終形に整理する**。  
試行錯誤のmigrationを全部残すより、merge時点で機能単位の少ないmigrationになっている方を優先する。

## 基本方針

| 状況 | 方針 |
| --- | --- |
| merge前のfeature branch | migrationを整理してよい |
| merge前で、まだ誰のDBにも適用していない | migration fileを編集・削除してよい |
| merge前で、自分のローカルDBにだけ適用済み | migration fileを整理してよい。ただしDB側のrevision調整が必要 |
| shared DB / staging / productionに適用済み | 既存migrationは編集・削除しない。forward migrationを追加する |
| develop / mainにmerge済み | 既存migrationは編集・削除しない。forward migrationを追加する |

## なぜmerge前に整理するか

開発中は、設計変更で以下のようなmigrationが増えやすい。

```text
create temporary_groups
add payload
drop payload
alter code from 4 chars to 5 chars
```

merge前なら、この履歴をそのまま残す必要は薄い。最終的には以下のように1本へまとめる方が読みやすい。

```text
create temporary_groups
```

最終migrationには、merge時点の正しいDB定義だけを入れる。

## 追加

テーブルやカラムを追加するときは、まずmigrationを作る。

```sh
cd backend
alembic revision -m "create temporary groups"
```

手書きまたはautogenerateで内容を作り、実行する。

```sh
make migrate
```

## merge前の整理

merge前にDB定義が変わった場合は、追加migrationを増やすより、既存のfeature用migrationを最終形へ直す。

例:

```text
変更前:
- code CHAR(4)
- payload JSONB

変更後:
- code CHAR(5)
- payloadなし
```

この場合、merge前なら以下のように最初のmigrationを直接直してよい。

```python
op.create_table(
    "temporary_groups",
    sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
    sa.Column("code", sa.CHAR(length=5), nullable=False),
    sa.Column("creator_id", sa.String(length=128), nullable=True),
    sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
    sa.PrimaryKeyConstraint("id"),
    sa.UniqueConstraint("code", name="uq_temporary_groups_code"),
)
```

一時的に作った以下のようなmigrationは、merge前に削除してよい。

```text
drop temporary_groups payload
alter temporary_group code to 5 chars
```

## ローカルDBに適用済みの場合

自分のローカルDBに一時migrationを適用済みの場合、fileだけ消すとAlembicが壊れる。

典型的なエラー:

```text
FAILED: Can't locate revision identified by '202607150002'
```

これはDBの `alembic_version` が削除済みrevisionを指しているため。

### 手順A: DBを捨ててよい場合

ローカルDBのデータが不要なら、これが一番簡単。

```sh
cd backend
docker compose --env-file .env -f compose.yaml down -v
make dev
```

DB volumeを消して、現在のmigrationから作り直す。

### 手順B: DBを残したい場合

一時migration fileを消す前に、現存させたいrevisionへstampする。

```sh
cd backend
docker compose --env-file .env -f compose.yaml run --rm api alembic current
docker compose --env-file .env -f compose.yaml run --rm api alembic stamp <revision_to_keep>
```

例:

```sh
docker compose --env-file .env -f compose.yaml run --rm api alembic stamp 202607150001
```

その後、一時migration fileを削除して確認する。

```sh
make migrate
```

### 手順C: 先にfileを消してしまった場合

`alembic stamp` も失敗する場合は、DBの `alembic_version` を直接戻す。

```sh
docker compose --env-file .env -f compose.yaml exec db \
  psql -U gurumeet -d gurumeet \
  -c "UPDATE alembic_version SET version_num = '<revision_to_keep>' WHERE version_num = '<deleted_revision>';"
```

例:

```sh
docker compose --env-file .env -f compose.yaml exec db \
  psql -U gurumeet -d gurumeet \
  -c "UPDATE alembic_version SET version_num = '202607150001' WHERE version_num = '202607150002';"
```

確認:

```sh
docker compose --env-file .env -f compose.yaml exec db \
  psql -U gurumeet -d gurumeet \
  -c "SELECT * FROM alembic_version;"
```

その後:

```sh
make migrate
```

## merge後の変更

develop / mainにmerge済み、またはshared DB / staging / productionに適用済みのmigrationは編集・削除しない。

この場合は、必ずforward migrationを追加する。

カラム削除の例:

```python
def upgrade() -> None:
    op.drop_column("temporary_groups", "payload")


def downgrade() -> None:
    op.add_column(
        "temporary_groups",
        sa.Column("payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
```

テーブル削除の例:

```python
def upgrade() -> None:
    op.drop_table("temporary_groups")


def downgrade() -> None:
    # 必要なら再作成を書く
    pass
```

## 最終確認

merge前に確認すること。

```sh
cd backend
make migrate
```

必要ならローカルDBを作り直して、空DBからmigrationが通ることも確認する。

```sh
docker compose --env-file .env -f compose.yaml down -v
make dev
```

注意: `down -v` はDBデータを削除する。必要なデータがある環境では実行しない。
