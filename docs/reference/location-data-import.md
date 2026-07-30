# Location Data Import

地点マスタのCSV取得とローカルDB投入手順。

CSV本体はGit管理しない。ローカルでは `backend/data/location-master/` に置く。
このディレクトリは `.gitignore` の `data/` 対象なので、取得済みCSVを置いてもコミットされない。

## 使うデータ

### Geolonia 住所データ

- 取得元: https://geolonia.github.io/japanese-addresses/
- CSV: https://raw.githubusercontent.com/geolonia/japanese-addresses/master/data/latest.csv
- ライセンス: CC BY 4.0

`latest.csv` はスクリプトで自動取得する。
GuruMeetでは町丁目単位では使わず、`市区町村コード` で集約して市区町村候補にする。

### 駅データ.jp

- 取得元: https://www.ekidata.jp/
- 利用規約: https://ekidata.jp/agreement.php
- FAQ: https://ekidata.jp/faq.php
- 駅CSV仕様: https://www.ekidata.jp/doc/station.php

駅データ.jpのCSVは自動取得しない。会員登録や有料データ購入が絡むため、取得済みCSVを手元に置いてからimportする。

駅名のかな検索を本番品質で使う場合は、有料データを使う。
無料データには駅名称カナが含まれないため、漢字検索はできても「しぶや」「アキハバラ」のような駅かな検索は弱くなる。

## CSV配置

`backend` ディレクトリ配下に置く。

```text
backend/data/location-master/
  geolonia/
    latest.csv        # 自動取得される
  ekidata/
    station.csv       # 駅データ.jpから取得して置く
    line.csv          # 任意。あると候補表示に路線名を出せる
```

駅データ.jpのzipを展開したあと、少なくとも `station.csv` を上記パスに置く。
`line.csv` がある場合は同じ場所に置く。

```sh
mkdir -p backend/data/location-master/ekidata
cp /path/to/ekidata/station.csv backend/data/location-master/ekidata/station.csv
cp /path/to/ekidata/line.csv backend/data/location-master/ekidata/line.csv
```

## ローカルDBへ初回投入

backendのDocker Composeを起動する。

```sh
cd backend
docker compose up -d --build
```

`docker compose up -d --build ./scripts/import_location_master_local.sh` のように
1行でつなげて実行するのではない。`docker compose up` はコンテナ起動用のコマンドで、
import scriptは起動後に別コマンドとして実行する。

地点マスタを投入する。

```sh
./scripts/import_location_master_local.sh
```

このスクリプトは以下を行う。

- Geolonia `latest.csv` がなければ自動ダウンロードする
- `backend/data/location-master/ekidata/station.csv` の存在を確認する
- `line.csv` があれば路線名も取り込む
- apiコンテナ内で `scripts/import_locations.py` を実行する
- 同じ地点IDはinsertではなくupdateする
- 不正行はログに出し、処理全体は継続する
  - 不正行が多い場合は最初の一部だけ表示し、最後に理由別件数を出す
  - `committing location master import` より前に中断した場合、DBには反映されない

## コンテナに入って確認する

apiコンテナに入る場合:

```sh
cd backend
docker compose exec api sh
```

コンテナ内ではbackendディレクトリが `/app` として見える。

```sh
pwd
# /app

ls data/location-master
```

コンテナ内から手動でimportする場合:

```sh
python scripts/import_locations.py \
  --municipalities-csv /app/data/location-master/geolonia/latest.csv \
  --stations-csv /app/data/location-master/ekidata/station.csv \
  --station-lines-csv /app/data/location-master/ekidata/line.csv
```

コンテナに入らずホストから直接実行する場合は、以下でも同じ。

```sh
cd backend
docker compose exec -T api python scripts/import_locations.py \
  --municipalities-csv /app/data/location-master/geolonia/latest.csv \
  --stations-csv /app/data/location-master/ekidata/station.csv \
  --station-lines-csv /app/data/location-master/ekidata/line.csv
```

通常は上記を直接打たず、`./scripts/import_location_master_local.sh` を使う。

## 更新投入

Geoloniaを取り直して再投入する場合:

```sh
cd backend
REFRESH_GEOLONIA=1 ./scripts/import_location_master_local.sh
```

駅データ.jpを更新する場合は、新しい `station.csv` / `line.csv` で
`backend/data/location-master/ekidata/` のファイルを置き換えてから同じスクリプトを再実行する。

## hostのPythonで実行する場合

backendのPython依存がローカルに入っていて、DB接続環境変数も設定済みならhost実行もできる。

```sh
cd backend
LOCATION_IMPORT_RUNNER=host ./scripts/import_location_master_local.sh
```

通常のローカル開発ではDocker実行を使う。

## 本番DBへ投入

本番DBはNeon PostgreSQLを前提にする。
CSV本体と本番 `DATABASE_URL` はGitに置かない。`backend/.env` にも本番値は書かず、
GitHub Environment secrets、Neon Dashboard、または一時的なshell環境変数だけで扱う。

基本方針:

- stagingで同じ手順を先に試す
- production DBへ投入する前にDB migrationを適用する
- 可能ならNeonのbranch/snapshotなどで復旧点を作る
- CSVは作業端末または一時的なCI artifactに置き、投入後は不要なら削除する
- importは再実行可能。同じ `locations.id` / 子テーブルのキーはinsertではなくupdateされる
- `committing location master import` より前に中断した場合、DBには反映されない

### 1. CSVを用意する

作業端末の `backend/data/location-master/` にローカル投入と同じ配置で置く。

```text
backend/data/location-master/
  geolonia/latest.csv
  ekidata/station.csv
  ekidata/line.csv
```

Geoloniaは以下の `curl` で取得できる。
駅データ.jpは取得済みCSVを配置する。

```sh
cd backend
mkdir -p data/location-master/geolonia
mkdir -p data/location-master/ekidata
curl -fL \
  https://raw.githubusercontent.com/geolonia/japanese-addresses/master/data/latest.csv \
  -o data/location-master/geolonia/latest.csv
cp /path/to/ekidata/station.csv data/location-master/ekidata/station.csv
cp /path/to/ekidata/line.csv data/location-master/ekidata/line.csv
```

### 2. 本番DB接続文字列を一時的に渡す

Neonのproduction branchのconnection stringを使う。
bulk importではpooler経由よりdirect connectionを使う方が無難。

```sh
export PRODUCTION_DATABASE_URL='postgresql://...'
```

この値はshell historyやログに残さない。作業後は必ず消す。

```sh
unset PRODUCTION_DATABASE_URL
```

### 3. migrationを本番DBへ適用する

deploy pipelineでmigrationを実行済みなら不要。
手動で行う場合は、ローカルDocker imageを使ってproduction DBへ接続する。
imageをまだ作っていない場合は先に `docker compose build api` を実行する。

```sh
cd backend
docker compose run --rm --no-deps \
  -e DATABASE_URL="$PRODUCTION_DATABASE_URL" \
  api alembic upgrade head
```

### 4. importを実行する

hostにPython依存を入れず、ローカルDocker imageからproduction DBへ接続して投入する。
`--no-deps` を付けることで、ローカルDBコンテナを起動せず本番DBだけへ接続する。
imageをまだ作っていない場合は先に `docker compose build api` を実行する。

```sh
cd backend
docker compose run --rm --no-deps \
  -e DATABASE_URL="$PRODUCTION_DATABASE_URL" \
  api python scripts/import_locations.py \
    --municipalities-csv /app/data/location-master/geolonia/latest.csv \
    --stations-csv /app/data/location-master/ekidata/station.csv \
    --station-lines-csv /app/data/location-master/ekidata/line.csv
```

`line.csv` がない場合:

```sh
docker compose run --rm --no-deps \
  -e DATABASE_URL="$PRODUCTION_DATABASE_URL" \
  api python scripts/import_locations.py \
    --municipalities-csv /app/data/location-master/geolonia/latest.csv \
    --stations-csv /app/data/location-master/ekidata/station.csv
```

hostのPythonで実行する場合:

```sh
cd backend
DATABASE_URL="$PRODUCTION_DATABASE_URL" \
LOCATION_IMPORT_RUNNER=host \
REFRESH_GEOLONIA=1 \
./scripts/import_location_master_local.sh
```

### 5. 投入後確認

production APIで候補が返ることを確認する。

```sh
curl 'https://gurumeet.net/api/locations?prefecture=東京都'
```

Cloudflare Accessをかけている環境では通常の `curl` では確認できない場合がある。
その場合はブラウザで確認するか、Access service tokenを使う。

DB側で件数を見る場合は、Neon SQL Editorまたは `psql` で確認する。

```sql
select location_type, count(*)
from locations
group by location_type
order by location_type;
```

投入したデータの取得日、checksum、件数は
[Location Data Versions](./location-data-versions.md) に記録する。

### 6. 作業後

```sh
unset PRODUCTION_DATABASE_URL
```

CSV本体はGit管理しない。作業端末に残す場合も、取得元・取得日・ライセンスを分かる形で管理する。

## 件数確認

```sh
cd backend
docker compose exec -T db psql -U gurumeet -d gurumeet \
  -c "select location_type, count(*) from locations group by location_type order by location_type;"
```

都道府県別候補APIの確認:

```sh
curl 'http://localhost:8000/locations?prefecture=東京都'
```

ここで `[]` が返る場合、フロント側で駅・市区町村候補は出ない。
地点マスタがDBに入っていないか、指定した都道府県名がDBの `prefecture_name` と一致していない。

件数だけ確認する場合:

```sh
curl -s 'http://localhost:8000/locations?prefecture=東京都' | python -m json.tool | head
```

## 注意

- CSV本体はコミットしない。
- Geolonia住所データ本体はCC BY 4.0として扱い、出典と加工内容をREADMEやクレジットに記載する。
- 駅データ.jpは利用規約に従う。非加工データを第三者提供する場合は無償である必要がある。
- かな検索の品質は駅CSVの `station_name_k` に依存する。
