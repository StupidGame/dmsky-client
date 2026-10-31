import "package:dmsky_client/util/app_platform.dart";

import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/model/tab_setting.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:dmsky_client/view/common/tab_icon_view.dart";

@RoutePage()
class TabSettingsListPage extends ConsumerWidget {
  const TabSettingsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabSettings = ref
        .watch(
          tabSettingsRepositoryProvider.select(
            (repository) => repository.tabSettings,
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: Container(),
        title: Text(S.of(context).tabSettings),
        actions: [
          IconButton(
            onPressed: () async => await context.pushRoute(TabSettingsRoute()),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: tabSettings.length,
                itemBuilder: (context, index) {
                  final tabSetting = tabSettings[index];
                  if (AppPlatform.isAndroid || AppPlatform.isIOS) {
                    return ReorderableDelayedDragStartListener(
                      key: Key("$index"),
                      index: index,
                      child: TabSettingsListItem(
                        tabSetting: tabSetting,
                        index: index,
                      ),
                    );
                  } else {
                    return ReorderableDragStartListener(
                      key: Key("$index"),
                      index: index,
                      child: TabSettingsListItem(
                        tabSetting: tabSetting,
                        index: index,
                      ),
                    );
                  }
                },
                onReorder: (oldIndex, newIndex) async {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = tabSettings.removeAt(oldIndex);
                  tabSettings.insert(newIndex, item);
                  await ref
                      .read(tabSettingsRepositoryProvider)
                      .save(tabSettings);
                },
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ElevatedButton(
                  onPressed: () async => await context.router.pushAndPopUntil(
                    const SplashRoute(),
                    predicate: (_) => false,
                  ),
                  child: Text(S.of(context).apply),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TabSettingsListItem extends ConsumerWidget {
  const TabSettingsListItem({
    required this.tabSetting,
    required this.index,
    super.key,
  });

  final TabSetting tabSetting;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider(tabSetting.acct));
    return ListTile(
      leading: AccountContextScope.as(
        account: account,
        child: TabIconView(icon: tabSetting.icon),
      ),
      title: Text(tabSetting.name ?? tabSetting.tabType.displayName(context)),
      subtitle: Text(
        "${tabSetting.tabType.displayName(context)} / ${tabSetting.acct}",
      ),
      trailing: const Icon(Icons.drag_handle),
      onTap: () async => context.pushRoute(TabSettingsRoute(tabIndex: index)),
    );
  }
}
