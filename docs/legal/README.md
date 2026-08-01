# Legal documents

GuruMeet のアプリ内フッターに表示する法務・問い合わせ文書の正本です。

| document | app footer |
| --- | --- |
| [プライバシーポリシー](./privacy-policy.md) | プライバシーポリシー |
| [利用規約](./terms-of-service.md) | 利用規約 |
| [お問い合わせ](./contact.md) | お問い合わせ |
| [ライセンス](./licenses.md) | ライセンス |

文書を変更したら、`frontend` ディレクトリで次を実行します。

```sh
dart run tool/generate_legal_content.dart
```

生成先は `frontend/lib/generated/legal_documents.g.dart` です。通常の `make dev`、
`make analyze`、`make test` では生成処理が先に実行されます。CI は生成結果に差分が
残っていないことを検証し、デプロイ時にも再生成するため、docs の内容がアプリ表示の
正本になります。

法令、利用サービス、保存項目、保存期間、問い合わせ先を変更した場合は、実装とこの
ディレクトリを同じ変更で更新してください。
