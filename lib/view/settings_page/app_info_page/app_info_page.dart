import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:dmsky_client/view/common/misskey_notes/mfm_text.dart";
import "package:dmsky_client/view/themes/dmsky_circuit.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "app_info_page.g.dart";

@riverpod
Future<PackageInfo> packageInfo(Ref ref) async =>
    await PackageInfo.fromPlatform();

@RoutePage()
class AppInfoPage extends ConsumerWidget {
  const AppInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).aboutMiria)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AccountContextScope.as(
            account: ref.read(accountsProvider).first,
            child: Column(
              children: [
                MfmText(
                  mfmText:
                      '''
<center>\$[x3 DMSKY Client]</center>
${S.of(context).packageName}: ${packageInfo?.packageName ?? ""}
${S.of(context).version}: ${packageInfo?.version ?? ""}+${packageInfo?.buildNumber ?? ""}

DMSKY デザインの Misskey クライアントです。
Miria のコードを基盤とし、DMSKY のテーマと素材を使用しています。

\$[x2 **${S.of(context).aboutMiria}**]
[ソースコード・ビルド](https://github.com/StupidGame/dmsky-client)
[DMSKY](https://github.com/StupidGame/dmsky)

\$[x2 **謝辞**]
[Miria](https://github.com/shiosyakeyakini-info/miria) — @shiosyakeyakini@misskey.io と貢献者の皆さま
[Misskey](https://github.com/misskey-dev/misskey) — syuilo と貢献者の皆さま
Aria を機能の比較対象にしています。独立した派生クライアントです。

\$[x2 **${S.of(context).openSourceLicense}**]
''',
                ),
                ElevatedButton(
                  onPressed: () async {
                    showLicensePage(
                      context: context,
                      applicationName: packageInfo?.appName.toString(),
                      applicationIcon: const DmskyEmblem(),
                      applicationVersion:
                          "${packageInfo?.version ?? ""}+${packageInfo?.buildNumber.toString() ?? ""}",
                    );
                  },
                  child: Text(S.of(context).showLicense),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
