import "package:dmsky_client/view/themes/dmsky_circuit.dart";
import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/model/acct.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:dmsky_client/view/common/avatar_icon.dart";
import "package:dmsky_client/view/common/misskey_notes/mfm_text.dart";

class CommonDrawer extends ConsumerWidget {
  final Acct initialOpenAcct;
  final bool allOpen;

  const CommonDrawer({
    required this.initialOpenAcct,
    this.allOpen = false,
    super.key,
  });

  void closeDrawer(BuildContext context) {
    final state = Scaffold.of(context);
    if (state.isDrawerOpen) {
      state.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return Drawer(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 20, 12, 24),
              child: DmskyBrand(),
            ),
            for (final account in accounts) ...[
              AccountContextScope.as(
                account: account,
                child: ExpansionTile(
                  textColor: const Color(0xfff1fbff),
                  collapsedTextColor: const Color(0xffd7edfb),
                  iconColor: dmskyGold,
                  collapsedIconColor: dmskyCyan,
                  leading: AvatarIcon(user: account.i),
                  initiallyExpanded: account.acct == initialOpenAcct || allOpen,
                  title: SimpleMfmText(
                    account.i.name ?? account.i.username,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  subtitle: Text(
                    account.acct.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xffb9d6e7),
                    ),
                  ),
                  children: [
                    DmskyMenuTile(
                      leading: const Icon(Icons.notifications),
                      title: Text(S.of(context).notification),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          NotificationRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                    ),
                    DmskyMenuTile(
                      leading: const Icon(Icons.star),
                      title: Text(S.of(context).favorite),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          FavoritedNoteRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                    ),
                    DmskyMenuTile(
                      leading: const Icon(Icons.list),
                      title: Text(S.of(context).list),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          UsersListRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                    ),
                    DmskyMenuTile(
                      leading: const Icon(Icons.settings_input_antenna),
                      title: Text(S.of(context).antenna),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          AntennaRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                    ),
                    DmskyMenuTile(
                      leading: const Icon(Icons.attach_file),
                      title: Text(S.of(context).clip),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          ClipListRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                    ),
                    DmskyMenuTile(
                      leading: const Icon(Icons.tv),
                      title: Text(S.of(context).channel),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          ChannelsRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                    ),
                    if (account.i.canChat == true)
                      DmskyMenuTile(
                        leading: const Icon(Icons.chat),
                        title: Text(S.of(context).chat),
                        onTap: () async {
                          closeDrawer(context);
                          await context.pushRoute(
                            ChatHomeRoute(
                              accountContext: AccountContext.as(account),
                            ),
                          );
                        },
                      ),
                    DmskyMenuTile(
                      leading: const Icon(Icons.search),
                      title: Text(S.of(context).search),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          SearchRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                    ),
                    DmskyMenuTile(
                      leading: const Icon(Icons.tag),
                      title: Text(S.of(context).explore),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          ExploreRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                    ),
                    DmskyMenuTile(
                      leading: const Icon(Icons.gamepad),
                      title: Text(S.of(context).misskeyGames),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          MisskeyGamesRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                    ),
                    DmskyMenuTile(
                      leading: const Icon(Icons.settings),
                      title: Text(
                        S
                            .of(context)
                            .accountSetting(
                              account.i.name ?? account.i.username,
                            ),
                      ),
                      onTap: () async {
                        closeDrawer(context);
                        await context.pushRoute(
                          SeveralAccountSettingsRoute(account: account),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            DmskyMenuTile(
              leading: const Icon(Icons.settings),
              title: Text(S.of(context).settings),
              onTap: () async {
                closeDrawer(context);
                await context.pushRoute(const SettingsRoute());
              },
            ),
          ],
        ),
      ),
    );
  }
}
