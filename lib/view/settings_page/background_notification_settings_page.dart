import "package:flutter/material.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/view/several_account_settings_page/background_notifications/background_notification_settings.dart";

class BackgroundNotificationSettingsPage extends StatelessWidget {
  const BackgroundNotificationSettingsPage({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("通知")),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [BackgroundNotificationSettings(account: account)],
    ),
  );
}
