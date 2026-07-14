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
flutter run -d web-server
```

Chromeが利用可能な場合：

```
flutter run -d chrome
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

モック実装

現在はバックエンド未接続のため、以下はモックです。

- 招待URL
- 飲食店データ
- 参加メンバー
- グループ作成処理
- 店舗のマッチ判定
- 共有ボタンの一部挙動

仮の招待URL：

https://gurumeet.app/join/demo-group

今後の接続予定

- グループ作成API
- 招待URL発行
- URLからのグループ参加
- 待機ルームのリアルタイム同期
- ホットペッパーグルメAPIからの店舗取得
- 投票結果の送信
- マッチ結果の取得
- Google Maps連携
