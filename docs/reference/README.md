# Reference

外部サービス、構築手順、運用手順、データ投入記録など、他人が説明書として読むドキュメントを置く。

設計判断や比較検討は [`../designs/`](../designs/) に置く。
API仕様は [`../api/`](../api/)、DB定義は [`../database/`](../database/) に置く。

## Documents

- [Cloudflare サービスリファレンス](./cloudflare-services.md)
- [Cloudflare Workers 構築手順](./cloudflare-construct.md)
- [Database Foundation](./database-foundation.md)
- [External Data And Services](./external-services.md)
- [Location Data Import](./location-data-import.md)
- [Location Data Versions](./location-data-versions.md)

## 機密情報

実値の secret、API key、DB接続文字列、有料CSV本体は置かない。
必要な場合は、環境変数名、placeholder、保存先、生成方法だけを書く。
