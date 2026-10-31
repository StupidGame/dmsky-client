# Android の固定署名鍵

配布する APK は **universal APK** です。`armeabi-v7a`・`arm64-v8a`・`x86_64` を１つに収録します。
更新時の署名は同じ RSA-4096 の鍵を使用し、ビルドごとに新しい鍵を作りません。

| ファイル・設定 | 内容 |
| --- | --- |
| `android/signing/release-key.gpg` | AES-256 で暗号化した PKCS12 キーストアと署名設定 |
| `android/signing/certificate.pem` | 公開証明書。秘密鍵は含みません |
| `android/signing/certificate.sha256` | APK が同じ証明書で署名されていることを確かめる指紋 |
| Actions Secret `ANDROID_SIGNING_PASSPHRASE` | 暗号化ファイルを復号するパスフレーズ |

パスフレーズはリポジトリに含めません。署名鍵を暗号化してリポジトリに置き、復号用の値を Actions Secrets に保存する方式です。
暗号化ファイルにはキーストア本体とパスワードを含めているため、登録する Secret は１つです。

## 初回のみ必要な設定

1. リポジトリの **Settings → Secrets and variables → Actions** を開きます。
2. **New repository secret** を選びます。
3. Name に `ANDROID_SIGNING_PASSPHRASE`、Secret に復号パスフレーズを設定します。
4. **Actions → Build all platforms → Run workflow** を実行します。

[Secret の追加画面](https://github.com/StupidGame/dmsky-client/settings/secrets/actions/new)

この開発環境で作成したパスフレーズは、リポジトリ外の
`/root/.local/share/dmsky-client-signing/passphrase` に、所有者のみ読み書きできる権限で保存しています。
このファイルは commit・成果物への同梱・ログへの出力をしません。
環境を破棄する前に、パスワードマネージャー等にも控えてください。

GitHub CLI が認証済みの同じ環境なら、値を端末へ表示せずに登録できます。

```bash
gh secret set ANDROID_SIGNING_PASSPHRASE \
  --repo StupidGame/dmsky-client \
  < /root/.local/share/dmsky-client-signing/passphrase
```

## CI の動作

1. Secret を使い、GPG を通して署名設定を復号します。
2. キーストアのチェックサムと公開証明書の指紋を確認します。
3. runner の一時領域へキーストアを権限 `0600` で復元します。
4. 固定鍵で universal APK と AAB を署名します。
5. `apksigner` で署名証明書を照合し、APK に３種類の ABI が含まれることを検査します。
6. `dmsky-client-android` に APK・AAB・署名指紋・SHA256SUMS を保存します。
7. 終了時に復号した一時ファイルを削除します。

APK の名前は `dmsky-client-universal.apk` です。
`versionCode` にはワークフロー実行番号を使い、同じ署名で継続して更新できるようにしています。
Secret が未登録・誤りの場合はリリースビルドを失敗させ、デバッグ鍵や代替鍵へ切り替えません。
Pull Request のコードに署名鍵を渡さないため、署名付き Android ジョブは push・手動実行時のみ動かします。

## ローカルでのリリースビルド

GnuPG と Android SDK・JDK 21 を用意します。

```bash
export ANDROID_SIGNING_PASSPHRASE="$(cat /root/.local/share/dmsky-client-signing/passphrase)"
python3 tool/decrypt_android_signing.py
set -a
. /tmp/dmsky-client-signing/signing.env
set +a
flutter build apk --release --target-platform android-arm,android-arm64,android-x64 --no-tree-shake-icons
python3 tool/verify_android_signature.py build/app/outputs/flutter-apk/app-release.apk
```

デバッグ開発は従来どおり `flutter run` または `flutter build apk --debug` が使えます。
Google Play App Signing を使う場合は、この鍵をアップロード鍵とするか、ストア側の設定に合わせて判断してください。

## 参考

- [GitHub：暗号化したファイルを用いた Secrets の管理](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#storing-large-secrets)
- [Flutter：Android の署名](https://docs.flutter.dev/deployment/android#sign-the-app)
