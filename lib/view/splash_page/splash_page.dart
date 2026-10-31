import "package:dmsky_client/util/app_platform.dart";

import "package:auto_route/auto_route.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/licenses.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/repository/account_repository.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/view/themes/dmsky_circuit.dart";
import "package:receive_sharing_intent/receive_sharing_intent.dart";

@RoutePage()
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => SplashPageState();
}

class SplashPageState extends ConsumerState<SplashPage> {
  static bool _isFirst = true;

  List<String> initialSharingMedias = [];
  String initialSharingText = "";
  late final Future<void> initialization;

  @override
  void initState() {
    super.initState();
    initialization = initialize();
  }

  Future<void> initialize() async {
    await ref.read(accountRepositoryProvider.notifier).load();
    await ref.read(tabSettingsRepositoryProvider).load();
    await ref.read(accountSettingsRepositoryProvider).load();
    await ref.read(generalSettingsRepositoryProvider).load();

    for (final account in ref.read(accountsProvider)) {
      await ref.read(emojiRepositoryProvider(account)).loadFromLocalCache();
    }

    if (_isFirst) {
      if (AppPlatform.isAndroid || AppPlatform.isIOS) {
        final initialMedia = await ReceiveSharingIntent.instance
            .getInitialMedia();
        initialSharingMedias = [];
        initialSharingText = "";

        for (final file in initialMedia) {
          if (file.type == SharedMediaType.text) {
            initialSharingText = file.path;
          } else {
            initialSharingMedias.add(file.path);
          }
        }

        await ReceiveSharingIntent.instance.reset();
      }

      LicenseRegistry.addLicense(
        () => Stream.fromIterable(miriaInheritedLicenses),
      );
    }

    _isFirst = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 16),
                    const Text("保存された設定を読み込めませんでした。"),
                    const SizedBox(height: 12),
                    SelectableText(snapshot.error.toString()),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.replaceRoute(const LoginRoute()),
                      child: const Text("ログイン画面を開く"),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.done) {
            final accounts = ref.read(accountsProvider);
            final isSigned = accounts.isNotEmpty;
            final hasTabSetting = ref
                .read(tabSettingsRepositoryProvider)
                .tabSettings
                .isNotEmpty;

            if (isSigned && hasTabSetting) {
              context.replaceRoute(
                TimeLineRoute(
                  initialTabSetting: ref
                      .read(tabSettingsRepositoryProvider)
                      .tabSettings
                      .first,
                ),
              );
              if (initialSharingMedias.isNotEmpty ||
                  initialSharingText.isNotEmpty) {
                if (accounts.length == 1) {
                  context.pushRoute(
                    NoteCreateRoute(
                      initialMediaFiles: initialSharingMedias,
                      initialText: initialSharingText,
                      initialAccount: accounts.first,
                    ),
                  );
                } else {
                  context.pushRoute(
                    SharingAccountSelectRoute(
                      filePath: initialSharingMedias,
                      sharingText: initialSharingText,
                    ),
                  );
                }
              }
            } else if (isSigned && !hasTabSetting) {
              // KeyChainに保存したデータだけアンインストールしても残るので
              // この状況が発生する
              Future(() async {
                for (final account in accounts) {
                  await ref
                      .read(accountRepositoryProvider.notifier)
                      .remove(account);
                }
                if (!mounted) return;

                await context.replaceRoute(const LoginRoute());
              });
            } else {
              context.replaceRoute(const LoginRoute());
            }
          }

          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DmskyBrand(large: true),
                SizedBox(height: 32),
                CircularProgressIndicator.adaptive(),
              ],
            ),
          );
        },
      ),
    );
  }
}
