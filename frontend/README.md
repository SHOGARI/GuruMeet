# frontend

Frontend

GuruMeetのフロントエンドはFlutterで実装しています。

ユーザーがグループを作成し、参加者を招待して、飲食店候補をスワイプしながら店を決定するまでの画面と操作を担当します。

ユーザーフロー

Home
→ グループ作成
→ 人数・エリア・予算を入力
→ 招待URLを共有
→ 参加者が集合
→ 店選びを開始
→ 店舗候補をスワイプ
→ マッチした店舗を表示
→ 店舗詳細を確認
→ Google Mapsを開く

技術構成

- Flutter
- Dart
- Material 3

起動方法

リポジトリ直下からfrontendディレクトリへ移動します。

```
cd frontend
```

依存関係を取得します。

```
flutter pub get
```

Webで起動する場合：

```
make dev
```

Chromeが利用可能な場合：

```
make dev-chrome
```

ローカル起動ポートは `frontend/.env` の `FRONTEND_PORT` で固定します。

```env
FRONTEND_PORT=3000
```

実APIへ接続する場合は、Flutter起動またはbuild時に以下を渡します。

```sh
flutter run -d chrome \
  --dart-define=GURUMEET_ENABLE_MOCKS=false \
  --dart-define=GURUMEET_API_BASE_URL=http://localhost:8000 \
  --dart-define=GURUMEET_INVITE_BASE_URL=http://localhost:3000
```

本番デプロイ時は `GURUMEET_API_BASE_URL` を公開APIのURL、
`GURUMEET_INVITE_BASE_URL` を公開フロントエンドURLにしてください。
招待URLとQRコードは `GURUMEET_INVITE_BASE_URL/#/join/{roomId}` 形式で生成されます。

`make dev` は内部で以下を実行します。

```sh
flutter run -d web-server --web-hostname 0.0.0.0 --web-port ${FRONTEND_PORT}
```

`make dev-chrome` は内部で以下を実行します。

```sh
flutter run -d chrome --web-port ${FRONTEND_PORT}
```

iOSまたはAndroid実機・シミュレータで起動する場合：

```
flutter devices
flutter run -d <device-id>
```

品質確認

```
flutter format .
flutter analyze
flutter test
```

現在の実装範囲

- ホーム画面
- グループ作成画面
- 人数・エリア・予算の入力
- グループ作成完了画面
- 招待URLの表示・コピー
- 各画面のルーティング
- フロントエンド上の入力バリデーション

モック切り替え

`GURUMEET_ENABLE_MOCKS=true` の場合はUI確認用のモックデータを使います。
公開環境では必ず `false` にしてください。
