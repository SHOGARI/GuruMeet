# Docs

GuruMeet の仕様、設計、運用手順、外部資料を置くディレクトリ。

## 置き場所のルール

| directory | purpose |
| --- | --- |
| [`api/`](./api/) | backend API の仕様、request / response、エラーポリシー。 |
| [`database/`](./database/) | DB schema、ER図、テーブル定義。 |
| [`designs/`](./designs/) | 設計判断、採用方針、検討メモ。 |
| [`development/`](./development/) | 開発時のルール、ブランチ運用、ローカル開発方針。 |
| [`legal/`](./legal/) | アプリ内に表示する規約、プライバシー、問い合わせ、ライセンス文書。 |
| [`migration/`](./migration/) | Alembic migration の運用方針。 |
| [`reference/`](./reference/) | 外部サービス説明、構築手順、運用手順、データ投入台帳、参考資料。 |

迷った場合は、判断理由や方針は `designs/`、他人が手順として読む説明書は
`reference/` に置く。APIやDBの確定仕様は、それぞれ `api/` / `database/` に置く。

## 機密情報の扱い

docs には secret、API key、DB接続文字列、取得済みCSV本体を貼らない。
記載してよいのは環境変数名、placeholder、生成コマンド、保管場所の説明まで。

例:

```env
HOTPEPPER_API_KEY=<Recruit Web Service API key>
PARTICIPANT_TOKEN_HASH_SECRET=change_me_to_a_long_random_value
```
