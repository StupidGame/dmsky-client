import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/futable_list_builder.dart";
import "package:dmsky_client/view/common/misskey_notes/mfm_text.dart";
import "package:misskey_dart/misskey_dart.dart";
import "package:dmsky_client/view/play_page/play_page.dart";
import "package:dmsky_client/view/play_page/game_menu_card.dart";

class ExplorePlay extends HookConsumerWidget {
  const ExplorePlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountContextProvider).getAccount;
    final misskey = ref.watch(misskeyGetContextProvider);
    final plays = useMemoized(
      () => misskey.flash.featured(const FlashFeaturedRequest()),
      [misskey],
    );
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: FutureListView(
        future: plays,
        builder: (context, item) {
          return GameMenuCard(
            child: ListTile(
              onTap: () async {
                await openPlay(
                  context,
                  account: account,
                  Uri(
                    scheme: account.scheme ?? "https",
                    host: account.host,
                    port: account.port,
                    pathSegments: ["play", item.id],
                  ),
                );
              },
              title: MfmText(
                mfmText: item.title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: MfmText(mfmText: item.summary),
            ),
          );
        },
      ),
    );
  }
}
