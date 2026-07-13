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
  docker/
    Dockerfile
    Dockerfile.dockerignore
    compose.yaml
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
- `docker/`: Docker 関連ファイルを置く。backend root に Docker 設定を散らさない。

基本方針:

- API を増やすときは `app/api/routes/` に追加する。
- Flutter に返す JSON の形を変えるときは `app/schemas/` を見る。
- DB table を増やすときは `app/models/` に追加する。
- endpoint 内の処理が長くなったら `app/services/` に分ける。
- DB 接続の設定は `app/db/` と `app/core/` に閉じる。

## 起動

`backend` フォルダ内で実行:

```sh
make dev
```

ログを見る:

```sh
make logs
```

API:

- `http://localhost:8000/`
- `http://localhost:8000/health`
- `http://localhost:8000/docs`

停止:

```sh
make down
```
