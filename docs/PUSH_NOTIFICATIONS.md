# プッシュ通知の実装と配信ゲートウェイ契約

この文書は DMSKY Client と配信ゲートウェイ間の通知データ契約、各OSの設定、および未完了項目を記録します。Misskey の標準APIではない独自契約です。

## 現在の実装状況

| 項目 | 状況 |
| --- | --- |
| 通知ペイロード v1 の検証 | クライアント実装・単体テストあり |
| Android FCM クライアント | Firebase Messaging 初期化、権限要求、トークン取得、更新監視、通知表示・タップ処理を追加 |
| Android UnifiedPush クライアント | Distributor 検出・選択、登録要求、endpoint/暗号鍵のゲートウェイ登録、受信・表示を追加。VAPID公開鍵は現行register APIへ指定可能 |
| iOS APNs / FCM クライアント | APNs entitlement、remote-notification background mode、権限要求、APNs token確認、FCM token/タップ処理を追加 |
| Web FCM クライアント | Web VAPID、Firebase Messaging、Service Worker、バックグラウンド通知・クリック時の復帰処理を追加 |
| 端末登録APIサーバー | `server/push-gateway` に実装済み。PostgreSQL登録、Misskeyトークン本人確認、AES-256-GCM暗号化保存、登録解除APIあり。**未配備** |
| Misskey通知イベントの購読・配信処理 | `main` Streaming channel の `notification` / `messagingMessage` 受信、再接続、送信処理を実装済み。**実サーバー連携は未検証** |
| FCM / APNs / Web Push送信 | Firebase Admin / Web Pushの送信処理を実装済み。**Firebaseプロジェクト、APNs鍵、VAPID鍵は未設定** |
| 終了中の実機受信試験 | **未実施** |

クライアント受信コードと配信ゲートウェイのソースコードは追加済みです。FCM／UnifiedPushの有効化はアカウントごとにユーザーが選択し、その選択状態を端末内に保存します。別アカウントを自動で有効化しません。ゲートウェイは `server/push-gateway` に実装しましたが、まだサーバーへ配備されておらず、Firebase/APNs/VAPID資格情報も設定されていません。そのため現時点で実際に通知が届く状態ではありません。

## ペイロード v1

すべての値は文字列として送信します。

| Key | 必須 | 説明 |
| --- | --- | --- |
| `v` | yes | 固定値 `1` |
| `eventId` | yes | 配信イベントの一意 ID。クライアント側の重複抑制に使用 |
| `host` | yes | アカウントのMisskeyホスト。任意URLやパスは不可 |
| `target` | yes | `note` / `user` / `chat` / `notifications` |
| `noteId` | target=note | 遷移先ノートID |
| `userId` | target=user | 遷移先ユーザーID |
| `chatId` | target=chat | `room:<room-id>` または `user:<user-id>`。遷移先のルーム／個人チャットID |

APIトークン、アクセストークン、メールアドレス、通知本文などの秘密情報・個人情報をdata payloadに含めないでください。通知本文はロック画面に表示される可能性があるため、ユーザーのプライバシー設定に従って別途扱います。

## ゲートウェイAPI契約

クライアントは `DMSKY_PUSH_GATEWAY_URL` を基点に以下を呼び出します。ゲートウェイはHTTPSで公開してください（localhost開発環境を除く）。

### 端末登録

`POST /v1/device-registrations`

Authorizationヘッダーには対象アカウントのMisskey APIトークンをBearer形式で送ります。**このトークンは設定したゲートウェイへ送信されます。運営者が管理する信頼済みのHTTPSゲートウェイ以外を指定しないでください。** ゲートウェイはMisskeyの `i` APIで本人確認した後、Streaming APIの再接続に必要なためAES-256-GCMで暗号化してDBへ保存します。FCM登録トークンとUnifiedPush endpoint・暗号鍵もAES-256-GCMで暗号化して保存し、送信時のみ復号します。旧バージョンの平文JSONB登録情報は起動時に暗号化移行して平文列をNULLにします。平文トークン・Authorizationヘッダーはアプリ／ゲートウェイのログ、解析イベント、エラートラッキングに出してはいけません。ゲートウェイのアクセスログでもAuthorizationヘッダーを必ずマスクしてください。

```json
{
  "schemaVersion": 1,
  "deviceId": "stable-installation-id",
  "platform": "android|ios|web|macos|linux",
  "provider": "fcm|unifiedpush",
  "account": {
    "host": "misskey.example",
    "userId": "misskey-user-id"
  },
  "registration": {
    "token": "FCM-registration-token"
  }
}
```

UnifiedPushの `registration` は以下の形式です。

```json
{
  "endpoint": "https://push.example/endpoint",
  "keys": {
    "p256dh": "base64url-public-key",
    "auth": "base64url-auth-secret"
  },
  "temporary": false
}
```

ゲートウェイはMisskeyサーバーへ認証を確認し、tokenを送ったアカウント本人であることを検証してから登録します。FCM/APNs送信にはFirebase Admin SDK等を利用し、UnifiedPush endpointにはWeb Push暗号化・VAPID認証を使って送信します。認証キーはゲートウェイのSecret管理にだけ置きます。

### 端末登録解除

`DELETE /v1/device-registrations`

Authorizationヘッダーは対象アカウントのMisskey APIトークンです。bodyは以下です。

```json
{
  "schemaVersion": 1,
  "deviceId": "stable-installation-id",
  "account": {
    "host": "misskey.example",
    "userId": "misskey-user-id"
  }
}
```

この端末・アカウントに紐づくFCMおよびUnifiedPush登録をすべて冪等に解除します。アカウント削除前にこの処理が成功するか、未送信の解除要求を安全に再試行できる実装が必要です。

### ゲートウェイ実装と残作業

ゲートウェイのソースコードは `server/push-gateway` に追加しました。MisskeyホストとUnifiedPush endpointのHTTPS／公開IP検証、Misskeyトークンによる本人確認、アカウント・端末・providerごとの登録管理、暗号化保存、Misskey Streaming購読、FCM／Web Push送信、失効endpointの削除、再接続、`i/notifications` の `sinceId` 差分回収、イベントIDによる重複抑制、簡易レート制限を実装しています。TypeScriptの型チェックCIは成功しています。

まだ必要な作業:

1. PostgreSQLとゲートウェイを常時稼働するサーバーへ配備し、HTTPSリバースプロキシを設定する。
2. Misskey通知イベントの実サーバー別差分、通知内容・チャットIDのマッピングを実環境で検証する。通知履歴は `i/notifications` の `sinceId` で回復しますが、チャットメッセージ履歴の切断中回復は未実装です。
3. FCM token失効、Web Push 404/410、端末ごとの送信再試行、複数端末の部分失敗・重複配信を実機検証する。
4. Firebaseサービスアカウント、Firebase ConsoleのAPNs認証キー、Web Push VAPID秘密鍵をSecret管理に設定する。アプリやGitリポジトリに含めない。
5. Misskey APIトークンの最小権限、HTTPS、DBバックアップと暗号鍵のローテーション、egress firewallを運用設定する。

起動手順と運用上の注意は [server/push-gateway/README.md](../server/push-gateway/README.md) を参照してください。

## ビルド設定

### Firebase共通

以下をFlutterビルドの `--dart-define` で渡します。Firebaseのクライアント用APIキーとApp IDは公開設定値ですが、管理者秘密鍵ではありません。

- `DMSKY_FIREBASE_API_KEY`
- `DMSKY_FIREBASE_PROJECT_ID`
- `DMSKY_FIREBASE_SENDER_ID`
- `DMSKY_FIREBASE_ANDROID_APP_ID`
- `DMSKY_FIREBASE_IOS_APP_ID`
- `DMSKY_FIREBASE_WEB_APP_ID`
- `DMSKY_FIREBASE_MACOS_APP_ID`（任意）
- `DMSKY_PUSH_GATEWAY_URL`
- `DMSKY_UNIFIEDPUSH_VAPID_KEY`（VAPIDを要求するDistributor用・公開鍵）

Webは追加で以下を設定します。

- `DMSKY_FIREBASE_WEB_VAPID_KEY`

Firebase ConsoleでWeb Push証明書の公開VAPID鍵を作成し、Webビルドへ渡してください。

### Android

- Android 13以降の通知権限をアプリから要求します。
- FirebaseプロジェクトにAndroid App IDを登録します。
- 実機でFCM受信を確認してください。
- UnifiedPushを使う場合は、対応Distributorアプリを端末にインストールし、アプリの通知設定から選択してください。
- VAPID を必要とする Distributor では、公開鍵を `DMSKY_UNIFIEDPUSH_VAPID_KEY` に設定します。VAPIDを要求しないDistributorでは空欄でも利用できます。

### iOS

- Apple Developer側で対象App IDのPush Notifications capabilityを有効にし、対応するProvisioning Profileを作成します。
- Firebase ConsoleにAPNs認証キーを登録します。
- DebugはAPNs development、Release/Profileはproduction entitlementを使用します。
- iPhone実機でAPNs tokenが取得できることを確認してください。シミュレーターだけでは終了中通知の完了判定をしません。

### Web

`web/firebase-config.js.example` を `web/firebase-config.js` にコピーし、Firebase ConsoleのWeb App設定値で埋めてください。このファイルは公開クライアント設定だけを含みます。Firebase AdminのサービスアカウントJSONやVAPID秘密鍵を配置してはいけません。

HTTPS配信が必須です。Service Workerがバックグラウンド通知を表示し、通知クリック時にはFlutterアプリをペイロード付きURLで開きます。

## リリース完了条件

- `server/push-gateway` をステージング／本番へ配備し、TLS・PostgreSQL・暗号鍵を設定する。
- Firebase Admin、APNs、Web Pushの送信資格情報をSecret管理に設定する。UnifiedPushはDistributorがVAPIDを要求する場合に公開鍵を設定する。
- Misskey通知イベントから各providerへ配信されることを確認する。
- Android／iOS／Webでforeground・background・終了状態を実機または実ブラウザーで検証する。
- 通知タップのノート／ユーザー／チャット／通知一覧への遷移、複数アカウント分離、ログアウト解除、token更新・失効・権限拒否を確認する。
- CI全プラットフォーム成功と実機検証が揃うまでIssue #3は未完了とし、PRを完成扱い・マージしない。
