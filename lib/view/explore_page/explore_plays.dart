import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/play_page/play_page.dart";
import "package:dmsky_client/view/play_page/game_menu_card.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:dmsky_client/view/aiscript/play_editor_page.dart";
import "package:dmsky_client/view/common/misskey_notes/mfm_text.dart";
import "package:dmsky_client/view/search_page/play_search.dart";
import "package:misskey_dart/misskey_dart.dart";

/// Misskey Play のおすすめ・自分の作品・お気に入り・検索をまとめた画面。
///
/// Play 本体はネイティブAiScriptランタイムで実行する。
class ExplorePlay extends ConsumerWidget {
  const ExplorePlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final misskey = ref.watch(misskeyGetContextProvider);
    final account = ref.watch(accountContextProvider).getAccount;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                const Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: "おすすめ"),
                      Tab(text: "自分のPlay"),
                      Tab(text: "いいね"),
                      Tab(text: "検索"),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "Playを作成",
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => PlayEditorPage(account: account),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PlayList(
                  future: () => misskey.flash.featured(
                    const FlashFeaturedRequest(limit: 100),
                  ),
                  emptyMessage: "おすすめのPlayはありません。",
                ),
                _PlayList(
                  future: () =>
                      misskey.flash.my(const FlashMyRequest(limit: 100)),
                  emptyMessage: "自分で作成したPlayはありません。",
                ),
                _PlayList(
                  future: () async => (await misskey.flash.myLikes(
                    const FlashMyLikesRequest(limit: 100),
                  )).map((item) => item.flash),
                  emptyMessage: "いいねしたPlayはありません。",
                ),
                const PlaySearch(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayList extends HookConsumerWidget {
  final Future<Iterable<Flash>> Function() future;
  final String emptyMessage;

  const _PlayList({required this.future, required this.emptyMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playsFuture = useMemoized(() => Future.sync(future), [future]);
    return FutureBuilder<Iterable<Flash>>(
      future: playsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text("Playを読み込めませんでした。\n${snapshot.error}"),
            ),
          );
        }
        final plays = snapshot.data?.toList() ?? const <Flash>[];
        if (plays.isEmpty) {
          return Center(child: Text(emptyMessage));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          itemCount: plays.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final play = plays[index];
            return GameMenuCard(
              child: ListTile(
                title: MfmText(
                  mfmText: play.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (play.summary.isNotEmpty) MfmText(mfmText: play.summary),
                    const SizedBox(height: 4),
                    Text(
                      "@${play.user.username}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing:
                    play.userId ==
                        ref.read(accountContextProvider).getAccount.i.id
                    ? IconButton(
                        tooltip: "編集",
                        icon: const Icon(Icons.edit),
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => PlayEditorPage(
                              account: ref
                                  .read(accountContextProvider)
                                  .getAccount,
                              playId: play.id,
                            ),
                          ),
                        ),
                      )
                    : play.likedCount == null
                    ? null
                    : Text("♡ ${play.likedCount}"),
                onTap: () {
                  final account = ref.read(accountContextProvider).getAccount;
                  openPlay(
                    context,
                    playServer(
                      account,
                    ).replace(pathSegments: ["play", play.id]),
                    account: account,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
