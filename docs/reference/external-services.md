# External Data And Services

GuruMeetで利用する外部データ、外部API、ライセンス、料金、運用上の扱いをまとめる。

CSVや取得済みデータ本体はGit管理しない。取得元、取得日、ライセンス、加工内容を記録し、DBへは再実行可能なimport scriptで投入する。

## 一覧

| name | purpose | type | cost | required for |
| --- | --- | --- | --- | --- |
| Geolonia 住所データ | 市区町村マスタ | CSV data | free | 地点検索の市区町村候補 |
| 駅データ.jp | 駅マスタ | CSV data | free / paid | 地点検索の駅候補 |
| Hot Pepper Gourmet API | 飲食店候補検索 | Web API | free within provider terms | グループ作成時の店舗候補取得 |

## Geolonia 住所データ

### 用途

市区町村候補の元データとして使う。

Geoloniaの住所データは町丁目・小字などを含む住所データであり、市区町村専用マスタではない。GuruMeetでは `市区町村コード` で集約し、都道府県・市区町村単位のマスタとして `locations` / `municipality_locations` に保存する。

保存する主な項目:

- 市区町村コード
- 都道府県名
- 市区町村名
- 読み仮名
- 代表緯度
- 代表経度

緯度経度は、同じ市区町村コードに属する行の代表点を平均して作る。厳密な行政区域の重心や市役所所在地ではないため、市区町村の区域検索が使えない場合のfallback座標として扱う。

### 取得元

- Site: https://geolonia.github.io/japanese-addresses/
- Repository: https://github.com/geolonia/japanese-addresses
- CSV: https://raw.githubusercontent.com/geolonia/japanese-addresses/master/data/latest.csv

### ライセンス

- Dataset license: CC BY 4.0
- Repository scripts/code: MIT License

データ本体はCC BY 4.0として扱う。利用時は出典、ライセンス、加工内容をREADMEやクレジット表示に記載する。

表示例:

```text
住所データ: Geolonia 住所データ
https://geolonia.github.io/japanese-addresses/
Licensed under CC BY 4.0
Geolonia住所データを市区町村コード単位に集約し、代表座標を算出して利用しています。
```

### 運用

- CSV本体はGitに含めない。
- 初期投入、更新投入は `backend/scripts/import_locations.py` で行う。
- 取得日と取得元URLを [Location Data Versions](./location-data-versions.md) に残す。
- データ更新時は同じscriptを再実行し、既存データをupsertする。

## 駅データ.jp

### 用途

駅候補の元データとして使う。

保存する主な項目:

- 駅コード
- 駅グループコード
- 駅名
- 読み仮名
- 都道府県
- 市区町村
- 緯度
- 経度
- 路線名

駅グループコードがある場合は、同一駅を1候補にまとめる。複数路線に属する駅は路線名を `/` 区切りで保持し、候補表示で区別できるようにする。

### 取得元

- Site: https://www.ekidata.jp/
- Terms: https://ekidata.jp/agreement.php
- FAQ: https://ekidata.jp/faq.php

### ライセンス/利用条件

駅データ.jpの利用規約に従う。商用・非商用利用、加工、第三者提供が可能とされているが、非加工データを第三者へ提供する場合は無償である必要がある。

クレジット表記は必須ではないが、READMEやクレジット表示に利用データとして記載する。

表示例:

```text
駅データ: 駅データ.jp
https://www.ekidata.jp/
駅データ.jpの利用規約に従って利用しています。
```

### 料金

無料データと有料データがある。

駅名の読み仮名検索を確実に実装する場合は、有料データを使う。駅データ.jpのFAQでは、有料データは税込4,400円で、支払い後6ヶ月間は最新版をダウンロード可能とされている。

無料データでは駅名称カナ、駅名称ローマ字、新幹線駅データなど一部項目が含まれない。GuruMeetの検索仕様はひらがな・カタカナ検索を含むため、本番運用では有料データ前提にする。

### 運用

- CSV本体はGitに含めない。
- 駅データ.jpから `station.csv` と `line.csv` を取得し、import scriptへ渡す。
- 自動取得は前提にしない。会員ログインや購入が絡むため、取得済みCSVを運用環境に配置して投入する。
- 取得日、無料/有料の種別、checksumを [Location Data Versions](./location-data-versions.md) に残す。
- データ更新時は同じscriptを再実行し、既存データをupsertする。

## Hot Pepper Gourmet API

### 用途

一時グループ作成時の飲食店候補検索に使う。

検索条件:

- 駅候補: 駅の緯度経度を中心に半径検索
- 市区町村候補: 市区町村の代表座標を中心に半径検索
- 現在地入力: 端末で取得した緯度経度を中心に半径検索
- 予算: Hot Pepperのbudget codeへ変換
- 人数: 店舗候補のranking scoreに利用

一時グループ作成では、自由入力地点による `keyword` 検索は使わない。
frontendで選択された `location_id` からbackendが地点マスタを引き、緯度経度と設定値の半径をHot Pepper APIへ渡す。
現在地入力の場合は、frontendが送信した `custom_location` の緯度経度を
backendが `custom_locations` に保存し、その座標をHot Pepper APIへ渡す。

### 取得元

- API: https://webservice.recruit.co.jp/doc/hotpepper/reference.html

### 認証/設定

`HOTPEPPER_API_KEY` をbackend環境変数として設定する。

ローカルで外部APIを叩かない場合は、以下でモック店舗を使う。

```env
GURUMEET_ENABLE_MOCK_RESTAURANTS=true
```

本番やstagingで実APIを使う場合:

```env
GURUMEET_ENABLE_MOCK_RESTAURANTS=false
HOTPEPPER_API_KEY=<Recruit Web Service API key>
```

API keyはGit管理しない。GitHub Environment secretsや本番secret storeに保存する。

### ライセンス/利用条件

リクルートWebサービスの利用規約とHot Pepper APIの仕様に従う。APIレスポンス由来の店舗名、住所、画像URL、店舗URLなどは、提供元の表示条件や利用条件に従って表示・保存する。

### 運用

- 店舗候補は一時グループ作成時に検索し、`temporary_groups.restaurant` にJSONで保存する。
- 外部API障害時はグループ作成APIで502/504を返す。
- API key未設定で実APIモードの場合は起動時または検索時に設定エラーにする。
