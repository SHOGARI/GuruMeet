# temporary_group_votes

匿名参加者ごとの店舗候補への投票を保存するテーブル。

| column | type | null | description |
| --- | --- | --- | --- |
| `id` | `UUID` | no | 投票レコードのUUID。 |
| `temporary_group_id` | `UUID` | no | 投票対象の `temporary_groups.id`。 |
| `anonymous_user_id` | `UUID` | no | 投票者の `anonymous_users.id`。 |
| `restaurant_id` | `VARCHAR(128)` | no | `temporary_groups.restaurant.restaurants[].id`。店舗マスタFKではない。 |
| `liked` | `BOOLEAN` | no | `true` は食べたい、`false` は見送り。 |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | no | 初回投票日時。 |
| `updated_at` | `TIMESTAMP WITH TIME ZONE` | no | 投票更新日時。ORM更新時に更新する。 |

## Constraints and Indexes

| name | target | purpose |
| --- | --- | --- |
| primary key | `id` | UUIDで一意に取得する。 |
| foreign key | `temporary_group_id` | グループ削除時に投票もCASCADE削除する。 |
| foreign key | `anonymous_user_id` | 匿名ユーザー削除時に投票もCASCADE削除する。 |
| `uq_temporary_group_votes_group_user_restaurant` | `temporary_group_id`, `anonymous_user_id`, `restaurant_id` | 同じ参加者・候補の投票を1行に限定する。 |
| `ix_temporary_group_votes_temporary_group_id` | `temporary_group_id` | グループ単位の進捗・結果集計用。 |
| `ix_temporary_group_votes_anonymous_user_id` | `anonymous_user_id` | 参加者単位の投票取得用。 |

同じ候補へ再投票した場合は行を追加せず `liked` を更新する。投票完了後は、
同じ値の冪等な再送だけを受け付け、内容変更は拒否する。

候補数は `temporary_groups.restaurant` の `restaurants` 配列長で決まる。
全参加者の投票行数がそれぞれ候補数に達したとき、グループの
`voting_completed_at` を設定する。

## Alembic

```text
backend/alembic/versions/202607290002_add_temporary_group_voting.py
```
