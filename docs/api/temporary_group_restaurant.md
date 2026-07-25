# TemporaryGroup × Restaurant 実装仕様

## 概要

TemporaryGroupに保存されている条件を利用してHotPepper APIから店舗候補を取得し、
取得した店舗情報をDBへ保存すると同時にフロントへ返却する機能を実装した。

フロントは検索条件を毎回送信するのではなく、
グループIDのみを指定して店舗検索を実行する。

---

# 実装目的

従来はHotPepper APIの検索結果をそのまま返却するだけで、
店舗情報はDBへ保存されていなかった。

そのため、

- グループメンバー全員が同じ店舗候補を見る
- 再取得時も同じ候補を利用する
- 後から投票機能などへ発展させる

ことが難しかった。

そこで、

TemporaryGroupに保存されている条件を利用して店舗検索を行い、
取得した店舗情報をTemporaryGroupへ保存する設計へ変更した。

---

# 処理フロー

① TemporaryGroup作成

```
POST /temporary-groups
```

保存する情報

- participant_count
- location
- budget_min
- budget_max
- 招待コード
- 有効期限

↓

② 店舗検索

```
POST /temporary-groups/{group_id}/restaurants/search
```

↓

③ group_idからTemporaryGroup取得

↓

④ DBに保存されている

- location
- budget_min
- budget_max

を取得

↓

⑤ HotPepper API検索

↓

⑥ 必要な項目のみ整形

↓

⑦ restaurant(JSONB)へ保存

↓

⑧ 同じデータをフロントへ返却

---

# API

## グループ作成

```
POST /temporary-groups
```

役割

TemporaryGroupを作成する。

---

## 店舗検索

```
POST /temporary-groups/{group_id}/restaurants/search
```

役割

TemporaryGroupの条件を利用して店舗検索を行う。

フロントから検索条件を送信する必要はない。

---

## グループ取得

```
GET /temporary-groups/{group_id}
```

役割

TemporaryGroup情報と保存済み店舗情報を取得する。

---

# restaurantカラム

restaurantはフロントから送信されるデータではない。

バックエンドがHotPepper APIから取得した店舗情報を保存するためのJSONBカラムである。

保存例

```json
{
  "restaurants": [
    {
      "id": "...",
      "name": "...",
      "address": "...",
      "access": "...",
      "genre": "...",
      "budget": "...",
      "image_url": "...",
      "shop_url": "..."
    }
  ],
  "searched_at": "2026-07-25T00:00:00+09:00"
}
```

---

# HotPepper検索条件

使用する項目

- location
- budget_min
- budget_max

participant_countは現在HotPepper APIに対応する検索条件が存在しないため、
検索条件には利用していない。

---

# 予算検索

HotPepperは予算コードで検索する仕様のため、

budget_min
budget_max

から対応する予算コードへ変換して検索する。

希望範囲と一部でも重なる予算コードを対象としている。

例

```
希望予算

2000〜3000円

↓

検索コード

B001
B002
```

---

# 返却する店舗情報

以下の項目のみ返却する。

- id
- name
- address
- access
- genre
- budget
- image_url
- shop_url

不要なHotPepperレスポンスは返却しない。

---

# 保存仕様

- 最大10件取得
- 店舗IDで重複除外
- searched_at保存
- restaurant全体を上書き
- 再検索時は追加しない

---

# エラー処理

400

- location不足
- 予算範囲不正
- 対応外予算

404

- グループが存在しない
- 有効期限切れ

502

- HotPepper通信エラー

504

- タイムアウト

DB保存失敗時

- rollback
- 既存restaurantを保持

店舗0件

- restaurantsを空配列で保存
- 正常終了

---

# 実装して確認済み

- TemporaryGroup作成
- 店舗検索
- HotPepper API通信
- JSON整形
- restaurant保存
- DB保存確認
- GET取得確認
- Swagger確認
- 実環境確認
- Docker確認
- PostgreSQL確認
- 再検索時の上書き確認

---

# 今後の拡張

restaurantに保存された店舗情報を利用して、

- 投票機能
- おすすめ店舗表示
- 店舗詳細表示
- Google Places APIとの連携

などへ発展できる設計となっている。