import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:dmsky_client/service/background_notification_service.dart";

import "../test_util/test_datas.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = BackgroundNotificationService(supported: true);
  final calls = <MethodCall>[];
  final account = TestData.account.copyWith(
    host: "one.example",
    userId: "alice",
    token: "test-token",
  );

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundNotificationService.channel, (
          call,
        ) async {
          calls.add(call);
          if (call.method == "status")
            return {
              "enabled": true,
              "intervalMinutes": 30,
              "permissionGranted": false,
              "lastCheck": 1000,
              "lastError": "端末の通知許可が無効です",
            };
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundNotificationService.channel, null),
  );

  test(
    "configuration identifies the account and disabling clears the native token",
    () async {
      await service.configure(account, enabled: true, intervalMinutes: 30);
      expect(calls.single.arguments, {
        "origin": "https://one.example",
        "username": "alice",
        "token": "test-token",
        "enabled": true,
        "intervalMinutes": 30,
      });
      await service.configure(account, enabled: false, intervalMinutes: 30);
      expect((calls.last.arguments as Map)["token"], isNull);
    },
  );

  test(
    "startup sync refreshes credentials and excludes unsupported accounts",
    () async {
      await service.synchronize([
        account,
        account.copyWith(scheme: "http"),
        account.copyWith(token: null),
        account.copyWith(userId: "bob", port: 8443),
      ]);
      final accounts = (calls.single.arguments as Map)["accounts"] as List;
      expect(accounts.length, 2);
      expect(accounts.last["origin"], "https://one.example:8443");
      expect(accounts.last["username"], "bob");
    },
  );

  test(
    "logout sends only identity to remove the native job and credentials",
    () async {
      await service.remove(account);
      expect(calls.single.method, "remove");
      expect(calls.single.arguments, {
        "origin": "https://one.example",
        "username": "alice",
      });
    },
  );

  test(
    "status exposes scheduling and notification permission failures",
    () async {
      final status = await service.status(account);
      expect(status.enabled, isTrue);
      expect(status.permissionGranted, isFalse);
      expect(status.intervalMinutes, 30);
      expect(status.lastCheck!.millisecondsSinceEpoch, 1000);
      expect(status.lastError, "端末の通知許可が無効です");
    },
  );

  test("tap routing matches both the origin and username", () {
    final accounts = [
      account,
      account.copyWith(host: "two.example"),
      account.copyWith(userId: "bob"),
    ];
    expect(
      service.accountForLaunch({
        "origin": "https://two.example",
        "username": "alice",
      }, accounts),
      same(accounts[1]),
    );
    expect(
      service.accountForLaunch({
        "origin": "https://one.example",
        "username": "bob",
      }, accounts),
      same(accounts[2]),
    );
    expect(
      service.accountForLaunch({
        "origin": "https://unknown.example",
        "username": "alice",
      }, accounts),
      isNull,
    );
  });

  test("unsupported hosts do not call native APIs", () async {
    const unsupported = BackgroundNotificationService(supported: false);
    await unsupported.configure(account, enabled: true, intervalMinutes: 15);
    await unsupported.synchronize([account]);
    await unsupported.remove(account);
    expect(await unsupported.takeLaunch(), isNull);
    expect(calls, isEmpty);
  });

  test(
    "invalid intervals and insecure origins never reach the native bridge",
    () async {
      await expectLater(
        service.configure(account, enabled: true, intervalMinutes: 1),
        throwsArgumentError,
      );
      await expectLater(
        service.configure(
          account.copyWith(scheme: "http"),
          enabled: true,
          intervalMinutes: 15,
        ),
        throwsStateError,
      );
      expect(calls, isEmpty);
    },
  );
}
