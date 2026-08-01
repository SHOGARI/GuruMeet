# temporary_groups

一時グループのUUID、手入力用コード、有効期限、希望条件を保存するテーブル。

| column | type | null | description |
| --- | --- | --- | --- |
| `id` | `UUID` | no | URL共有用の推測困難な識別子。アプリ側で `uuid4` を生成する。 |
| `code` | `CHAR(5)` | no | 手入力参加用の5桁英数字コード。unique制約あり。 |
| `creator_id` | `VARCHAR(128)` | yes | 作成者識別子。作成時tokenがあり明示値がなければ匿名ユーザーUUIDを文字列で保存する。 |
| `participant_count` | `INT` | yes | 参加人数。 |
| `location` | `VARCHAR(255)` | yes | 希望場所の表示名。 |
| `location_id` | `VARCHAR(40)` | yes | 駅・市区町村を選択した場合の `locations.id`。 |
| `custom_location_id` | `UUID` | yes | 現在地・地図ピンから入力した場合の `custom_locations.id`。 |
| `budget_min` | `INT` | yes | 予算下限。 |
| `budget_max` | `INT` | yes | 予算上限。 |
| `restaurant` | `JSONB` | yes | 選択済み、または候補の店舗情報。 |
| `restaurant_search_status` | `VARCHAR(32)` | no | Hot Pepper店舗検索の状態。`not_requested`, `succeeded`, `no_results` のいずれか。 |
| `voting_started_at` | `TIMESTAMP WITH TIME ZONE` | yes | 投票開始時刻。未開始の場合はnull。 |
| `voting_completed_at` | `TIMESTAMP WITH TIME ZONE` | yes | 全参加者が全候補へ投票し終えた時刻。未完了の場合はnull。 |
| `selected_restaurant_id` | `VARCHAR(128)` | yes | 同率1位からホストが決定した店舗ID。単独1位ではnullのまま。 |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | no | DB側の `now()` で作成日時を保存する。 |
| `expires_at` | `TIMESTAMP WITH TIME ZONE` | no | 有効期限。デフォルトは作成から3時間後。 |

## Constraints and Indexes

| name | target | purpose |
| --- | --- | --- |
| primary key | `id` | UUIDで一意に取得する。 |
| `uq_temporary_groups_code` | `code` | 手入力コードの重複を防ぐ。 |
| `ck_temporary_groups_restaurant_search_status` | `restaurant_search_status` | Hot Pepper店舗検索状態を許可値に限定する。 |
| `ix_temporary_groups_code` | `code` | コード参加APIの検索用。 |
| `ix_temporary_groups_location_id` | `location_id` | 選択地点から作成された一時グループの参照用。 |
| `ix_temporary_groups_custom_location_id` | `custom_location_id` | 現在地・地図ピンから作成された一時グループの参照用。 |
| `ix_temporary_groups_expires_at` | `expires_at` | 期限切れ判定と削除処理用。 |

## 場所の保存

`location` は表示名で、Hot Pepper検索の原点は `location_id` または
`custom_location_id` から解決する。

| input | saved origin | search behavior |
| --- | --- | --- |
| 駅・市区町村を選択 | `location_id` | `locations` と子テーブルから緯度経度を取得する。 |
| 現在地から入力 | `custom_location_id` | `custom_locations` の緯度経度をそのまま使う。 |
| 場所指定なし | なし | 店舗検索は行わず `not_requested` にする。 |

`location_id` と `custom_location_id` は同時に使わない。
`location` だけを送る自由入力は、検索原点が解決できないためAPIで400にする。

## 投票状態

進行状態は時刻から計算し、`phase` 自体は保存しない。

| phase | condition |
| --- | --- |
| `waiting` | `voting_started_at IS NULL` |
| `swiping` | `voting_started_at IS NOT NULL` かつ `voting_completed_at IS NULL` |
| `result` | `voting_completed_at IS NOT NULL` |

個々の投票は `temporary_group_votes` に保存する。全参加者が保存済み店舗候補の
すべてへ投票すると `voting_completed_at` を一度だけ設定する。

## 参加人数

`participant_count` は必要人数を表す。現在の参加人数は `temporary_group_participants` の件数から計算する。

```sql
SELECT COUNT(*)
FROM temporary_group_participants
WHERE temporary_group_id = :group_id;
```

満員判定は `joined_participant_count >= participant_count` で行う。`is_full` はDBカラムとしては持たず、APIレスポンスで返す。

## 有効期限

一時グループは `expires_at > now` の場合のみ有効。

API検索では必ず `expires_at > now` を条件に含める。期限切れ行がDBに残っていても、取得・参加はできない。

## 期限切れ行の削除

期限切れ行は後処理で物理削除する。

```sh
cd backend
make cleanup-temporary-groups
```

内部ではSQLAlchemy ORMで以下の条件に一致する行を削除する。

```python
TemporaryGroup.expires_at <= datetime.now(UTC)
```

削除ジョブが遅れても、API側の有効期限判定により期限切れグループは利用不可のまま。

## Alembic

`temporary_groups` は以下のmigrationで作成する。

```text
backend/alembic/versions/202607150001_create_temporary_groups.py
backend/alembic/versions/202607230001_add_temporary_group_details.py
backend/alembic/versions/202607290001_add_restaurant_search_status.py
backend/alembic/versions/202607290002_add_temporary_group_voting.py
backend/alembic/versions/202607300001_create_locations.py
backend/alembic/versions/202607300002_create_custom_locations.py
backend/alembic/versions/202607310001_add_temporary_group_voting_completed_at.py
backend/alembic/versions/202608010001_add_temporary_group_selected_restaurant.py
```

既存DB構成は `feature/setup-db-etc` の方針に合わせ、`POSTGRES_*` 環境変数からDB URLを組み立てる。
