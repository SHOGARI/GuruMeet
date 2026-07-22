# データベース基盤の概要

FastAPIからPostgreSQLを利用するために、SQLAlchemyとAlembicを使ったデータベース基盤を作成しました。

## データベースへ接続する流れ

```
FastAPI
    │
    ▼
database.py（DB接続）
    │
    ▼
Base（ORMの土台）
    │
    ▼
Userモデル（テーブル定義）
    │
    ▼
Alembic（マイグレーション）
    │
    ▼
PostgreSQL
```

---

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
  - `upgrade()`でテーブルを作成します。
  - `downgrade()`でテーブルを削除します。

---

## 各ファイルの役割

### engine

データベースへ接続するための窓口です。
FastAPIからPostgreSQLへ接続するときに利用されます。

### SessionLocal

データベース操作を行うためのSessionを作成します。

今後は次のように利用します。

```python
db = SessionLocal()
```

### Base

ORMモデルが共通で継承するクラスです。

Alembicは`Base.metadata`を参照して、
テーブルの追加・変更・削除を検出します。

---

## Alembicを使う理由

ORMモデルを書いただけでは、PostgreSQLに実際のテーブルは作成されません。

AlembicはORMモデルとDBの差分からマイグレーションファイルを作成し、
その内容をPostgreSQLへ適用します。

---

## 実行した主なコマンド

```bash
docker-compose --env-file .env -f compose.yaml up -d --build
docker-compose --env-file .env -f compose.yaml exec api alembic revision --autogenerate -m "create users table"
docker-compose --env-file .env -f compose.yaml exec api alembic upgrade head
docker-compose --env-file .env -f compose.yaml exec db psql -U gurumeet -d gurumeet -c "\dt"
```

---

## 実行結果

PostgreSQLに次のテーブルが作成されました。

- `users`
  - ユーザーデータを保存するテーブルです。

- `alembic_version`
  - Alembicが適用済みのマイグレーションを管理するためのテーブルです。

---

## 今後実装する内容

今回はデータベース基盤の構築までを行いました。

今後は以下の機能を追加していきます。

- CRUD処理（追加・取得・更新・削除）
- APIエンドポイント
- Pydantic Schema
- サービス層の実装