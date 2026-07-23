# Cloudflare サービスリファレンス

## このドキュメントの目的

Cloudflare の各サービスが何を担当するものかを整理する。設計判断は `docs/designs/` に置き、このファイルでは「何のためのサービスか」「GuruMeet で使う可能性があるか」を確認できるようにする。

Cloudflare はサービス数が多く、名前だけでは役割を誤解しやすい。特に `D1`、`R2`、`KV`、`Workers`、`Pages` は用途が違うため混同しない。

参考:

- Cloudflare docs index: https://developers.cloudflare.com/llms.txt
- Cloudflare docs directory: https://developers.cloudflare.com/directory/

## GuruMeet で優先的に見るサービス

| サービス | 種類 | 何をするものか | GuruMeet での使い方 |
| --- | --- | --- | --- |
| Pages | 静的サイト/フロント配信 | build 済み frontend を Cloudflare global network から配信する | 初期は使わない。frontend 独立運用が必要になったら検討 |
| Workers | serverless compute | request を受けて edge で処理する | Flutter Web 配信、API 入口、routing、軽い前処理 |
| Workers Containers / Containers | container runtime | Workers から Docker container image を起動・呼び出す | FastAPI + uvicorn を container として動かす候補 |
| D1 | serverless SQL database | Cloudflare native な SQL DB。SQLite 系 | Workers 中心の小規模 DB なら候補。FastAPI 主 DB には今は使わない |
| R2 | object storage | S3 互換のファイル置き場 | 画像、添付、PDF、アップロードファイル |
| KV | key-value store | global に読める軽量 key-value storage | feature flag、軽い cache、設定値 |
| Durable Objects | stateful compute/storage | 特定 ID に紐づく stateful な Worker object | room/session/state 管理が必要になったら検討 |
| Queues | message queue | 非同期 job を queue に積む | 通知、メール、重い後処理 |
| Workflows | durable workflow | 複数 step の長めの処理を管理する | 複雑な非同期処理が出たら検討 |
| Cron Triggers | scheduled execution | Workers を定期実行する | 定期 cleanup、通知、集計 |
| Hyperdrive | DB acceleration | Workers から外部 DB への接続を高速化・安定化する | PostgreSQL 接続で必要になったら検討 |
| Secrets Store | secrets management | account 横断で secret を安全に管理する | API key、DB credential 管理候補 |
| Turnstile | bot 対策 | CAPTCHA 代替 | signup / login / public form の bot 対策 |
| Access | Zero Trust access control | hostname や app に認証 policy をかける | 管理画面や internal endpoint の保護 |
| DNS | domain management | DNS record を管理する | `stg.gurumeet.net` / `gurumeet.net` の管理 |
| SSL/TLS | TLS 管理 | HTTPS 証明書と TLS 設定 | public domain の HTTPS |
| WAF | web application firewall | HTTP request を rule で保護する | API / frontend の攻撃対策 |
| Cache / CDN | cache | static / dynamic content を cache する | Pages 配信、画像配信、API cache の調整 |
| Web Analytics | analytics | privacy-friendly web analytics | frontend の基本 analytics |
| Logs / Log Explorer | logs | Cloudflare 側の logs を見る/保存する | production 調査に使う |
| Notifications | alerting | Cloudflare account/service の通知 | 障害や設定変更の通知 |
| Terraform / Pulumi | IaC | Cloudflare resource を code 管理する | 構成が固まったら導入候補 |

## Storage / Database 系

| サービス | DB か | 向いているデータ | 向かないデータ |
| --- | --- | --- | --- |
| D1 | はい | SQL で扱う小〜中規模の構造化データ | PostgreSQL 前提の ORM/migration をそのまま使う用途 |
| R2 | いいえ | 画像、動画、PDF、添付ファイル、backup | user table や meeting table のような relational data |
| KV | いいえ | key-value cache、feature flag、設定値 | relational query、強い一貫性が必要な main DB |
| Durable Objects | 部分的に stateful storage | room/session/counter など ID 単位の state | 汎用 RDB の代替 |
| Vectorize | vector database | embedding 検索、類似検索 | 通常の user/meeting DB |
| R2 SQL | query engine | R2 Data Catalog 上の data lake 的な query | app の通常 transaction DB |

### D1

D1 は Cloudflare native な serverless SQL database。SQL semantics を持つ DB で、Workers / Pages Functions と組み合わせやすい。

GuruMeet では、FastAPI + PostgreSQL を主 DB とする方針のため、D1 は最初の main DB にはしない。Cloudflare native な小機能や Workers-only の補助 DB が必要になったら検討する。

### R2

R2 は object storage。S3 互換 API を持つファイル置き場。

GuruMeet での例:

```text
avatars/user_123.png
meetings/meeting_456/material.pdf
exports/report_2026_07.csv
```

PostgreSQL には file body ではなく R2 key や URL を保存する。

### KV

KV は key-value storage。読み取りが多く、単純な key で引けるデータに向く。

例:

```text
feature:enable_waitlist = true
cache:public_settings = {...}
```

ユーザー一覧、参加者一覧、予約状態の source of truth にはしない。

### Durable Objects

Durable Objects は、特定 ID に対して stateful な処理を集約する仕組み。

例:

```text
meeting-room-123 の live state
realtime session state
rate limit counter
```

通常の DB ではなく、同時接続・状態管理が必要な箇所で検討する。

## Compute / Runtime 系

| サービス | 役割 | GuruMeet での位置づけ |
| --- | --- | --- |
| Workers | edge compute | API gateway / routing / lightweight API |
| Pages Functions | Pages に同梱する server-side code | Flutter Pages には基本使わない。軽い frontend 付属処理なら候補 |
| Workers Containers | container execution | FastAPI container の本命候補 |
| Workflows | durable multi-step process | 長い非同期処理が増えたら検討 |
| Queues | message queue | 非同期 job の入口 |
| Cron Triggers | scheduled jobs | 定期処理 |
| Dynamic Workers | isolated Workers on demand | 通常は不要 |
| Sandbox SDK | isolated code execution | ユーザーコード実行などが必要な場合のみ |

### Workers

Workers は serverless application を global に動かす compute。GuruMeet では FastAPI container の前段として、routing、headers、auth 前処理、container 呼び出しに使う。

FastAPI 本体を Workers に直接寄せるのではなく、Workers Containers への入口として使う。

### Workers Containers

Containers は Workers と組み合わせて serverless container を動かす仕組み。任意言語・任意 runtime の container image を扱える。

GuruMeet では FastAPI + uvicorn を Docker image として動かす候補。

注意:

- Workers Paid plan が必要
- `wrangler`、Worker entrypoint、container binding が必要
- 通常の container hosting より構成が特殊

### Pages Functions

Pages Functions は Pages project に server-side code を足す機能。Cloudflare docs では Pages Functions は Workers を使って dynamic functionality を足すものとして説明されている。

GuruMeet では frontend は Flutter Web の静的配信が主目的なので、backend API は Pages Functions に寄せず、Worker + Workers Containers に分ける。

## Frontend / Delivery 系

| サービス | 役割 | GuruMeet での位置づけ |
| --- | --- | --- |
| Pages | 静的 frontend 配信 | Flutter Web |
| Cache / CDN | cache / delivery | static assets と必要な API cache |
| Images | 画像の保存・変換・配信 | R2 だけで足りなくなったら検討 |
| Stream | 動画保存・配信 | 録画/動画配信が出たら検討 |
| Zaraz | third-party scripts | analytics/tag 管理が必要になったら検討 |
| Web Analytics | analytics | frontend の軽量 analytics |

### Pages

Flutter Web は `flutter build web` 後に静的ファイルになるため、Pages にも載せやすい。

想定:

```text
Build command: flutter build web
Output: build/web
```

GuruMeet 初期構成では Pages は使わず、Workers Static Assets で Worker と一体 deploy する。frontend だけ独立 deploy / preview したくなったら Pages を検討する。

## Security / Access 系

| サービス | 役割 | GuruMeet での位置づけ |
| --- | --- | --- |
| WAF | Web 攻撃対策 | public frontend / API の基本防御 |
| DDoS Protection | DDoS 対策 | Cloudflare 標準の強み |
| Turnstile | bot 対策 | signup / login / form |
| Access | Zero Trust access | admin / internal endpoint 保護 |
| API Shield | API 保護 | API が育ったら検討 |
| Rate Limiting | request 制限 | login / signup / public API |
| Secrets Store | secret 管理 | API key / credential 管理候補 |

### Access

Access は Cloudflare 側で hostname / app に policy をかけるもの。アプリ内認証とは別レイヤー。

例:

```text
stg.gurumeet.net -> Access で保護
gurumeet.net     -> public app として公開
```

Cloudflare Access と backend app の JWT/session 認証を混同しない。

## Network / Domain 系

| サービス | 役割 | GuruMeet での位置づけ |
| --- | --- | --- |
| DNS | DNS 管理 | app/api domain 管理 |
| Registrar | domain 登録 | Cloudflare Registrar を使うなら |
| SSL/TLS | HTTPS | public domain の TLS |
| Load Balancing | 複数 origin の振り分け | backend が複数 origin になったら |
| Health Checks | origin 監視 | backend production 監視 |
| Cloudflare Tunnel | private origin 公開 | VPS/private host を公開する場合 |
| Spectrum | TCP/UDP proxy | 通常の web/API では不要 |

### Cloudflare Tunnel

Cloudflare Tunnel は private origin を public IP なしで Cloudflare に接続する仕組み。VPS や homelab に backend を置く場合の候補。

Workers Containers を使う場合は、backend runtime が Cloudflare 側にあるため、Tunnel は初期構成では不要。

## Observability / Operations 系

| サービス | 役割 | GuruMeet での位置づけ |
| --- | --- | --- |
| Analytics | Cloudflare service metrics | 全体状況の確認 |
| Web Analytics | frontend analytics | user traffic の軽量把握 |
| Logs | detailed logs | production 調査 |
| Log Explorer | dashboard/API で logs を調査 | incident 調査 |
| Notifications | 通知 | 障害・設定変更通知 |
| Version Management | config rollout | 構成が増えたら検討 |
| Resource Tagging | resource 整理 | Cloudflare resource が増えたら |

## AI / Media / Advanced 系

| サービス | 役割 | GuruMeet での位置づけ |
| --- | --- | --- |
| Workers AI | AI model execution | AI 機能が出たら |
| AI Gateway | AI API gateway | OpenAI 等を使う時の観測・制御 |
| AI Search | managed RAG | 検索/FAQ が必要なら |
| Vectorize | vector DB | embedding search |
| Browser Run | headless browser | 自動 screenshot / scraping 等 |
| Realtime / SFU / TURN | realtime media | video/audio meeting 機能が必要なら |
| Stream | video storage/streaming | 録画配信 |
| Images | image transform/delivery | 画像変換が増えたら |

## GuruMeet の初期採用マップ

| 段階 | 採用 | 保留 |
| --- | --- | --- |
| 初期 frontend deploy | Workers Static Assets | Pages, Zaraz, Images, Stream |
| 初期 backend deploy | Workers + Workers Containers | Pages Functions |
| 初期 DB | Neon PostgreSQL | D1 |
| 初期 file storage | R2 | Images |
| 初期 security | Cloudflare Access for staging, DNS, SSL/TLS, WAF basics | API Shield |
| 初期 async | まだ不要 | Queues, Workflows, Cron |
| 初期 observability | Cloudflare dashboard / Logs later | Logpush 等の高度運用 |

## 無料枠・課金の目安

2026-07-14 時点で公式 docs を確認した目安。Cloudflare の pricing / limits は変わる可能性があるため、実際に採用する直前に公式 pricing を再確認する。

| サービス | 無料枠の目安 | 有料化・注意点 | GuruMeet での見方 |
| --- | --- | --- | --- |
| Pages | Free plan で 500 builds/month、20,000 files/site、custom domains 100/project | build timeout や file 数の上限がある | Flutter Web の初期配信は無料で始めやすい |
| Workers | Free で 100,000 requests/day、CPU 10ms/invocation | Paid は最低 $5/month。Standard では 10 million requests/month included | 軽い routing / API gateway は無料で試せる |
| Workers Containers | Free ではなく Workers Paid 前提 | Workers Paid の最低 $5/month が必要。container 使用量は別途課金対象 | FastAPI + Docker を Cloudflare に載せるならここが最低課金ライン |
| R2 | 10 GB-month、Class A 1 million/month、Class B 10 million/month、egress free | storage / operations が増えると従量課金 | 画像・添付ファイルは小規模なら無料枠で始めやすい |
| D1 | 5 million rows read/day、100,000 rows written/day、5 GB total | Free で daily limit を超えると query が失敗する | Workers-native な小規模 DB なら無料で試せる。FastAPI 主 DB には今は使わない |
| KV | Free で read 100,000/day、write 1,000/day、delete 1,000/day、list 1,000/day、1 GB storage | 書き込みが多い用途には向かない | feature flag / 軽い cache なら無料枠で十分 |
| Hyperdrive | Free で 100,000 queries/day | PostgreSQL 接続の補助。Workers pricing 側で扱う | 外部 PostgreSQL 接続が課題になったら検討 |
| Queues | Free で 10,000 operations/day | Paid は included 分を超えると operations 課金 | 通知・メールなどの小さい非同期処理は無料で試せる |
| Durable Objects | Free で 100,000 requests/day、13,000 GB-s/day | active duration / storage に注意 | realtime state や room state が必要になったら検討 |
| Workflows | Free で 100,000 requests/day、3,000 steps/day、1 GB storage | steps / storage / CPU が増えると課金 | 複数 step の非同期処理が必要になったら検討 |
| Vectorize | Free 枠あり。ただし用途は AI/vector search | Workers Paid 専用機能や included 枠の条件に注意 | 初期 GuruMeet では不要 |

### 今回の最小コスト感

Cloudflare を使い倒しつつ、FastAPI + Docker を維持するなら、Workers Containers のために Cloudflare 側で最低 $5/month を見込む。

```text
frontend:
  Workers Static Assets で Worker と一体 deploy

backend:
  Workers Containers を使うなら Workers Paid $5/month から

file storage:
  R2 は小規模なら無料枠で開始可能

cache / queue:
  KV / Queues は小規模なら無料枠で開始可能

main DB:
  PostgreSQL は Cloudflare 外の managed DB 料金を見る
```

完全無料に寄せる場合は、FastAPI + Docker ではなく Workers-native な構成に変える必要がある。

```text
frontend:
  Workers Static Assets または Pages

backend:
  Workers

database:
  D1

file storage:
  R2
```

ただし、この構成は FastAPI + PostgreSQL + Docker の設計とは別物になる。

### 課金面の判断

GuruMeet の現方針では、Cloudflare 無料枠だけで全部を完結させるより、次の前提で考える。

```text
Cloudflare:
  Workers Paid $5/month を許容する

PostgreSQL:
  GuruMeet では Neon を採用する
  local は Docker Compose PostgreSQL
  staging / production は Neon PostgreSQL
```

初期段階で避けるべきこと:

- Workers Containers を使うのに「完全無料」を前提にする
- R2 / KV / D1 を main DB の代替として雑に使う
- pricing を確認せずに R2 へ大きいファイルを大量保存する
- D1 Free の daily read/write limit を本番 traffic 前提で見落とす

## 混同しやすいもの

### D1 と R2

```text
D1 = SQL database
R2 = file/object storage
```

D1 には user / meeting のような record を入れる。R2 には画像/PDF/録音などの file body を入れる。

### KV と D1

```text
KV = key で値を取る cache/storage
D1 = SQL で query する database
```

KV は速く読む設定や cache に向く。main DB にはしない。

### Workers と Workers Containers

```text
Workers = request を処理する edge runtime
Workers Containers = Worker から呼び出す container runtime
```

FastAPI を Docker image として動かすなら Workers Containers を使う。Worker はその前段の入口。

### Access と app 認証

```text
Access = Cloudflare 側の入口制御
app 認証 = GuruMeet の user login/session/JWT
```

管理画面は Access で守れるが、一般ユーザーの login は app 側で実装する。

## 公式リンク

- Directory: https://developers.cloudflare.com/directory/
- Workers pricing: https://developers.cloudflare.com/workers/platform/pricing/
- Pages limits: https://developers.cloudflare.com/pages/platform/limits/
- R2 pricing: https://developers.cloudflare.com/r2/pricing/
- D1 pricing: https://developers.cloudflare.com/d1/platform/pricing/
- Pages: https://developers.cloudflare.com/pages/
- Workers: https://developers.cloudflare.com/workers/
- Containers: https://developers.cloudflare.com/containers/
- D1: https://developers.cloudflare.com/d1/
- R2: https://developers.cloudflare.com/r2/
- KV: https://developers.cloudflare.com/kv/
- Durable Objects: https://developers.cloudflare.com/durable-objects/
- Queues: https://developers.cloudflare.com/queues/
- Workflows: https://developers.cloudflare.com/workflows/
- Hyperdrive: https://developers.cloudflare.com/hyperdrive/
- Turnstile: https://developers.cloudflare.com/turnstile/
- Access: https://developers.cloudflare.com/cloudflare-one/applications/
- WAF: https://developers.cloudflare.com/waf/
- DNS: https://developers.cloudflare.com/dns/
- SSL/TLS: https://developers.cloudflare.com/ssl/
- Cloudflare Tunnel: https://developers.cloudflare.com/tunnel/
