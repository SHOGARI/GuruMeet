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
Hot Pepper API を実際に叩く場合だけ、`HOTPEPPER_API_KEY` を入れて
`GURUMEET_ENABLE_MOCK_RESTAURANTS=false` にする。

実際の `backend/.env` に書く値:

```env
HOTPEPPER_API_KEY=
API_PORT=8000

POSTGRES_DB=gurumeet
POSTGRES_USER=gurumeet
POSTGRES_PASSWORD=change_me
POSTGRES_PORT=5432

TEMPORARY_GROUP_TTL_MINUTES=1440
TEMPORARY_GROUP_CODE_MAX_ATTEMPTS=20
JOIN_RATE_LIMIT_REQUESTS=10
JOIN_RATE_LIMIT_WINDOW_SECONDS=60
CORS_ALLOW_ORIGINS='["http://localhost:3000","http://127.0.0.1:3000","http://localhost:8080","http://127.0.0.1:8080"]'
GURUMEET_ENABLE_MOCK_RESTAURANTS=true
GURUMEET_HOTPEPPER_STATION_SEARCH_RADIUS_METERS=1000
GURUMEET_HOTPEPPER_MUNICIPALITY_SEARCH_RADIUS_METERS=3000
PARTICIPANT_TOKEN_HASH_SECRET=<openssl rand -hex 32 の出力>
INTERNAL_TASK_SECRET=<openssl rand -hex 32 の出力>
```

`PARTICIPANT_TOKEN_HASH_SECRET` は匿名参加者トークンをDB保存用にhash化するときのサーバー秘密値。

生成例:

```sh
openssl rand -hex 32
```

この値はfrontendには渡さない。本番ではGitに置かず、GitHub Environment secrets に登録する。途中で変更すると既存の `anonymous_users.participant_token_hash` と照合できなくなる。

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

staging / production の `DATABASE_URL` は `backend/.env` には書かない。
GitHub Environment secrets に登録し、deploy workflow から Cloudflare Worker / Container に渡す。

Environment secrets:

```text
DATABASE_URL
HOTPEPPER_API_KEY
PARTICIPANT_TOKEN_HASH_SECRET
INTERNAL_TASK_SECRET
```

Environment vars:

```text
CORS_ALLOW_ORIGINS
GURUMEET_ENABLE_MOCK_RESTAURANTS
GURUMEET_HOTPEPPER_STATION_SEARCH_RADIUS_METERS
GURUMEET_HOTPEPPER_MUNICIPALITY_SEARCH_RADIUS_METERS
```

Environment secrets の登録場所:

```text
GitHub repository
  -> Settings
  -> Environments
  -> staging / production
  -> Environment secrets
  -> Add secret
```

Environment vars の登録場所:

```text
GitHub repository
  -> Settings
  -> Environments
  -> staging / production
  -> Variables
  -> Add variable
```

追加値の作り方:

```text
INTERNAL_TASK_SECRET: openssl rand -hex 32 の出力
CORS_ALLOW_ORIGINS:
  staging: https://stg.gurumeet.net
  production: https://gurumeet.net
GURUMEET_ENABLE_MOCK_RESTAURANTS: false
GURUMEET_HOTPEPPER_STATION_SEARCH_RADIUS_METERS: 1000
GURUMEET_HOTPEPPER_MUNICIPALITY_SEARCH_RADIUS_METERS: 3000
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

店舗候補は一時グループ作成時に希望場所が指定されていれば同時に検索・保存されます。

```text
POST /temporary-groups
```

## 地点マスタの投入

地点検索は `locations` を親テーブルにし、市区町村固有情報を
`municipality_locations`、駅固有情報を `station_locations` に保持する。

使用データ:

- 市区町村: Geolonia 住所データ `latest.csv`
  - https://geolonia.github.io/japanese-addresses/
  - データ本体は CC BY 4.0
  - 町丁目・小字レベルのデータを市区町村コード単位に集約して使う
- 駅: 駅データ.jp の駅CSV
  - https://www.ekidata.jp/
  - 利用条件は駅データ.jpの案内に従う
  - ひらがな・カタカナ検索を本番品質で行う場合は、駅名称カナを含む有料データを前提にする

外部データ/APIのライセンス、料金、運用上の扱いは [External Data And Services](../docs/external-services.md) にまとめる。

CSVはGitに含めず、ローカルまたは運用環境で取得して指定する。
初回投入の具体的な手順は [Location Data Import](../docs/location-data-import.md) にまとめる。

```sh
python scripts/import_locations.py \
  --municipalities-csv /path/to/geolonia/latest.csv \
  --stations-csv /path/to/ekidata/station.csv \
  --station-lines-csv /path/to/ekidata/line.csv
```

`--station-lines-csv` は任意。指定すると候補表示に路線名を含める。

ローカルDocker ComposeのDBへ投入する場合は、駅CSVを
`backend/data/location-master/ekidata/` に置いたうえで以下を実行する。

```sh
docker compose up -d --build
./scripts/import_location_master_local.sh
```

`docker compose up -d --build ./scripts/import_location_master_local.sh` ではない。
Compose起動とimport script実行は別コマンドで行う。

apiコンテナに入って確認する場合:

```sh
docker compose exec api sh
```

コンテナ内ではbackendディレクトリが `/app` にマウントされている。
手動importする場合は以下の形になる。

```sh
python scripts/import_locations.py \
  --municipalities-csv /app/data/location-master/geolonia/latest.csv \
  --stations-csv /app/data/location-master/ekidata/station.csv \
  --station-lines-csv /app/data/location-master/ekidata/line.csv
```

import は再実行可能。同じ地点IDの行は更新する。不正行はログに出して処理を継続する。

一時グループ作成時に地点候補を選択した場合、frontend は表示名ではなく
`location_id` を送る。

```json
{
  "location": "北千住駅・東京都足立区",
  "location_id": "station:1132005"
}
```

backend は `locations` から元データを解決し、`temporary_groups` には
`location_id` だけを保存する。駅は駅座標から半径検索し、市区町村は代表座標から
半径検索する。検索半径は `GURUMEET_HOTPEPPER_STATION_SEARCH_RADIUS_METERS` と
`GURUMEET_HOTPEPPER_MUNICIPALITY_SEARCH_RADIUS_METERS` で設定する。
自由入力文字列による Hot Pepper の keyword 検索は一時グループ作成では使わない。

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
