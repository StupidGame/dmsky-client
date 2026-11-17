import "package:flutter/services.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/util/app_platform.dart";
import "package:permission_handler/permission_handler.dart";

final backgroundNotificationServiceProvider = Provider(
  (ref) => const BackgroundNotificationService(),
);

Uri notificationOrigin(Account account) => Uri(
  scheme: account.scheme ?? "https",
  host: account.host,
  port: account.port,
);

class BackgroundNotificationStatus {
  final bool enabled;
  final int intervalMinutes;
  final bool permissionGranted;
  final DateTime? lastCheck;
  final String? lastError;

  const BackgroundNotificationStatus({
    this.enabled = false,
    this.intervalMinutes = 15,
    this.permissionGranted = true,
    this.lastCheck,
    this.lastError,
  });

  factory BackgroundNotificationStatus.fromMap(Map<Object?, Object?> value) {
    final checked = value["lastCheck"] as int? ?? 0;
    return BackgroundNotificationStatus(
      enabled: value["enabled"] == true,
      intervalMinutes: value["intervalMinutes"] as int? ?? 15,
      permissionGranted: value["permissionGranted"] == true,
      lastCheck: checked > 0
          ? DateTime.fromMillisecondsSinceEpoch(checked)
          : null,
      lastError: value["lastError"] as String?,
    );
  }
}

class BackgroundNotificationService {
  const BackgroundNotificationService({bool? supported})
    : _supported = supported;

  static const channel = MethodChannel(
    "app.dmsky.client/background_notifications",
  );
  final bool? _supported;
  bool get isSupported => _supported ?? AppPlatform.isAndroid;

  Map<String, Object?> _identity(Account account) => {
    "origin": notificationOrigin(account).origin,
    "username": account.userId,
  };

  bool canNotify(Account account) =>
      notificationOrigin(account).scheme == "https" &&
      account.userId.isNotEmpty &&
      (account.token?.isNotEmpty ?? false);

  Future<bool> requestPermission() async =>
      isSupported && (await Permission.notification.request()).isGranted;

  Future<BackgroundNotificationStatus> status(Account account) async {
    if (!isSupported) return const BackgroundNotificationStatus();
    final value = await channel.invokeMapMethod<Object?, Object?>(
      "status",
      _identity(account),
    );
    return BackgroundNotificationStatus.fromMap(value ?? {});
  }

  Future<void> configure(
    Account account, {
    required bool enabled,
    required int intervalMinutes,
  }) async {
    if (!isSupported) return;
    if (![15, 30, 60].contains(intervalMinutes)) {
      throw ArgumentError.value(intervalMinutes);
    }
    if (enabled && !canNotify(account)) {
      throw StateError("HTTPSのログイン済みアカウントが必要です");
    }
    await channel.invokeMethod<void>("configure", {
      ..._identity(account),
      "token": enabled ? account.token : null,
      "enabled": enabled,
      "intervalMinutes": intervalMinutes,
    });
  }

  Future<void> checkNow(Account account) async {
    if (isSupported) {
      await channel.invokeMethod<void>("checkNow", _identity(account));
    }
  }

  Future<void> openSettings(Account account) async {
    if (isSupported) {
      await channel.invokeMethod<void>("openSettings", _identity(account));
    }
  }

  Future<void> remove(Account account) async {
    if (!isSupported || notificationOrigin(account).scheme != "https") {
      return;
    }
    try {
      await channel.invokeMethod<void>("remove", _identity(account));
    } on MissingPluginException {
      // Older/test hosts have no native background notification integration.
    }
  }

  Future<void> synchronize(List<Account> accounts) async {
    if (!isSupported) return;
    try {
      await channel.invokeMethod<void>("sync", {
        "accounts": [
          for (final account in accounts.where(canNotify))
            {..._identity(account), "token": account.token},
        ],
      });
    } on MissingPluginException {
      // Allows tests and older hosts to load accounts without a native bridge.
    }
  }

  Future<Map<Object?, Object?>?> takeLaunch() async {
    if (!isSupported) return null;
    try {
      return await channel.invokeMapMethod<Object?, Object?>("takeLaunch");
    } on MissingPluginException {
      return null;
    }
  }

  void setOpenedHandler(Future<void> Function()? handler) {
    if (!isSupported) return;
    channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method == "notificationOpened") {
                await handler();
              }
            },
    );
  }

  Account? accountForLaunch(
    Map<Object?, Object?>? target,
    List<Account> accounts,
  ) {
    if (target == null) return null;
    for (final account in accounts) {
      if (notificationOrigin(account).origin == target["origin"] &&
          account.userId == target["username"]) {
        return account;
      }
    }
    return null;
  }
}
