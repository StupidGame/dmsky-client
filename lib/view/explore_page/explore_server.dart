import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/view/common/misskey_server_list.dart";

class ExploreServer extends ConsumerWidget {
  const ExploreServer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: MisskeyServerList(
        onTap: (item) async => context.pushRoute(
          FederationRoute(
            accountContext: ref.read(accountContextProvider),
            host: item.url,
          ),
        ),
      ),
    );
  }
}
