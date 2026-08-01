# 匿名参加と一時グループ設計

ユーザー登録なしで一時グループへ参加できるようにしつつ、普通のユーザーのリロード、戻る、再送信、別タブ操作で二重参加にならないようにする。

## 目的

この設計で守るのは、本人確認ではなく操作ミスによる二重参加防止。

```text
守る:
  同じブラウザでリロードして再参加しても1人扱い
  戻る/進むや通信遅延で参加APIが再送されても1人扱い
  別タブで同じURLを開いても1人扱い

割り切る:
  localStorage/cookie削除
  別ブラウザ
  別端末
  シークレットセッションを閉じた後の再入室
```

悪意あるユーザーを完全に防ぐにはログイン、メール認証、SMS認証、招待枠トークンのような強い本人確認が必要になる。初期実装ではそこまではやらない。

## 識別方針

frontendは初回アクセス時にランダムな `participant_token` を生成する。

```text
participant_token = crypto.randomUUID()
```

同じ値を2箇所に保存する。

```text
localStorage:
  gurumeet_participant_token

cookie:
  gurumeet_participant_token
```

起動時は以下の順で復元する。

```text
1. localStorage にあれば使う
2. localStorage がなくcookieがあれば、cookieからlocalStorageへ復元する
3. cookie がなくlocalStorageがあれば、localStorageからcookieへ復元する
4. 両方なければ新規生成して両方へ保存する
```

`localStorage` と `cookie` は保存場所であり、DBには保存しない。DBに保存するのは `participant_token` をbackend側でhash化した値。

```text
participant_token_hash = sha256(PARTICIPANT_TOKEN_HASH_SECRET + participant_token)
```

`PARTICIPANT_TOKEN_HASH_SECRET` はサーバー秘密値として扱う。本番値は以下のように生成する。

```sh
openssl rand -hex 32
```

この値はfrontendへ渡さず、Gitにもコミットしない。途中で変更すると既存の匿名ユーザーと照合できなくなる。
staging / production では GitHub Environment secrets の `PARTICIPANT_TOKEN_HASH_SECRET` に登録する。

## テーブル

```text
temporary_groups
  id
  code
  creator_id
  participant_count
  location
  location_id
  custom_location_id
  budget_min
  budget_max
  restaurant
  restaurant_search_status
  voting_started_at
  voting_completed_at
  selected_restaurant_id
  created_at
  expires_at

anonymous_users
  id
  participant_token_hash
  created_at
  last_seen_at

temporary_group_participants
  id
  temporary_group_id
  anonymous_user_id
  joined_at
  last_seen_at

temporary_group_votes
  id
  temporary_group_id
  anonymous_user_id
  restaurant_id
  liked
  created_at
  updated_at
```

`temporary_groups` に参加者ID配列は持たない。配列にすると外部キー、重複防止、参加日時、同時実行制御が扱いづらくなるため、中間テーブルで参加関係を表す。

## 制約

```text
anonymous_users.participant_token_hash
  unique

temporary_group_participants.temporary_group_id
  foreign key -> temporary_groups.id

temporary_group_participants.anonymous_user_id
  foreign key -> anonymous_users.id

temporary_group_participants(temporary_group_id, anonymous_user_id)
  unique

temporary_group_votes.temporary_group_id
  foreign key -> temporary_groups.id

temporary_group_votes.anonymous_user_id
  foreign key -> anonymous_users.id

temporary_group_votes(temporary_group_id, anonymous_user_id, restaurant_id)
  unique
```

`UNIQUE(temporary_group_id, anonymous_user_id)` により、同じ匿名ユーザーが同じ一時グループに複数回参加しても1人扱いになる。

## 参加処理

UUID参加とコード参加は、入口が違うだけで同じ参加ロジックを使う。

```text
1. temporary_groups を有効期限つきで検索する
2. 参加対象の temporary_groups 行を FOR UPDATE でロックする
3. participant_token をhash化する
4. anonymous_users を取得、なければ作成する
5. temporary_group_participants に既存行があるか見る
6. 既存行があれば last_seen_at を更新して既存参加として返す
7. 未参加なら現在参加人数を count する
8. participant_count に達していれば 409 Conflict
9. 空きがあれば temporary_group_participants を作成する
```

`FOR UPDATE` を使う理由は、同時参加リクエストで定員を超えないようにするため。

## 満員判定

満員状態はDBカラムとして持たない。

```text
joined_participant_count = COUNT(temporary_group_participants)
is_full = joined_participant_count >= temporary_groups.participant_count
```

`is_full` をDBに持つと、参加、再参加、削除、期限切れ処理のたびに整合性を保つ必要が出る。初期実装では都度計算し、APIレスポンスだけに含める。

## API

作成者を参加者として登録したい場合:

```text
POST /temporary-groups
  participant_token を渡す
```

共有URLから参加する場合:

```text
POST /temporary-groups/{group_id}/participants
  participant_token を渡す
```

手入力コードから参加する場合:

```text
POST /temporary-groups/join
  code と participant_token を渡す
```

詳細表示だけの場合:

```text
GET /temporary-groups/{group_id}
```

詳細レスポンスには現在人数表示用に以下を含める。

```text
joined_participant_count
is_full
phase
```

投票では同じ `participant_token` を使い、DB内部の `anonymous_user_id` と照合する。

```text
POST /temporary-groups/{group_id}/voting/start
POST /temporary-groups/{group_id}/votes
GET  /temporary-groups/{group_id}/voting/progress
GET  /temporary-groups/{group_id}/voting/result
POST /temporary-groups/{group_id}/voting/result/decision
```

## 投票と店舗決定

投票開始は参加者であることを要求する。予定人数 `participant_count` がある場合は、
その人数が参加済みになるまで開始しない。

各参加者は保存済みの全店舗候補へ `liked=true/false` を1件ずつ送る。
`UNIQUE(temporary_group_id, anonymous_user_id, restaurant_id)` により、再送時は
同じ投票行を更新する。

```text
全参加者が全候補へ投票
  -> voting_completed_at を設定
  -> like_count降順で集計
  -> 単独1位なら results[0] を決定店舗として扱う
  -> 同率1位ならホストが1店舗を選び selected_restaurant_id を設定
```

`phase` は保存せず、`voting_started_at` / `voting_completed_at` から
`waiting` / `swiping` / `result` を計算する。

## フロント表示

人数表示はAPIレスポンスの値を使う。

```text
joined_participant_count / participant_count
```

例:

```text
2 / 4人
```

`is_full` が `true` の場合、新規参加ボタンやスワイプ開始導線を満員状態にする。ただし同じ `participant_token` の既存参加者は再入室できる。

## 限界

この方式はブラウザ単位の匿名識別であり、本人確認ではない。

```text
別ブラウザ:
  別参加者扱い

別端末:
  別参加者扱い

localStorage/cookie削除:
  別参加者扱い

シークレットを閉じて開き直す:
  別参加者扱い
```

IPやUser-Agentは将来、rate limitや「同じ端末っぽい参加があります」という確認用途で追加できる。ただし同じWi-Fiの複数人を誤判定しやすいため、人数カウントの主識別子にはしない。
