# Gurumeet

製作中

## 動作確認前の環境変数チェック

ローカルで動作確認する前に、必ず以下を実行する。

```sh
cd backend
make check-env

cd ../frontend
make check-env
```

このチェックは `backend/.env` と `frontend/.env`、および現在のシェル環境変数を読み、
必要な項目が空でないか確認する。APIキーやsecretの値は表示しない。

Frontend の `make dev` / `make dev-chrome` は `frontend/.env` の値を
Flutter の `--dart-define` に渡して起動する。

## GitHub Actions secrets

Cloudflare deploy と Worker / Container の runtime secrets は GitHub Actions から渡す。

Repository secrets:

```text
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
```

GitHub Environment secrets:

```text
staging:
  DATABASE_URL
  HOTPEPPER_API_KEY
  PARTICIPANT_TOKEN_HASH_SECRET
  INTERNAL_TASK_SECRET

production:
  DATABASE_URL
  HOTPEPPER_API_KEY
  PARTICIPANT_TOKEN_HASH_SECRET
  INTERNAL_TASK_SECRET
```

GitHub Environment vars:

```text
staging:
  CORS_ALLOW_ORIGINS
  GURUMEET_ENABLE_MOCK_RESTAURANTS

production:
  CORS_ALLOW_ORIGINS
  GURUMEET_ENABLE_MOCK_RESTAURANTS
```

登録手順は `infra/cloudflare/README.md` を参照する。
