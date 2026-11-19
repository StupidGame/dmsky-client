import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/util/app_platform.dart";
import "package:dmsky_client/view/settings_page/background_notification_settings_page.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/view/aiscript/scratchpad_page.dart";
import "package:dmsky_client/view/themes/dmsky_circuit.dart";

@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).settings)),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          DmskyPanel(
            margin: const EdgeInsets.fromLTRB(5, 4, 5, 12),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined, color: dmskyCyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.acct.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (AppPlatform.isAndroid)
            DmskyMenuTile(
              style: DmskyPanelStyle.surface,
              title: const Text("通知"),
              leading: const Icon(Icons.notifications_active_outlined),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      BackgroundNotificationSettingsPage(account: account),
                ),
              ),
            ),
          DmskyMenuTile(
            style: DmskyPanelStyle.surface,
            title: const Text("AiScript スクラッチパッド"),
            leading: const Icon(Icons.code),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScratchpadPage(account: account),
              ),
            ),
          ),
          DmskyMenuTile(
            style: DmskyPanelStyle.surface,
            title: Text(S.of(context).generalSettings),
            leading: const Icon(Icons.settings),
            onTap: () async => context.pushRoute(const GeneralSettingsRoute()),
          ),
          DmskyMenuTile(
            style: DmskyPanelStyle.surface,
            title: Text(S.of(context).accountSettings),
            leading: const Icon(Icons.account_circle),
            onTap: () async => context.pushRoute(const AccountListRoute()),
          ),
          DmskyMenuTile(
            style: DmskyPanelStyle.surface,
            title: Text(S.of(context).tabSettings),
            leading: const Icon(Icons.tab),
            onTap: () async => context.pushRoute(const TabSettingsListRoute()),
          ),
          DmskyMenuTile(
            style: DmskyPanelStyle.surface,
            title: Text(S.of(context).settingsImportAndExport),
            leading: const Icon(Icons.import_export),
            onTap: () async => context.pushRoute(const ImportExportRoute()),
          ),
          DmskyMenuTile(
            style: DmskyPanelStyle.surface,
            title: Text(S.of(context).aboutMiria),
            leading: const Icon(Icons.info),
            onTap: () async => context.pushRoute(const AppInfoRoute()),
          ),
        ],
      ),
    );
  }
}
