import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/futable_list_builder.dart";
import "package:dmsky_client/view/common/misskey_notes/mfm_text.dart";
import "package:dmsky_client/view/search_page/play_search.dart";
import "package:misskey_dart/misskey_dart.dart";
import "package:url_launcher/url_launcher.dart";

/// Misskey Play のおすすめ・自分の作品・お気に入り・検索をまとめた画面。
///
/// Play 本体の実行・編集はサーバー側の AiScript 実行環境を利用するため、
/// 作品を開く操作はアカウントのサーバーへ遷移する。
class ExplorePlay extends ConsumerWidget {
  const ExplorePlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final misskey = ref.watch(misskeyGetContextProvider);

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: "おすすめ"),
                Tab(text: "自分のPlay"),
                Tab(text: "いいね"),
                Tab(text: "検索"),
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
                  future: () => misskey.flash.my(
                    const FlashMyRequest(limit: 100),
                  ),
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

class _PlayList extends ConsumerWidget {
  final Future<Iterable<Flash>> Function() future;
  final String emptyMessage;

  const _PlayList({
    required this.future,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(
      accountContextProvider.select((value) => value.getAccount.host),
    );

    return FutureListView<Flash>(
      future: Future(future),
      builder: (context, play) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: ListTile(
          title: MfmText(
            mfmText: play.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
          trailing: play.likedCount == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_border, size: 16),
                    const SizedBox(width: 4),
                    Text("${play.likedCount}"),
                  ],
                ),
          onTap: () async {
            await launchUrl(
              Uri(
                scheme: "https",
                host: host,
                pathSegments: ["play", play.id],
              ),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      ),
    );
  }
}
