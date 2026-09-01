# Discord Alert 設計

## 目的

Cloudflare Worker / Container の運用で、課金事故や異常に気づけるようにする。

ただし、alert のために余計な backend container 起動を増やさない。通知は「すでに container が起きている処理」または「Worker だけで完結する処理」のついでに送る。

## 方針

```text
やる:
  一時グループ作成時の利用通知
  店舗決定時の結果通知
  cleanup command の結果通知
  cleanup command の失敗通知

やらない:
  container wake 検知だけを目的にした定期監視
  Discord 通知のためだけに /api/* を叩く処理
  高頻度 polling に反応する毎回通知
  初期実装でのCSV出力や詳細分析レポート作成
```

## 通知先

Discord Incoming Webhook を使う。

今回の用途は GuruMeet から Discord channel へ一方向に通知を送るだけなので、Discord bot は作らない。

```text
Incoming Webhook:
  外部サービスから Discord channel へ HTTP POST でメッセージを送る
  bot user や常時接続は不要

Bot:
  Discord 内のユーザー操作に応答する
  slash command や interaction を扱う
  今回の alert 目的では不要
```

Webhook URL は secret として扱う。

```text
DISCORD_ALERT_WEBHOOK_URL
```

staging / production は別の webhook URL を使う。GitHub Environment secrets では同じ secret 名 `DISCORD_ALERT_WEBHOOK_URL` を使い、`staging` と `production` にそれぞれ別の値を登録する。

payload には `environment` を必ず含める。

## Webhook 作成手順

Discord server の管理権限を持つユーザーが作成する。

```text
1. Discord server を開く
2. Server Settings を開く
3. Integrations を開く
4. Webhooks を開く
5. New Webhook または Create Webhook を選ぶ
6. 通知先 channel を選ぶ
7. webhook 名を設定する
8. Copy Webhook URL で URL を取得する
9. URL を GitHub Environment secrets / Cloudflare secrets に登録する
```

webhook URL は token を含むため、Git やログに出さない。

命名例:

```text
gurumeet-staging-alert
gurumeet-production-alert
```

実装前に手元から疎通確認する場合は、URL を shell history に残さない方法で送る。

```sh
curl -X POST "$DISCORD_ALERT_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content":"gurumeet alert test"}'
```

## 通知イベント

### cleanup trigger

期限切れ一時グループ削除は、Discord slash command から任意のタイミングで実行する。

理由:

```text
不要な定期起動を避ける
staging / production の cleanup を明示的な運用操作にする
```

### group_created

一時グループ作成が成功したタイミングで送る。

目的:

```text
実利用の把握
staging の意図しない利用検知
production の利用発生確認
```

送る情報:

```text
event: group_created
environment
group_id
participant_count
location
budget
restaurant_search_status
```

注意:

```text
個人情報や participant_token は送らない
restaurant の詳細情報は必要になるまで送らない
```

### cleanup_completed

Discord slash command から期限切れ一時グループ削除が完了したタイミングで送る。

目的:

```text
手動 cleanup が動いたことの確認
削除件数の把握
container が cleanup command で起きた理由の記録
```

送る情報:

```text
event: cleanup_completed
environment
deleted_expired_temporary_groups
report_summary
triggered_at
```

cleanup は期限切れ一時グループを削除する最後のタイミングなので、削除前に利用状況を集計する。

Discord にはざっくりした要約を送る。

```text
expired_groups
total_expected_participants
total_joined_participants
total_votes
groups_with_votes
top_locations
```

注意:

```text
participant_token や participant_token_hash は出力しない
個人を追える粒度の値は出力しない
restaurant の詳細 JSON は初期実装では出力しない
```

### cleanup_failed

cleanup command が失敗したタイミングで送る。

目的:

```text
期限切れデータが残り続ける状態の検知
DB 接続や secret 設定ミスの早期発見
```

送る情報:

```text
event: cleanup_failed
environment
status
message
triggered_at
```

失敗通知は必ず送る。成功通知は手動実行ごとなので、実行回数が増える場合は通知先を分ける。

### restaurant_decided

投票完了によって単独1位が決まった時点、または同率1位からホストが
最終決定した時点で送る。

目的:

```text
group_created と照合して、作成されたグループが実際に店舗決定まで進んだかを見る
投票完了数、候補数、同率有無、上位店舗を把握する
```

送る情報:

```text
event: restaurant_decided
environment
group_id
participant_count
joined/completed
is_complete
location
has_tie
top_like_count
top_restaurant_name
created_to_result_viewed_minutes
```

投票結果の単なる再取得では通知しない。同率決定APIも決定済みの場合は現在結果を
冪等に返し、通知を再送しない。

## 実装位置

```text
backend:
  group_created 通知
  cleanup_completed 通知

worker:
  cleanup_failed 通知
```

group 作成と cleanup 成功は backend container 内の処理結果を持っているため、backend 側で送る。

cleanup failed は Worker が container から non-2xx response を受け取った時点で検知できるため、Worker 側でも送れる。

## 失敗時の扱い

Discord webhook 送信に失敗しても、元の API / cleanup 処理は失敗させない。

```text
通知失敗:
  logging のみ
  business 処理は継続
```

通知は補助情報であり、ユーザー操作や cleanup の成否を左右させない。

## 将来検討

必要になったら以下を追加する。

```text
Container active time の日次サマリ
Worker / Container 5xx 件数の集計通知
同一 path / user-agent の短周期アクセス検知
月間利用量の予算アラート
cleanup report の BigQuery / spreadsheet 連携
cleanup CSV の R2 保存
```

これらは Cloudflare Metrics / Logs / Billing usage を見て設計する。最初から入れるとノイズと実装コストが増えるため、初期実装では扱わない。

## References

- Discord Intro to Webhooks: https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks
- Discord Developer Docs Webhooks: https://docs.discord.com/developers/platform/webhooks
- Discord Webhook Resource: https://docs.discord.com/developers/resources/webhook
