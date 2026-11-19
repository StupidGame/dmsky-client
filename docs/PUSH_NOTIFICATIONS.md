# Androidのバックグラウンド通知

[HyperionRSSReader](https://github.com/StupidGame/HyperionRSSReader)と同じ、AndroidのWorkManagerで定期取得し、端末内で通知を表示する方式です。Firebase、UnifiedPush、追加の配信アプリ、通知サーバーの登録は不要です。

## 設定方法

1. DMSKYへ、通知を受け取りたいMisskeyアカウントでログインします。
2. 対象アカウントに切り替え、メニューの「設定」→「通知」を開きます。
3. 「バックグラウンド通知」をオンにし、Androidの通知権限を許可します。
4. 「確認間隔」を15・30・60分から選びます。「今すぐ確認」でも取得を予約できます。

アカウント別設定の「バックグラウンド通知」からも、同じ設定を変更できます。複数アカウントを使う場合は、それぞれのアカウントで有効にしてください。通知チャネルと取得ジョブもアカウントごとに分かれます。

## 動作

- 初回は現在の最新通知を基準にし、過去の通知をまとめて表示しません。
- 新着はMisskeyの `i/notifications` APIから取得し、既読にはしません。
- 通知をタップすると、通知元のアカウントの通知一覧を開きます。同じサーバーに複数アカウントがあっても、サーバーとユーザーIDを照合します。
- 通信が一時的に失敗した場合はWorkManagerへ再試行を返します。
- アプリを開き直すと有効なアカウントの認証情報を同期します。無効化・アカウント削除時には、取得ジョブと保存済み認証情報を削除します。
- 認証情報はAndroid Keystoreを使って暗号化し、端末内に保存します。

WorkManagerの定期処理は最短15分です。実際の実行時刻は通信状態やAndroidの省電力制御に左右されるため、指定間隔ちょうどの即時配信は保証しません。[Android公式説明](https://developer.android.com/reference/kotlin/androidx/work/PeriodicWorkRequest)

## 実装と検証

Flutter側は `lib/service/background_notification_service.dart`、Android側は `android/app/src/main/kotlin/app/dmsky/dmsky_client/notifications/` にあります。通知表示のためにFlutterエンジンをバックグラウンド起動する必要はありません。

アカウント分離、設定の有効化・解除、更新間隔、権限拒否、通知タップの対応アカウント選択は、既存のサービス・画面テストをローカルで実行して確認できます。ActionsはAndroid・iOS・Windows・Linux・Webのビルドと成果物公開に統一しており、解析・テスト・起動検証は実行しません。各端末の省電力制御による遅延や、長時間のバックグラウンド動作は実機で確認する必要があります。

## 以前の即時通知サーバー

WorkManager方式への統一に伴い、Firebase・UnifiedPushのクライアント、配信ゲートウェイのソース、専用のCIをこの変更から取り除きました。試験用に作成したCloudflareゲートウェイは登録データがないことを確認し、公開URLとプレビューURLを無効化しています。Vercelの試験用プロジェクトも自動配備を停止しています。
