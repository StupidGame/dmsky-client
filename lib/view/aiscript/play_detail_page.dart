import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:misskey_dart/misskey_dart.dart";
import "package:url_launcher/url_launcher.dart";

import "../../model/account.dart";
import "../../providers.dart";
import "../../rust/api/aiscript.dart";
import "../../rust/api/aiscript/ui.dart";
import "../../rust/frb_generated.dart";
import "../../util/create_aiscript.dart";
import "as_ui_widget.dart";
import "play_editor_page.dart";

class PlayDetailPage extends HookConsumerWidget {
  const PlayDetailPage({
    required this.account,
    required this.playId,
    super.key,
  });

  final Account account;
  final String playId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final misskey = ref.watch(misskeyProvider(account));
    final refresh = useState(0);
    final playFuture = useMemoized(
      () => misskey.flash.show(FlashShowRequest(flashId: playId)),
      [misskey, playId, refresh.value],
    );
    final playSnapshot = useFuture(playFuture);
    final running = useState(false);
    final started = useState(false);
    final script = useState<AiScript?>(null);
    final components = useValueNotifier<Map<String, AsUiComponent>>({});
    final log = useState<String?>(null);
    final play = playSnapshot.data;

    Future<void> stop() async {
      try {
        await script.value?.abort();
      } catch (_) {}
      running.value = false;
      started.value = false;
    }

    Future<void> execute(Flash value) async {
      if (running.value) return;
      running.value = true;
      components.value = {};
      log.value = null;
      try {
        if (!RustLib.instance.initialized) await RustLib.init();
        await script.value?.abort();
        script.value = await createAiScript(
          ref,
          account: account,
          host: account.host,
          token: account.token,
          storageKey: value.id,
          url: Uri(
            scheme: account.scheme ?? "https",
            host: account.host,
            port: account.port,
            pathSegments: ["play", value.id],
          ),
          playId: value.id,
          components: components,
          write: (message) => log.value = message,
        );
        started.value = true;
        await script.value!.exec(
          input: value.script,
          isLegacy: value.updatedAt.isBefore(DateTime.utc(2025, 8, 8))
              ? true
              : value.updatedAt.isBefore(DateTime.utc(2025, 11, 23))
                  ? null
                  : false,
        );
      } catch (error, stack) {
        log.value = "$error\n$stack";
        started.value = false;
      } finally {
        running.value = false;
      }
    }

    Future<void> toggleLike(Flash value) async {
      try {
        if (value.isLiked) {
          await misskey.flash.unlike(FlashUnlikeRequest(flashId: value.id));
        } else {
          await misskey.flash.like(FlashLikeRequest(flashId: value.id));
        }
        refresh.value++;
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("いいねに失敗しました: $error")),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(play?.title ?? "Play"),
        actions: [
          if (play != null &&
              account.i.username == play.user.username &&
              account.i.id == play.userId)
            IconButton(
              tooltip: "編集",
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => PlayEditorPage(
                      account: account,
                      playId: play.id,
                    ),
                  ),
                );
                refresh.value++;
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: "共有",
            onPressed: play == null
                ? null
                : () => launchUrl(
                      Uri(
                        scheme: account.scheme ?? "https",
                        host: account.host,
                        port: account.port,
                        pathSegments: ["play", play.id],
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: playSnapshot.connectionState == ConnectionState.waiting
          ? const Center(child: CircularProgressIndicator.adaptive())
          : playSnapshot.hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text("Playを読み込めませんでした: ${playSnapshot.error}"),
                  ),
                )
              : play == null
                  ? const Center(child: Text("Playが見つかりません"))
                  : started.value
                      ? PopScope(
                          canPop: false,
                          onPopInvokedWithResult: (didPop, _) async {
                            if (!didPop) {
                              final exit = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text("Playを終了"),
                                  content: const Text("実行中のPlayを終了しますか？"),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text("続ける"),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text("終了"),
                                    ),
                                  ],
                                ),
                              );
                              if (exit == true && context.mounted) {
                                await stop();
                              }
                            }
                          },
                          child: ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: AsUiWidget(
                                    account: account,
                                    components: components.value,
                                  ),
                                ),
                              ),
                              if (log.value != null)
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SelectableText(log.value!),
                                  ),
                                ),
                              FilledButton.icon(
                                onPressed: running.value ? null : stop,
                                icon: const Icon(Icons.stop),
                                label: const Text("終了"),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              play.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(play.summary),
                            const SizedBox(height: 8),
                            Text("@${play.user.username}"),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed:
                                  running.value ? null : () => execute(play),
                              icon: running.value
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow),
                              label: const Text("アプリ内で実行"),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => toggleLike(play),
                              icon: Icon(
                                play.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                              label: Text(
                                "いいね (${play.likedCount ?? 0})",
                              ),
                            ),
                            const SizedBox(height: 16),
                            ExpansionTile(
                              title: const Text("スクリプトソース"),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SelectableText(
                                    play.script,
                                    style: const TextStyle(
                                      fontFamily: "monospace",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
    );
  }
}
