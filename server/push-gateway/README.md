# DMSKY Push Gateway

DMSKY Client へ FCM と UnifiedPush の通知を配信するための常駐ゲートウェイです。Misskey のユーザーごとの `main` Streaming channel を1接続ずつ購読し、通知イベントとチャットメッセージを登録済み端末へ転送します。

## 構成

- HTTP API: `POST /v1/device-registrations` と `DELETE /v1/device-registrations`
- PostgreSQL: Misskeyトークン、FCM登録トークン、UnifiedPush endpoint・暗号鍵をすべてAES-256-GCMで暗号化して保存
- Misskey Streaming API: `main` チャンネルを購読して `notification` / `messagingMessage` を受信
- Firebase Admin SDK: Android FCM、iOS APNs（Firebase経由）、Web FCMへ送信
- Web Push: UnifiedPush Distributorから受け取ったendpoint・暗号鍵へRFC8291形式で送信
- 再接続: WebSocket切断時は指数バックオフで再接続し、Misskeyの i/notifications を sinceId で差分回収
- 重複抑制・再試行: 通知イベントIDと端末/provider別の配信状態を PostgreSQL に保存し、部分失敗した端末だけを60秒間隔で再試行

## 起動

1. `.env.example` を `.env` にコピーします。
2. `PUSH_TOKEN_ENCRYPTION_KEY` に32バイトの暗号鍵を設定します。

   ```sh
   openssl rand -hex 32
   ```

3. PostgreSQLのパスワードを設定します。Composeの `POSTGRES_PASSWORD` と `DATABASE_URL` のパスワードは一致させてください。
4. Firebase Consoleでサービスアカウントを用意し、`FIREBASE_SERVICE_ACCOUNT_JSON` にSecretとして設定します。Google Cloud上で実行する場合はADC / Workload Identityを利用できます。
5. Firebase ConsoleにiOS APNs認証キーを登録します。APNs秘密鍵はアプリやGitへ入れません。
6. Web Push用の公開・秘密VAPID鍵と `VAPID_SUBJECT` を設定します。
7. Webアプリを配信するoriginを `CORS_ORIGINS` に列挙します。
8. 起動します。

   ```sh
   docker compose up -d --build
   ```

ゲートウェイはコンテナ内8080番で待ち受け、ホスト側では `127.0.0.1:8080` にだけ公開します。Caddy / Nginx等のTLSリバースプロキシを前段に置き、クライアントの `DMSKY_PUSH_GATEWAY_URL` にはHTTPS URLを設定してください。サーバーにはPostgreSQLの永続ボリュームが必要です。サーバーレス関数のようにWebSocketが切断される環境へはそのまま配置できません。

## クライアントの設定

Flutterビルド時に以下を `--dart-define` で指定します。

- `DMSKY_PUSH_GATEWAY_URL`
- Firebaseクライアント設定（API key、Project ID、Sender ID、各platform App ID）
- Android UnifiedPushでVAPIDを要求するDistributorを使う場合は `DMSKY_UNIFIEDPUSH_VAPID_KEY`（公開鍵）
- Webの場合は `DMSKY_FIREBASE_WEB_VAPID_KEY`

Webでは `web/firebase-config.js.example` を `web/firebase-config.js` にコピーし、Firebase ConsoleのWebアプリ設定値を入れてください。Admin SDKのサービスアカウントJSONやVAPID秘密鍵をこのファイルに置かないでください。

## API

### 登録

`POST /v1/device-registrations`

Misskey APIトークンを `Authorization: Bearer <token>` に設定します。ゲートウェイはそのトークンを対象ホストの `POST /api/i` で検証し、要求された `userId` と一致することを確かめます。認証情報はログに出しません。PostgreSQLにはAES-256-GCM暗号化した値だけを保存し、Streaming再接続時に復号します。

FCM登録は `registration.token`、UnifiedPush登録は `registration.endpoint` と `registration.keys.p256dh/auth` を利用します。

### 解除

`DELETE /v1/device-registrations`

Misskeyトークンの再検証後、指定端末・アカウントに属するFCM／UnifiedPush登録を削除します。アカウントに端末登録が残らなくなったらStreaming購読も停止します。

### ヘルスチェック

`GET /health` はPostgreSQLへの接続を確認し、正常時に `{ ok: true }` を返します。アカウント数や機密情報は公開しません。

## セキュリティ運用

- HTTPSのみで公開してください。MisskeyホストとUnifiedPush endpointはHTTPSかつ公開IPへ解決される場合だけ受け付けます。さらに本番ネットワークのegress firewallでRFC1918・loopback・link-local・クラウドmetadata宛て通信を遮断してください（DNS rebinding対策）。
- `PUSH_TOKEN_ENCRYPTION_KEY`、Firebase Admin資格情報、VAPID秘密鍵、DBパスワードはSecret Manager等で管理し、イメージやリポジトリに含めません。
- ロードバランサー、Reverse Proxy、APM、HTTPアクセスログはAuthorizationヘッダーとWebSocket URLの `i` クエリを必ずマスクしてください。
- Misskeyトークンは信頼済みのこのゲートウェイへ送信されます。利用者にゲートウェイURLを任意指定させる場合は、運営元を確認させてください。
- CORSはWebアプリのoriginだけを許可します。モバイルアプリからのリクエストはOriginヘッダーを必要としません。
- FCM tokenの失効とWeb Pushの404/410は端末登録を削除し、最後の端末が失効した場合はStreaming購読も停止します。その他の一時エラーは端末単位で状態を保持し、60秒間隔で再試行します。通知イベントの復旧カーソルは未配信の通知を飛び越えないようにします。
- DBバックアップにも暗号化済みのMisskeyトークン、FCMトークン、UnifiedPush endpoint・鍵が含まれます。endpointは送信権限を持つcapability URLとして扱い、暗号化鍵とバックアップのアクセス権を制限してください。

## 制約

- FCM / APNs資格情報、Firebaseプロジェクト、VAPID鍵、TLS、PostgreSQLは運営者側で設定・配備する必要があります。Firebase Admin資格情報が未設定ならFCM登録を拒否し、VAPID鍵が未設定ならUnifiedPush登録を拒否します。片方のprovider設定不足でゲートウェイ全体は起動不能になりません。
- UnifiedPush 6.2.0では `UnifiedPush.register(instance: instance, vapid: publicKey)` でVAPID公開鍵をDistributorへ渡せます。VAPIDを要求するDistributorでは `DMSKY_UNIFIEDPUSH_VAPID_KEY` に公開鍵を設定してください。Distributorごとの実機互換性はリリース前に確認します。
- Misskey通知は `i/notifications` の `sinceId` でStreaming切断中の履歴を回復します。チャットメッセージは現在ライブStreamingのみで、ゲートウェイ停止・切断中の履歴回復は未実装です。
- 終了中通知の完了判定には、Android・iOS実機とHTTPS Web環境でのフォアグラウンド／バックグラウンド／終了状態テストが必要です。
