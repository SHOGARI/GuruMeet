# anonymous_users

ユーザー登録なしで、同じブラウザからの再参加を同一参加者として扱うための匿名ユーザーテーブル。

| column | type | null | description |
| --- | --- | --- | --- |
| `id` | `UUID` | no | backend側で生成する内部識別子。 |
| `participant_token_hash` | `VARCHAR(64)` | no | frontendがlocalStorageとcookieに保存する匿名トークンのhash。 |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | no | 初回作成日時。 |
| `last_seen_at` | `TIMESTAMP WITH TIME ZONE` | no | 最終利用日時。 |

## Constraints and Indexes

| name | target | purpose |
| --- | --- | --- |
| primary key | `id` | UUIDで一意に取得する。 |
| `uq_anonymous_users_participant_token_hash` | `participant_token_hash` | 同じ匿名トークンを同一ユーザーとして扱う。 |

## Token

frontendは初回アクセス時にランダムな `participant_token` を生成し、localStorageとcookieに同じ値を保存する。

backendは生の `participant_token` を保存しない。`PARTICIPANT_TOKEN_HASH_SECRET` と組み合わせてSHA-256 hashにして保存する。

`PARTICIPANT_TOKEN_HASH_SECRET` は本番では長いランダム値を使う。

生成例:

```sh
openssl rand -hex 32
```

この値はfrontendへ渡さず、Gitにもコミットしない。途中で変更すると既存の `participant_token_hash` と照合できなくなる。
