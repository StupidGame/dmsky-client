import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/repository/account_repository.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/util/server_utils.dart";
import "package:dmsky_client/view/common/dialog/dialog_state.dart";
import "package:dmsky_client/view/common/modal_indicator.dart";
import "package:dmsky_client/view/login_page/centraing_widget.dart";
import "package:dmsky_client/view/login_page/misskey_server_list_dialog.dart";
import "package:url_launcher/url_launcher.dart";

class MiAuthLogin extends ConsumerStatefulWidget {
  const MiAuthLogin({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => MiAuthLoginState();
}

class MiAuthLoginState extends ConsumerState<MiAuthLogin> {
  final serverController = TextEditingController();
  bool isAuthed = false;

  @override
  void dispose() {
    serverController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    try {
      IndicatorView.showIndicator(context);
      await ref
          .read(accountRepositoryProvider.notifier)
          .validateMiAuth(normalizeServer(serverController.text));
      if (!mounted) return;
      await context.router.pushAndPopUntil(
        const SplashRoute(),
        predicate: (_) => false,
      );
    } catch (e) {
      rethrow;
    } finally {
      if (mounted) {
        IndicatorView.hideIndicator(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CenteringWidget(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: [
                TableRow(
                  children: [
                    Text(S.of(context).server),
                    TextField(
                      controller: serverController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.dns),
                        suffixIcon: IconButton(
                          onPressed: () async {
                            final url = await showDialog<String?>(
                              context: context,
                              builder: (context) =>
                                  const MisskeyServerListDialog(),
                            );
                            if (url != null && url.isNotEmpty) {
                              serverController.text = url;
                            }
                          },
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 10)),
                    Container(),
                  ],
                ),
                TableRow(
                  children: [
                    Container(),
                    ElevatedButton(
                      onPressed: () async {
                        await ref.read(dialogStateProvider.notifier).guard(
                          () async {
                            final repository = ref.read(
                              accountRepositoryProvider.notifier,
                            );
                            final server = normalizeServer(
                              serverController.text,
                            );
                            if (kIsWeb) {
                              await repository.prepareMiAuth(server);
                            } else {
                              await repository.openMiAuth(server);
                            }
                            if (mounted) setState(() => isAuthed = true);
                          },
                        );
                      },
                      child: Text(
                        kIsWeb
                            ? "認証リンクを準備"
                            : isAuthed
                            ? S.of(context).reauthorizate
                            : S.of(context).authorizate,
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 10)),
                    Container(),
                  ],
                ),
                if (isAuthed && kIsWeb)
                  TableRow(
                    children: [
                      const SizedBox(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElevatedButton(
                          onPressed: () async {
                            final uri = ref
                                .read(accountRepositoryProvider.notifier)
                                .authorizationUri;
                            if (uri != null) {
                              await launchUrl(uri, webOnlyWindowName: "_blank");
                            }
                          },
                          child: const Text("サーバーで認証する"),
                        ),
                      ),
                    ],
                  ),
                if (isAuthed)
                  TableRow(
                    children: [
                      Container(),
                      ElevatedButton(
                        onPressed: () async => ref
                            .read(dialogStateProvider.notifier)
                            .guard(() => login()),
                        child: Text(S.of(context).didAuthorize),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
