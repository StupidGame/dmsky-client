import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/view/drive_page/drive_management_page.dart";
import "package:dmsky_client/view/avatar_decorations_page/avatar_decorations_page.dart";
import "package:dmsky_client/view/qr_page/qr_code_page.dart";
import "package:dmsky_client/view/qr_page/qr_scanner_page.dart";

@RoutePage()
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountContextProvider).postAccount;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          ListTile(
            title: const Text("ドライブ管理"),
            leading: const Icon(Icons.cloud_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (routeContext) =>
                    DriveManagementPage(account: account).wrappedRoute(routeContext),
              ),
            ),
          ),
          ListTile(
            title: const Text("アバター装飾"),
            leading: const Icon(Icons.auto_awesome),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AvatarDecorationsPage(account: account),
              ),
            ),
          ),
          ListTile(
            title: const Text("プロフィールQRコード"),
            leading: const Icon(Icons.qr_code_2),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QrCodePage(account: account),
              ),
            ),
          ),
          ListTile(
            title: const Text("QRコード読み取り"),
            leading: const Icon(Icons.qr_code_scanner),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QrScannerPage(account: account),
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
