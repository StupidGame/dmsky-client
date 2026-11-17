import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/service/background_notification_service.dart";
import "package:dmsky_client/view/several_account_settings_page/background_notifications/background_notification_settings.dart";

import "../../test_util/test_datas.dart";

class _Notifications extends BackgroundNotificationService {
  _Notifications({this.allowed = true}) : super(supported: true);
  final bool allowed;
  bool enabled = false;
  int interval = 15;
  int changes = 0;
  int permissionRequests = 0;
  bool checked = false;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<BackgroundNotificationStatus> status(Account account) async =>
      BackgroundNotificationStatus(enabled: enabled, intervalMinutes: interval);

  @override
  Future<void> configure(
    Account account, {
    required bool enabled,
    required int intervalMinutes,
  }) async {
    this.enabled = enabled;
    interval = intervalMinutes;
    changes++;
  }

  @override
  Future<void> checkNow(Account account) async {
    checked = true;
  }
}

Widget widget(_Notifications service) => ProviderScope(
  overrides: [backgroundNotificationServiceProvider.overrideWithValue(service)],
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BackgroundNotificationSettings(
          account: TestData.account.copyWith(token: "test-token"),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets("permission denial leaves background polling disabled", (
    tester,
  ) async {
    final service = _Notifications(allowed: false);
    await tester.pumpWidget(widget(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(service.enabled, isFalse);
    expect(service.changes, 0);
    expect(find.textContaining("通知が許可されていません"), findsOneWidget);
  });

  testWidgets(
    "accounts can enable polling, change interval, check now, and disable",
    (tester) async {
      final service = _Notifications();
      await tester.pumpWidget(widget(service));
      await tester.pumpAndSettle();
      expect(find.text(TestData.account.acct.toString()), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(service.enabled, isTrue);
      expect(service.permissionRequests, 1);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text("30分").last);
      await tester.pumpAndSettle();
      expect(service.interval, 30);
      expect(service.permissionRequests, 1);

      await tester.tap(find.text("今すぐ確認"));
      await tester.pumpAndSettle();
      expect(service.checked, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(service.enabled, isFalse);
    },
  );
}
