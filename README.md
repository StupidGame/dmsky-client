# DMSKY Client

<p align="center"><img src="assets/branding/dmsky-emblem.png" alt="DMSKY" width="144"></p>

[![Build all platforms](https://github.com/StupidGame/dmsky-client/actions/workflows/build.yml/badge.svg)](https://github.com/StupidGame/dmsky-client/actions/workflows/build.yml)

[DMSKY](https://github.com/StupidGame/dmsky) のデザインを使う、Flutter 製の Misskey クライアントです。
青い発光パネル、銀色の多重フレーム、金色の選択表示、都市背景とエンブレムを取り入れています。
機能は [Miria](https://github.com/shiosyakeyakini-info/miria) を基盤とし、[Aria](https://github.com/poppingmoon/aria) も比較対象にしています。

**開発中です。Aria・Miria の全機能との一致、およびすべてのサーバー・OS での動作確認が完了した製品ではありません。**
実装状況と検証の違いは [機能対応表](docs/FEATURES.md) に記載しています。

## ダウンロード

[Build all platforms の実行一覧](https://github.com/StupidGame/dmsky-client/actions/workflows/build.yml)から対象の実行を開き、**Summary → Downloads → ダウンロード**のリンクを選びます。
GitHubへのログインが必要です。Androidは `dmsky-client-android` のZIPを展開し、中のAPKをインストールします。
同じ画面からiOS・Linux・Windows・Webの成果物も選べます。iOSは未署名です。

テストなどのジョブだけを再実行した場合も、Downloadsジョブが以前のビルド成果物を最新の実行へ再掲します。
初回実行へ切り替える操作は不要です。ビルド失敗・期限切れで取得できない環境は一覧に「未作成・期限切れ」と表示します。
成果物の保存期間は30日です。

## 対応プラットフォーム・成果物

| 環境 | Actions の成果物 | 備考 |
| --- | --- | --- |
| Android | arm64 APK（標準） | 固定のリリース鍵で署名。universal APK・AAB は手動実行時のオプション |
| iOS | `dmsky-client-ios-unsigned.tar.gz` | 未署名の `Runner.app`。実機・TestFlight 配布には Apple の署名が必要 |
| Linux x64 | `dmsky-client-linux-x64.tar.gz` | 実行ファイル・共有ライブラリ・データのバンドル |
| Windows x64 | `dmsky-client-windows-x64.zip` | EXE・DLL・データのバンドル |
| Web | `dmsky-client-web` | Web サーバーに置く静的ファイル一式 |

## 主な機能

- MiAuth・API キーログイン、複数サーバー・複数アカウント。
- ホーム・ローカル・ソーシャル・グローバル・リスト・アンテナ・チャンネル・ロールのタイムライン。
- タブ追加・並べ替え・設定、左右スワイプ、複数列のデッキ表示、ストリーミング。タブにはユーザー名とサーバー名を表示。
- 投稿、返信、Renote、引用、公開範囲、ローカル限定、CW、添付、NSFW、説明文、投票、下書き。
- MFM、カスタム絵文字、リアクション選択・履歴・デッキ、リアクション・単語ミュート。
- 通知、お気に入り、クリップ、リスト・アンテナ編集、チャンネル、検索・探索。
- Play の一覧・検索・ユーザー別一覧と、Android・iOS のアプリ内実行画面。
- Android のバックグラウンド通知。アカウントごとに15・30・60分の定期取得を設定。Firebase の設定は不要。
- プロフィール・フォロー関係・プロフィール編集、ミュート・ブロック、サーバー情報・お知らせ。
- 対応サーバーでの個人・ルームチャット、添付、検索、メッセージ操作。
- DMSKY ライト・ダークテーマ、フォント・文字サイズ、設定のインポート・エクスポート。

サーバーのバージョン・権限・設定や OS によって利用できる機能が異なります。
Aria 独自機能などの制限は [機能対応表](docs/FEATURES.md) を確認してください。

## GitHub Actions でビルド

### 手動実行

1. [Actions](https://github.com/StupidGame/dmsky-client/actions/workflows/build.yml) の **Build all platforms** を選択します。
2. **Run workflow** をクリックします。
3. ブランチを選び、緑色の **Run workflow** をクリックします。
4. ワークフロー・署名検証ツールのチェックと、アプリ本体の静的解析・テストが通ると、５環境のビルドが実行されます。
5. 実行結果の **Summary → Downloads → ダウンロード** から成果物を選びます。**Artifacts** にも同じ5環境のファイルが表示されます。

手動起動には書き込み権限と、既定ブランチ上のワークフローが必要です。
Android は最初に [署名鍵の設定](docs/ANDROID_SIGNING.md) が必要です。
標準は軽量な `arm64` APK です。手動実行の `android_apk` で `universal` を選択でき、
`build_aab` を有効にしたときだけ AAB も作成します。

### 自動実行

`main`・`develop` への push、Pull Request、`v` から始まるタグの push でも実行します。
署名鍵を使う Android 配布ビルドは push・手動実行と、同じリポジトリ内のブランチからの Pull Request で実行します。外部フォークの Pull Request では実行しません。
ストアへの自動公開は行いません。成果物は30日、解析・テストログとカバレッジは14日保存します。
解析やテストが失敗した場合も、`test-results` に実行ログを保存し、生成済みのカバレッジを回収します。
iOS・Linux・Windows・Web は共通のビルド定義を使い、1環境が失敗しても他のビルドを継続します。
設定は [`.github/workflows/build.yml`](.github/workflows/build.yml) にあります。

## 開発・起動

Flutter **3.47.9** を [`.fvmrc`](.fvmrc) に固定しています。Dart は同梱版を使用します。
Android は JDK 21・Android SDK、iOS は macOS・Xcode・CocoaPods、
Windows は Visual Studio の「C++ によるデスクトップ開発」が必要です。

```bash
git clone https://github.com/StupidGame/dmsky-client.git
cd dmsky-client
flutter pub get --enforce-lockfile
flutter run
```

FVM を使う場合は `fvm install` 後、`flutter` を `fvm flutter` に読み替えます。

Linux の依存関係の例（Ubuntu 24.04）：

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  libsecret-1-dev libstdc++-12-dev liblzma-dev nasm
flutter run -d linux
```

Android の共有ストレージ（`/sdcard`・`/mnt/sdcard` 等）は開発用シンボリックリンクを作れません。
該当する場合は Termux のホーム等、通常のファイルシステムに clone してビルドしてください。

## ログイン

サーバーのアドレス（例：`misskey.example`）を入力し、**MiAuth** でブラウザーを開きます。
サーバーで許可した後、アプリへ戻って認証完了のボタンを押してください。
Web では「認証リンクを準備」→「サーバーで認証する」の順に進みます。
API キーによるログインにも対応しています。

認証情報はセキュアストレージへ保存します。Web は HTTPS または localhost が必要です。
接続先の CORS 設定も影響します。HTTP の開発サーバーは `http://localhost:3000` のように明示してください。
モバイル OS で HTTP を使う場合は別途開発用の通信許可が必要です。

## Play

Miria 由来の「探索 → Play」「検索 → Play」「ユーザーページ → Play」から選ぶと、
Android・iOS ではアプリ内ブラウザーで実行画面を開きます。投稿中の `/play/...` リンクと「ゲーム → Play」からも開けます。
サーバー側の Play・AiScript 実行環境を利用し、必要な場合は画面内でサーバーへログインします。
Web 表示側のログイン状態を使うため、アプリのアカウントとは別途ログインが必要な場合があります。
WebView 非対応環境ではブラウザーを開くボタンを表示します。

## Android のバックグラウンド通知

**設定 → アカウント管理 → 対象アカウント → バックグラウンド通知** で有効にします。
初回は通知を許可し、確認間隔を選んでください。通知を押すと、そのアカウントの通知一覧を開きます。
初回の過去通知は表示せず、その後の新着を定期取得します。
WorkManager による定期取得方式のため、即時配信ではなく、省電力設定などで遅れる場合があります。
詳細は [バックグラウンド通知](docs/BACKGROUND_NOTIFICATIONS.md) を参照してください。

## ローカルでビルド

タブに任意の Material Icon を指定できるため、アイコンの削減を無効にします。

```bash
flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons
# 必要な場合のみ、全 ABI の APK や AAB を作成
flutter build apk --release --target-platform android-arm,android-arm64,android-x64 --no-tree-shake-icons
flutter build appbundle --release --target-platform android-arm64 --no-tree-shake-icons
flutter build ios --release --no-codesign --no-tree-shake-icons
flutter build linux --release --no-tree-shake-icons
flutter build windows --release --no-tree-shake-icons
flutter build web --no-wasm-dry-run --release --base-href / --no-tree-shake-icons
```

iOS・Linux・Windows は対応する OS 上でビルドします。
Android のリリースビルドは、[固定鍵を復号した署名環境](docs/ANDROID_SIGNING.md) が必要です。デバッグ鍵への自動切り替えはしません。
Linux・Windows は実行ファイルだけでなく、生成されたフォルダー全体を配布してください。
Web は `build/web` を Web サーバーに配置します。`index.html` を直接開く方法には対応しません。

## 検証・再生成

```bash
flutter analyze --no-fatal-infos lib
flutter test --coverage
python3 -m unittest discover -s tool -p 'test_*.py'
```

ワークフローは固定バージョンの [actionlint](https://github.com/rhysd/actionlint) でも検証します。ローカルでは `actionlint` で同じチェックを実行できます。
Android はリリース APK を Android 16 エミュレーターへインストールし、新規起動とホーム画面からの再表示でプロセスが終了しないことも検証します。
失敗時の logcat・起動画面は `android-startup-results` に保存します。署名済み配布 APK と同じ最適化設定で確認するため、単体テストでは検出できない起動時の問題も検出できます。

生成済み Dart ファイルも含んでいます。モデル・ルート・翻訳を変更した場合は再生成します。

```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
dart run flutter_launcher_icons
```

## 軽量化

- ライセンス画面とブランド表示で画像を共用し、同じ画像の二重同梱（2,033,370 bytes）を解消しています。
- エンブレムは画面密度と表示サイズに合わせてデコードし、小さなロゴのために元画像全体を展開しません。
- タイムラインは行ごとの全件リスト複製をやめ、必要な投稿を直接参照します。投稿順序・追加読み込みの位置は維持しています。

## 構成

| 場所 | 内容 |
| --- | --- |
| `lib/view/themes/dmsky_circuit.dart` | 色・フレーム・ボタン・ブランド表示 |
| `lib/view/login_page/` | ログイン・MiAuth・API キー |
| `lib/view/time_line_page/` | タイムライン・タブ・デッキ |
| `lib/view/` | 投稿・通知・チャット・プロフィール等 |
| `lib/repository/` | API・ストリーミング・アカウント・設定 |
| `lib/state_notifier/` | 画面の状態・操作 |
| `assets/branding/` | DMSKY の背景・エンブレム・アイコン |
| `test/` | 継承したテストと DMSKY の検証 |
| `android/signing/` | 暗号化した固定署名鍵と公開証明書 |
| `tool/` | 署名鍵の復号・APK の証明書と ABI の検証 |

## ライセンス・謝辞

**GNU AGPL v3**。詳細は [LICENSE](LICENSE) と [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) を参照してください。

- [Miria](https://github.com/shiosyakeyakini-info/miria)：アプリとテストの基盤。
- [DMSKY](https://github.com/StupidGame/dmsky)：配色・フレーム・背景・エンブレム。
- [Misskey](https://github.com/misskey-dev/misskey)：サーバーとプロトコル。
- [Aria](https://github.com/poppingmoon/aria)：機能の比較対象。

Misskey・Miria・Aria の公式アプリではありません。開発者・貢献者の皆さまへ感謝します。
