# backend

ここはbackendの処理を書くフォルダです

Flutter frontend に対して JSON API を提供します。DB 操作や認証、アプリケーション側の処理は backend 側に閉じます。

## フォルダ構成

```text
backend/
  app/
    main.py
    api/
      routes/
        health.py
        users.py
        meetings.py
    core/
      config.py
    schemas/
      user.py
      meeting.py
    models/
      user.py
      meeting.py
    services/
      meeting_service.py
    db/
      session.py
  compose.yaml
  docker/
    Dockerfile
    Dockerfile.dockerignore
  Makefile
  requirements.txt
  README.md
```

## 各フォルダの役割

- `app/main.py`: FastAPI アプリの作成と router 登録を行う入口。
- `app/api/routes/`: Flutter から呼ばれる API endpoint を置く。URL ごとの処理はここから始まる。
- `app/core/`: アプリ全体の設定を置く。環境変数、認証設定、共通設定などはここに寄せる。
- `app/schemas/`: API の request / response の型を置く。Flutter と JSON でやり取りする形はここで定義する。
- `app/models/`: DB の table に対応する型を置く。DB 構造の source of truth にする。
- `app/services/`: 業務ロジックを置く。`routes/` に処理を書きすぎず、複数 API で使う処理はここへ逃がす。
- `app/db/`: DB 接続や session 管理を置く。
- `compose.yaml`: backend local 開発用の compose 設定を置く。
- `docker/`: backend image の build に使う Dockerfile を置く。

基本方針:

- API を増やすときは `app/api/routes/` に追加する。
- Flutter に返す JSON の形を変えるときは `app/schemas/` を見る。
- DB table を増やすときは `app/models/` に追加する。
- endpoint 内の処理が長くなったら `app/services/` に分ける。
- DB 接続の設定は `app/db/` と `app/core/` に閉じる。

## 起動

初回は local 用 `.env` を作る。

```sh
cp .env.example .env
```

通常は `.env.example` の値のままで起動できる。

実際の `backend/.env` に書く値:

```env
API_PORT=8000

POSTGRES_DB=gurumeet
POSTGRES_USER=gurumeet
POSTGRES_PASSWORD=change_me
POSTGRES_PORT=5432
```

通常の local Docker Compose 開発では `DATABASE_URL` は `backend/.env` に書かなくてよい。

理由:

```text
backend/.env
  -> compose.yaml が読む
  -> api / db コンテナに POSTGRES_* を渡す
  -> api コンテナは POSTGRES_HOST=db と POSTGRES_* から接続 URL を作る
```

FastAPI を Compose の外で直接起動する場合だけ、必要に応じて `DATABASE_URL` を shell に export する。

```env
DATABASE_URL=postgresql://gurumeet:change_me@localhost:5432/gurumeet
```

staging / production の `DATABASE_URL` は `backend/.env` には書かない。Cloudflare Wrangler secret に登録する。

```sh
cd ../infra/cloudflare/app-worker
npx wrangler secret put DATABASE_URL --env staging
npx wrangler secret put DATABASE_URL --env production
```

`backend` フォルダ内で実行:

```sh
docker compose up --build
```

ログを見る:

```sh
docker compose logs -f
```

API:

- `http://localhost:8000/`
- `http://localhost:8000/health`
- `http://localhost:8000/docs`

停止:

```sh
docker compose down
```

## DB 認証エラーが出る場合

`password authentication failed for user "gurumeet"` が出る場合は、既存の Docker volume に保存されている PostgreSQL のパスワードと、現在の `backend/.env` の `POSTGRES_PASSWORD` がずれている。

PostgreSQL の公式 image は、初回に volume を作ったときだけ `POSTGRES_PASSWORD` を反映する。あとから `.env` を変えても、既存 DB ユーザーのパスワードは自動では変わらない。

ローカル開発 DB を消してよい場合だけ、`backend` フォルダで実行する。

```sh
make reset-db
```

これは `postgres_data` volume を削除するため、ローカル DB のデータは消える。残したいデータがある場合は、`.env` の `POSTGRES_PASSWORD` を既存 DB 作成時の値に戻す。
