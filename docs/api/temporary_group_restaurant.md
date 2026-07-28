# TemporaryGroup × Restaurant 実装仕様

## 概要

TemporaryGroupに保存されている条件を利用してHotPepper APIから店舗候補を取得し、
取得した店舗情報をDBへ保存すると同時にフロントへ返却する機能を実装した。

フロントは検索条件を毎回送信するのではなく、
TemporaryGroup作成APIに希望条件を送信する。店舗検索専用APIは持たない。

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

TemporaryGroup作成時に店舗検索を行い、取得した店舗情報をTemporaryGroupへ保存する設計へ変更した。

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

② リクエストの

- location
- budget_min
- budget_max

を利用

↓

③ HotPepper API検索

↓

④ 必要な項目のみ整形

↓

⑤ restaurant(JSONB)へ保存

↓

⑥ restaurant_search_statusへ検索状態を保存

↓

⑦ グループ情報と同じレスポンスでフロントへ返却

---

# API

## グループ作成

```
POST /temporary-groups
```

役割

TemporaryGroupを作成し、希望場所があれば店舗候補も検索して保存する。

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

restaurant_search_statusはHot Pepper店舗検索の状態を保存するカラムである。

| value | meaning |
| --- | --- |
| `not_requested` | locationが空で検索していない。 |
| `succeeded` | Hot Pepperから1件以上の店舗候補を取得した。 |
| `no_results` | Hot Pepper検索は成功したが候補が0件だった。 |

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
- restaurantに検索結果を保存
- restaurant_search_statusに検索状態を保存

---

# エラー処理

400

- 予算範囲不正
- 対応外予算

502

- HotPepper通信エラー

504

- タイムアウト

DB保存失敗時

- rollback
- グループ作成を完了しない

店舗0件

- restaurantsを空配列で保存
- restaurant_search_statusはno_results
- 正常終了

---

# 実装して確認済み

- TemporaryGroup作成
- 作成時の店舗検索
- HotPepper API通信
- JSON整形
- restaurant保存
- DB保存確認
- GET取得確認
- Swagger確認
- 実環境確認
- Docker確認
- PostgreSQL確認

---

# 今後の拡張

restaurantに保存された店舗情報を利用して、

- 投票機能
- おすすめ店舗表示
- 店舗詳細表示
- Google Places APIとの連携

などへ発展できる設計となっている。

---

# 店舗推薦アルゴリズム仕様書

## 概要

TemporaryGroupの店舗検索では、Hot Pepper APIの取得順をそのまま返すのではなく、
グループ条件に応じて独自のスコアリングを行い、最適と思われる店舗を最大10件返却する。

---

# 全体フロー

```text
TemporaryGroup取得
        │
        ▼
Hot Pepper APIから30件取得
        │
        ▼
店舗ID重複除外
        │
        ▼
予算スコア（70点）
        │
        ▼
席数スコア（30点）
        │
        ▼
合計100点でランキング
        │
        ▼
ジャンル重複を調整
        │
        ▼
最大10件を返却・保存
```

---

# スコアリング

## 1. 予算スコア（70点）

グループの希望予算と店舗予算の中央値を比較する。

```text
希望予算中央値 = (budget_min + budget_max) / 2
店舗予算中央値 = (店舗予算下限 + 店舗予算上限) / 2
差 = abs(希望予算中央値 - 店舗予算中央値)
```

| 中央値の差 | 点数 |
|---|---:|
| 300円以下 | 70 |
| 600円以下 | 63 |
| 900円以下 | 56 |
| 1,200円以下 | 49 |
| 1,500円以下 | 42 |
| 1,500円超 | 28 |

予算情報が欠損・不正な場合も店舗は除外せず、28点を付与する。

---

## 2. 席数スコア（30点）

グループ人数と店舗の総席数（`capacity`）から採点する。

| 条件 | 点数 |
|---|---:|
| `capacity < participant_count` | 0 |
| `capacity < participant_count × 2` | 12 |
| `capacity < participant_count × 4` | 21 |
| `capacity < participant_count × 8` | 27 |
| それ以上 | 30 |

席数または人数が不正・欠損の場合は9点を付与する。

---

# 総合スコア

```text
total_score = budget_score + capacity_score
```

ランキング順位は以下の優先順位で決定する。

1. `total_score`（降順）
2. `budget_score`（降順）
3. `capacity_score`（降順）
4. Hot Pepper APIの取得順

同じ入力に対しては必ず同じ順位となる。

---

# ジャンル分散

ランキング後にジャンルの偏りを抑える。

## 第1段階

- 同一ジャンルは最大2店舗まで採用
- スコア順に選出

## 第2段階

10店舗に満たない場合のみ、

- ジャンル制限を解除
- ランキング順に不足分を補充

これにより、

- できるだけジャンルを分散
- 候補が少ない場合でも10店舗返却

を両立している。

---

# 取得件数

| 内容 | 件数 |
|---|---:|
| Hot Pepper API取得候補 | 30 |
| 最終返却件数 | 10 |

30件から最適な10件を選び直すことで、推薦精度を向上させている。

---

# 実装上のポイント

- 店舗ID重複はスコア計算前に除外
- スコアは内部処理のみ利用
- APIレスポンス・DB保存値にはスコアを含めない
- DB Schema・Flutter・APIレスポンス形式は変更しない
- ランキング処理はprivate関数へ分割し、保守性を確保

---

# このアルゴリズムを採用した理由

- 希望予算に近い店舗を優先できる
- 人数に対して余裕のある店舗を評価できる
- 同じジャンルばかりになることを防げる
- Hot Pepper APIの取得順に依存しない推薦ができる
- 将来的に評価項目（レビュー評価・営業状況・混雑度など）を追加しやすい設計になっている
