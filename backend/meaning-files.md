# データベース基盤の概要

FastAPIからPostgreSQLを利用するために、SQLAlchemyとAlembicを使ったデータベース基盤を作成しました。

## 主なファイルと役割

- `app/db/database.py`
  - `.env`の`DATABASE_URL`を読み込みます。
  - `engine`でPostgreSQLへの接続を管理します。
  - `SessionLocal`でDB操作用のセッションを作成します。

- `app/db/base.py`
  - ORMモデルが共通で継承する`Base`を定義します。
  - モデルのテーブル情報は`Base.metadata`に集約されます。

- `app/models/user.py`
  - PostgreSQLの`users`テーブルに対応する`User`モデルです。
  - `id`、`name`、`email`、`created_at`を定義しています。

- `alembic.ini` / `alembic/env.py`
  - AlembicがDBへ接続し、ORMモデルの変更を検出するための設定です。

- `alembic/versions/6724ca471deb_create_users_table.py`
  - `users`テーブルを作成するマイグレーションファイルです。
  - `upgrade()`で作成し、`downgrade()`で削除できます。

## Alembicを使う理由

ORMモデルを書いただけでは、PostgreSQLに実際のテーブルは作成されません。
AlembicはモデルとDBの差分からマイグレーションファイルを作り、その内容をDBへ適用します。

## 実行した主なコマンド

```bash
docker-compose --env-file .env -f compose.yaml up -d --build
docker-compose --env-file .env -f compose.yaml exec api alembic revision --autogenerate -m "create users table"
docker-compose --env-file .env -f compose.yaml exec api alembic upgrade head
docker-compose --env-file .env -f compose.yaml exec db psql -U gurumeet -d gurumeet -c "\dt"
```

## 実行結果

PostgreSQLに次のテーブルが作成されました。

- `users`: ユーザーデータを保存するテーブル
- `alembic_version`: 適用済みマイグレーションをAlembicが管理するテーブル

今回の作業では、CRUD処理やAPIエンドポイントは追加していません。
