# Android のバックグラウンド通知

[HyperionRSSReader の RssUpdateWorker](https://github.com/StupidGame/HyperionRSSReader/blob/master/app/src/main/java/io/github/stupidgame/hyperionrssreader/worker/RssUpdateWorker.kt) と同じく、Android WorkManager による定期取得と NotificationChannel による端末通知を使います。
Firebase・配信サーバー・Google Play 開発者向け設定は不要です。

## 使い方

1. 設定 → アカウント管理 → 対象アカウントを開きます。
2. 「バックグラウンド通知」を有効にし、端末の通知許可を与えます。
3. 確認間隔を15・30・60分から選びます。「今すぐ確認」で次の取得を予約できます。
4. 通知の音・表示方法は「端末の通知設定」で、アカウントごとに変更できます。

HTTPS のサーバーへログインしたアカウントが対象です。MiAuth の通常ログインは通知を読む権限も要求します。
手動の API キーを使う場合は `read:notifications` が必要です。
最後の確認時刻・取得エラー・端末の通知許可の状態は設定画面で確認できます。

## 動作

- 初回の取得は基準点の保存だけを行い、過去の通知は一斉表示しません。
- 以後は `/api/i/notifications` を `markAsRead: false` で取得し、新着の ID を記録します。定期取得だけで既読にはしません。
- `sinceId` の指定により古い順のページが返る場合も、ページ内の最新の通知までを記録します。
- 同じ ID の通知や既読と判定できる通知は再通知しません。複数の新着はアカウントごとに1件へまとめます。
- 通知を押すとアプリ内の該当アカウントの通知一覧へ移動します。終了状態からの起動にも対応します。
- 通信失敗はバックオフ付きで再試行し、認証・権限のエラーは設定画面に表示します。
- 認証情報は Android Keystore で暗号化し、バックアップ対象外のアプリ専用領域へ保存します。
- アプリ起動時にログイン情報を同期します。アカウント削除時は定期処理・通知・保存した認証情報を削除します。

## 対応範囲と検証

この実装は Android 専用です。iOS・Web・Linux・Windows のビルドではネイティブ通知処理を呼びません。
FCM/APNs のような即時配信ではなく、[WorkManager の最小間隔は15分](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work)です。
OS の省電力制御、ネットワーク制約、端末メーカーの設定によって実行が遅れます。設定画面からアプリを強制停止した場合は、再度アプリを開くまで取得できません。

通知の初回抑制・重複除外・取得順序・アカウント識別は Android の単体テストで、設定操作と画面遷移先の判別は Flutter テストで検証します。
実際の OS 通知、再起動後の実行、通知を押した際の起動は、対象端末でログインして確認してください。
