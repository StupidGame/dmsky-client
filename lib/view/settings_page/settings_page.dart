import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/view/settings_page/push_notification_settings_page.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/view/aiscript/scratchpad_page.dart";

@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          ListTile(
            title: const Text("プッシュ通知"),
            leading: const Icon(Icons.notifications_active_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PushNotificationSettingsPage(account: account),
              ),
            ),
          ),
          ListTile(
            title: const Text("AiScript スクラッチパッド"),
            leading: const Icon(Icons.code),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScratchpadPage(account: account),
              ),
            ),
          ),
          ListTile(
            title: Text(S.of(context).generalSettings),
            leading: const Icon(Icons.settings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async => context.pushRoute(const GeneralSettingsRoute()),
          ),
          ListTile(
            title: Text(S.of(context).accountSettings),
            leading: const Icon(Icons.account_circle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async => context.pushRoute(const AccountListRoute()),
          ),
          ListTile(
            title: Text(S.of(context).tabSettings),
            leading: const Icon(Icons.tab),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async => context.pushRoute(const TabSettingsListRoute()),
          ),
          ListTile(
            title: Text(S.of(context).settingsImportAndExport),
            leading: const Icon(Icons.import_export),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async => context.pushRoute(const ImportExportRoute()),
          ),
          ListTile(
            title: Text(S.of(context).aboutMiria),
            leading: const Icon(Icons.info),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async => context.pushRoute(const AppInfoRoute()),
          ),
        ],
      ),
    );
  }
}
