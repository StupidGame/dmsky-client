import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/services/push_notification_service.dart";
import "package:dmsky_client/util/app_platform.dart";

class PushNotificationSettingsPage extends StatefulWidget {
  const PushNotificationSettingsPage({required this.account, super.key});

  final Account account;

  @override
  State<PushNotificationSettingsPage> createState() =>
      _PushNotificationSettingsPageState();
}

class _PushNotificationSettingsPageState
    extends State<PushNotificationSettingsPage> {
  bool _busy = false;
  String _status = "";

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = "処理中…";
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _status = "登録要求を送信しました。配信サーバーの応答と実際の受信は別途確認してください。";
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableUnifiedPush() async {
    final service = PushNotificationService.instance;
    if (!service.gatewayConfigured) {
      if (mounted) {
        setState(() {
          _status = "配信ゲートウェイが未設定です。DMSKY_PUSH_GATEWAY_URL を設定してください。";
        });
      }
      return;
    }
    try {
      await service.enableUnifiedPushForAccount(widget.account);
      if (!mounted) return;
      setState(() {
        _status = "UnifiedPush の登録要求を送信しました。";
      });
      return;
    } catch (error) {
      final distributors = await service.getUnifiedPushDistributors();
      if (distributors.isEmpty) {
        if (!mounted) return;
        setState(() => _status = error.toString());
        return;
      }
      if (!mounted) return;
      final selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text("配信アプリを選択"),
          children: [
            for (final distributor in distributors)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(distributor),
                child: Text(distributor),
              ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      await _run(
        () => service.selectUnifiedPushDistributor(
          widget.account,
          selected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = PushNotificationService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text("プッシュ通知")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "このアカウントの通知を端末へ届けるための設定です。",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_outlined),
            title: const Text("接続設定"),
            subtitle: Text(service.configurationSummary),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                    () => service.enableFirebaseForAccount(widget.account),
                  ),
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(
              kIsWeb
                  ? "Web Push を有効にする"
                  : AppPlatform.isIOS
                  ? "APNs / Firebase を有効にする"
                  : "FCM を有効にする",
            ),
          ),
          if (AppPlatform.isAndroid) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _enableUnifiedPush,
              icon: const Icon(Icons.hub_outlined),
              label: const Text("UnifiedPush を登録する"),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                    () => service.unregisterAccount(widget.account),
                  ),
            icon: const Icon(Icons.notifications_off_outlined),
            label: const Text("このアカウントの端末登録を解除"),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            SelectableText(_status),
          ],
          const SizedBox(height: 24),
          const Text(
            "注意: このアプリにはまだ本番用の配信ゲートウェイが同梱されていません。Firebase / APNs / UnifiedPush の端末登録には、別途設定済みの配信サーバーが必要です。設定が未完了の場合、通知トークンを取得できても通知は届きません。",
          ),
        ],
      ),
    );
  }
}
