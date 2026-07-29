# temporary_group_participants

一時グループと匿名ユーザーの参加関係を保存する中間テーブル。

| column | type | null | description |
| --- | --- | --- | --- |
| `id` | `UUID` | no | 参加レコードのUUID。 |
| `temporary_group_id` | `UUID` | no | 参加先の `temporary_groups.id`。 |
| `anonymous_user_id` | `UUID` | no | 参加者の `anonymous_users.id`。 |
| `joined_at` | `TIMESTAMP WITH TIME ZONE` | no | 初回参加日時。 |
| `last_seen_at` | `TIMESTAMP WITH TIME ZONE` | no | 最終参加確認日時。 |

## Constraints and Indexes

| name | target | purpose |
| --- | --- | --- |
| primary key | `id` | UUIDで一意に取得する。 |
| foreign key | `temporary_group_id` | 一時グループ削除時に参加レコードも削除する。 |
| foreign key | `anonymous_user_id` | 匿名ユーザー削除時に参加レコードも削除する。 |
| `uq_temporary_group_participants_group_user` | `temporary_group_id`, `anonymous_user_id` | 同じ匿名ユーザーの二重参加を防ぐ。 |
| `ix_temporary_group_participants_temporary_group_id` | `temporary_group_id` | 参加人数集計用。 |
| `ix_temporary_group_participants_anonymous_user_id` | `anonymous_user_id` | ユーザー側からの参加状態確認用。 |

## 参加人数

現在の参加人数はこのテーブルの件数から計算する。

```sql
SELECT COUNT(*)
FROM temporary_group_participants
WHERE temporary_group_id = :group_id;
```

満員判定は `temporary_groups.participant_count` と現在の参加人数を比較して行う。`is_full` はDBカラムとしては持たず、APIレスポンスで計算結果を返す。
