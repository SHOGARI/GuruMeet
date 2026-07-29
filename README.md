# Gurumeet

製作中

## 動作確認前の環境変数チェック

ローカルで動作確認する前に、必ず以下を実行する。

```sh
make check-env
```

このチェックは `backend/.env` と `frontend/.env`、および現在のシェル環境変数を読み、
必要な項目が空でないか確認する。APIキーやsecretの値は表示しない。

Frontend の `make dev` / `make dev-chrome` は `frontend/.env` の値を
Flutter の `--dart-define` に渡して起動する。
