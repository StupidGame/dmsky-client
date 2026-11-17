import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/service/background_notification_service.dart";

class BackgroundNotificationSettings extends ConsumerStatefulWidget {
  const BackgroundNotificationSettings({required this.account, super.key});
  final Account account;

  @override
  ConsumerState<BackgroundNotificationSettings> createState() =>
      _BackgroundNotificationSettingsState();
}

class _BackgroundNotificationSettingsState
    extends ConsumerState<BackgroundNotificationSettings>
    with WidgetsBindingObserver {
  BackgroundNotificationStatus status = const BackgroundNotificationStatus();
  bool busy = false;
  String? error;
  BackgroundNotificationService get service =>
      ref.read(backgroundNotificationServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (service.isSupported && service.canNotify(widget.account)) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        service.isSupported &&
        service.canNotify(widget.account)) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final value = await service.status(widget.account);
      if (mounted) setState(() => status = value);
    } catch (_) {
      if (mounted) setState(() => error = "通知設定を読み込めませんでした");
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await _load();
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception is PlatformException
              ? exception.message ?? "通知設定の変更に失敗しました"
              : "通知設定の変更に失敗しました",
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _configure(bool enabled, int interval) => _run(() async {
    if (enabled && !status.enabled && !await service.requestPermission()) {
      if (mounted) setState(() => error = "通知が許可されていません。端末の通知設定を確認してください。");
      return;
    }
    await service.configure(
      widget.account,
      enabled: enabled,
      intervalMinutes: interval,
    );
  });

  @override
  Widget build(BuildContext context) {
    if (!service.isSupported) return const SizedBox.shrink();
    if (!service.canNotify(widget.account)) {
      return const ListTile(
        leading: Icon(Icons.notifications_outlined),
        title: Text("バックグラウンド通知"),
        subtitle: Text("HTTPSのログイン済みアカウントで利用できます"),
      );
    }
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text("バックグラウンド通知"),
            subtitle: Text(widget.account.acct.toString()),
            value: status.enabled,
            onChanged: busy
                ? null
                : (enabled) => _configure(enabled, status.intervalMinutes),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "アプリを閉じている間も新着を定期取得します。初回は過去の通知を表示しません。省電力設定などにより取得が遅れる場合があります。",
            ),
          ),
          ListTile(
            title: const Text("確認間隔"),
            trailing: DropdownButton<int>(
              value: status.intervalMinutes,
              items: [
                for (final minutes in [15, 30, 60])
                  DropdownMenuItem(value: minutes, child: Text("$minutes分")),
              ],
              onChanged: busy || !status.enabled
                  ? null
                  : (value) {
                      if (value != null) _configure(true, value);
                    },
            ),
          ),
          if (status.lastCheck != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "最終確認: ${DateFormat('M/d HH:mm').format(status.lastCheck!)}",
              ),
            ),
          if (!status.permissionGranted)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text("端末の通知許可が無効です"),
            ),
          if (error != null || status.lastError != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                error ?? status.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: busy || !status.enabled
                    ? null
                    : () => _run(() async {
                        await service.checkNow(widget.account);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("新着通知の確認を予約しました")),
                          );
                        }
                      }),
                icon: const Icon(Icons.refresh),
                label: const Text("今すぐ確認"),
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => _run(() => service.openSettings(widget.account)),
                icon: const Icon(Icons.settings),
                label: const Text("端末の通知設定"),
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
