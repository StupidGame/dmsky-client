import "dart:async";
import "dart:convert";

import "package:dio/dio.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/model/push_notification_payload.dart";
import "package:dmsky_client/util/app_platform.dart";
import "package:dmsky_client/services/web_push_bridge.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:unifiedpush/unifiedpush.dart";
import "package:uuid/uuid.dart";

const _pushChannelId = "dmsky_notifications";
const _pushChannelName = "DMSKY 通知";
const _pushInstancePrefix = "dmsky:";

@pragma("vm:entry-point")
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  WidgetsFlutterBinding.ensureInitialized();
  final options = PushNotificationService.firebaseOptionsForCurrentPlatform();
  if (options == null) return;

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }
    await PushNotificationService.instance.initializeLocalNotifications();
    // OS が notification payload を表示するため、data-only の場合だけローカル表示する。
    if (message.notification == null) {
      await PushNotificationService.instance.showRemoteMessage(message);
    }
  } catch (_) {
    // Background isolates must not crash because an optional notification failed.
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _gatewayRaw = String.fromEnvironment(
    "DMSKY_PUSH_GATEWAY_URL",
  );
  static const String _webVapidKey = String.fromEnvironment(
    "DMSKY_FIREBASE_WEB_VAPID_KEY",
  );
  static const String _unifiedPushVapidKey = String.fromEnvironment(
    "DMSKY_UNIFIEDPUSH_VAPID_KEY",
  );

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final StreamController<PushNotificationPayload> _tapController =
      StreamController<PushNotificationPayload>.broadcast();
  final List<PushNotificationPayload> _pendingTaps = [];
  final Set<String> _recentEventIds = <String>{};
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  final Map<String, Account> _unifiedAccounts = <String, Account>{};
  final Map<String, PushEndpoint> _pendingUnifiedEndpoints =
      <String, PushEndpoint>{};

  FirebaseMessaging? _messaging;
  List<Account> _knownAccounts = const [];
  final Set<String> _firebaseEnabledAccountKeys = <String>{};
  final Set<String> _unifiedEnabledAccountKeys = <String>{};
  bool _enablementLoaded = false;
  Future<void>? _initialization;
  bool _localInitialized = false;
  bool _unifiedInitialized = false;
  bool _firebaseReady = false;
  String? _lastFirebaseError;
  String? _lastUnifiedError;

  Stream<PushNotificationPayload> get onNotificationTap =>
      _tapController.stream;

  bool get firebaseConfigured =>
      firebaseOptionsForCurrentPlatform() != null;
  bool get gatewayConfigured => _gatewayUri != null;
  bool get firebaseReady => _firebaseReady;
  bool get unifiedPushAvailable => AppPlatform.isAndroid && _unifiedInitialized;

  Uri? get _gatewayUri {
    if (_gatewayRaw.trim().isEmpty) return null;
    final uri = Uri.tryParse(_gatewayRaw.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !<String>{"https", "http"}.contains(uri.scheme) ||
        (uri.scheme == "http" &&
            uri.host != "localhost" &&
            uri.host != "127.0.0.1")) {
      return null;
    }
    return uri;
  }

  static FirebaseOptions? firebaseOptionsForCurrentPlatform() {
    const apiKey = String.fromEnvironment("DMSKY_FIREBASE_API_KEY");
    const projectId = String.fromEnvironment("DMSKY_FIREBASE_PROJECT_ID");
    const senderId = String.fromEnvironment("DMSKY_FIREBASE_SENDER_ID");
    const androidAppId = String.fromEnvironment(
      "DMSKY_FIREBASE_ANDROID_APP_ID",
    );
    const iosAppId = String.fromEnvironment("DMSKY_FIREBASE_IOS_APP_ID");
    const webAppId = String.fromEnvironment("DMSKY_FIREBASE_WEB_APP_ID");
    const macosAppId = String.fromEnvironment("DMSKY_FIREBASE_MACOS_APP_ID");
    const iosBundleId = "app.dmsky.dmskyClient";

    final appId = kIsWeb
        ? webAppId
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => androidAppId,
            TargetPlatform.iOS => iosAppId,
            TargetPlatform.macOS => macosAppId,
            _ => "",
          };

    if (apiKey.isEmpty ||
        projectId.isEmpty ||
        senderId.isEmpty ||
        appId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      authDomain: "$projectId.firebaseapp.com",
      iosBundleId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? iosBundleId
          : null,
    );
  }

  String _accountKey(Account account) =>
      "${_accountHost(account)}|${account.userId}";

  Future<void> _loadEnablement() async {
    if (_enablementLoaded) return;
    final preferences = await SharedPreferences.getInstance();
    _firebaseEnabledAccountKeys
      ..clear()
      ..addAll(preferences.getStringList("dmsky_push_fcm_accounts") ?? const []);
    _unifiedEnabledAccountKeys
      ..clear()
      ..addAll(preferences.getStringList("dmsky_push_unified_accounts") ?? const []);
    _enablementLoaded = true;
  }

  Future<void> _saveEnablement() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      "dmsky_push_fcm_accounts",
      _firebaseEnabledAccountKeys.toList()..sort(),
    );
    await preferences.setStringList(
      "dmsky_push_unified_accounts",
      _unifiedEnabledAccountKeys.toList()..sort(),
    );
  }

  Future<void> initialize(List<String> args) {
    return _initialization ??= _initialize(args);
  }

  Future<void> _initialize(List<String> args) async {

    if (!kIsWeb &&
        (AppPlatform.isAndroid ||
            AppPlatform.isIOS ||
            AppPlatform.isMacOS ||
            AppPlatform.isLinux)) {
      await initializeLocalNotifications();
    }

    if (AppPlatform.isAndroid) {
      await _initializeUnifiedPush();
    }

    if (!kIsWeb && _localInitialized) {
      try {
        final launch = await _local.getNotificationAppLaunchDetails();
        final payload = launch?.notificationResponse?.payload;
        if (launch?.didNotificationLaunchApp == true && payload != null) {
          _acceptEncodedPayload(payload);
        }
      } catch (_) {
        // Notification launch metadata is not supported by every desktop host.
      }
    }

    final options = firebaseOptionsForCurrentPlatform();
    if (options == null) {
      _lastFirebaseError = "Firebase のアプリ設定がありません";
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      _messaging = FirebaseMessaging.instance;
      if (!kIsWeb) {
        await _messaging!.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
      }

      FirebaseMessaging.onMessage.listen((message) {
        unawaited(showRemoteMessage(message));
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _acceptData(message.data);
      });
      // The push gateway currently targets legacy FCM registration tokens.
      // Keep this listener until the gateway can address Firebase Installation IDs.
      // ignore: deprecated_member_use
      _messaging!.onTokenRefresh.listen((token) {
        unawaited(_registerTokenForKnownAccounts(token));
      });

      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _acceptData(initialMessage.data);
      }

      _firebaseReady = true;
      _lastFirebaseError = null;
    } catch (error) {
      _lastFirebaseError = error.toString();
      _firebaseReady = false;
    }
  }

  Future<void> initializeLocalNotifications() async {
    if (kIsWeb || _localInitialized) return;

    final settings = InitializationSettings(
      android: const AndroidInitializationSettings("@mipmap/ic_launcher"),
      iOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: const LinuxInitializationSettings(
        defaultActionName: "通知を開く",
      ),
    );

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _acceptEncodedPayload(payload);
        }
      },
    );
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _pushChannelId,
        _pushChannelName,
        description: "DMSKY Client の新着通知",
        importance: Importance.high,
      ),
    );
    _localInitialized = true;
  }

  Future<String?> _waitForApnsToken() async {
    if (!AppPlatform.isIOS || _messaging == null) return null;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      final token = await _messaging!.getAPNSToken();
      if (token != null && token.isNotEmpty) return token;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<void> enableFirebaseForAccount(Account account) async {
    await initialize(const []);
    if (_messaging == null || !_firebaseReady) {
      throw StateError(
        _lastFirebaseError ?? "Firebase Messaging を初期化できません",
      );
    }

    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw StateError("通知の許可が拒否されています。端末の設定から許可してください。");
    }

    if (AppPlatform.isIOS) {
      final apnsToken = await _waitForApnsToken();
      if (apnsToken == null) {
        throw StateError(
          "APNs トークンを15秒以内に取得できませんでした。Push Notifications capabilityとProvisioning Profileを確認してください。",
        );
      }
    }

    if (kIsWeb && _webVapidKey.isEmpty) {
      throw StateError("Web Push 用の VAPID 公開鍵が設定されていません。");
    }

    // The gateway uses FCM registration tokens; FID migration requires a gateway protocol change.
    // ignore: deprecated_member_use
    final token = await _messaging!.getToken(
      vapidKey: kIsWeb ? _webVapidKey : null,
    );
    if (token == null || token.isEmpty) {
      throw StateError("通知トークンを取得できませんでした。");
    }

    await _registerDevice(
      account: account,
      provider: "fcm",
      registration: <String, dynamic>{"token": token},
    );
    await _loadEnablement();
    _firebaseEnabledAccountKeys.add(_accountKey(account));
    _knownAccounts = <Account>{..._knownAccounts, account}.toList();
    await _saveEnablement();
  }

  Future<void> syncAccounts(List<Account> accounts) async {
    _knownAccounts = accounts;
    await _loadEnablement();

    if (AppPlatform.isAndroid && _unifiedInitialized && gatewayConfigured) {
      for (final account in accounts) {
        final key = _accountKey(account);
        if (!_unifiedEnabledAccountKeys.contains(key)) continue;
        final instance = _instanceFor(account);
        _unifiedAccounts[instance] = account;
        try {
          // The UnifiedPush contract recommends re-registering at each app
          // startup so the selected distributor can confirm the subscription.
          await UnifiedPush.register(
            instance: instance,
            vapid: _unifiedPushVapidKey.isEmpty ? null : _unifiedPushVapidKey,
          );
        } catch (error) {
          _lastUnifiedError = error.toString();
        }
        final pending = _pendingUnifiedEndpoints.remove(instance);
        if (pending != null) {
          try {
            await _registerUnifiedEndpoint(pending, instance);
          } catch (_) {
            _pendingUnifiedEndpoints[instance] = pending;
          }
        }
      }
    }

    if (!_firebaseReady || _messaging == null || !gatewayConfigured) return;
    if (!accounts.any(
      (account) => _firebaseEnabledAccountKeys.contains(_accountKey(account)),
    )) {
      return;
    }

    try {
      final settings = await _messaging!.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      if (AppPlatform.isIOS && await _waitForApnsToken() == null) {
        return;
      }
      if (kIsWeb && _webVapidKey.isEmpty) return;
      // Keep token registration compatible with the current push gateway.
      // ignore: deprecated_member_use
      final token = await _messaging!.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );
      if (token == null || token.isEmpty) return;
      await _registerTokenForKnownAccounts(token);
    } catch (_) {
      // Account loading must continue if push registration is unavailable.
    }
  }

  Future<void> _registerTokenForKnownAccounts(String token) async {
    await _loadEnablement();
    for (final account in _knownAccounts) {
      if (!_firebaseEnabledAccountKeys.contains(_accountKey(account))) {
        continue;
      }
      try {
        await _registerDevice(
          account: account,
          provider: "fcm",
          registration: <String, dynamic>{"token": token},
        );
      } catch (_) {
        // A single account/server must not block the others.
      }
    }
  }

  Future<List<String>> getUnifiedPushDistributors() async {
    if (!AppPlatform.isAndroid) return const [];
    await initialize(const []);
    if (!_unifiedInitialized) return const [];
    return UnifiedPush.getDistributors();
  }

  Future<void> enableUnifiedPushForAccount(Account account) async {
    if (!AppPlatform.isAndroid) {
      throw UnsupportedError("UnifiedPush は Android でのみ利用できます。");
    }
    await initialize(const []);
    if (!_unifiedInitialized) {
      throw StateError(_lastUnifiedError ?? "UnifiedPush を初期化できません。");
    }
    if (!gatewayConfigured) {
      throw StateError("配信サーバー URL が未設定のため、端末登録を完了できません。");
    }

    _unifiedAccounts[_instanceFor(account)] = account;
    final hasDistributor = await UnifiedPush.tryUseCurrentOrDefaultDistributor();
    if (!hasDistributor) {
      throw StateError("UnifiedPush Distributor が見つかりません。対応する配信アプリをインストールして選択してください。");
    }
    await UnifiedPush.register(
      instance: _instanceFor(account),
      vapid: _unifiedPushVapidKey.isEmpty ? null : _unifiedPushVapidKey,
    );
    await _loadEnablement();
    _unifiedEnabledAccountKeys.add(_accountKey(account));
    await _saveEnablement();

    final pending = _pendingUnifiedEndpoints.remove(_instanceFor(account));
    if (pending != null) {
      await _registerUnifiedEndpoint(pending, _instanceFor(account));
    }
  }

  Future<void> selectUnifiedPushDistributor(
    Account account,
    String distributor,
  ) async {
    if (!AppPlatform.isAndroid || !_unifiedInitialized) {
      throw UnsupportedError("UnifiedPush は Android でのみ利用できます。");
    }
    if (!gatewayConfigured) {
      throw StateError("配信サーバー URL が未設定のため、端末登録を完了できません。");
    }
    await UnifiedPush.saveDistributor(distributor);
    _unifiedAccounts[_instanceFor(account)] = account;
    await UnifiedPush.register(
      instance: _instanceFor(account),
      vapid: _unifiedPushVapidKey.isEmpty ? null : _unifiedPushVapidKey,
    );
    await _loadEnablement();
    _unifiedEnabledAccountKeys.add(_accountKey(account));
    await _saveEnablement();
  }

  Future<void> _initializeUnifiedPush() async {
    if (_unifiedInitialized) return;
    try {
      _unifiedInitialized = await UnifiedPush.initialize(
        onNewEndpoint: (endpoint, instance) {
          unawaited(() async {
            try {
              await _registerUnifiedEndpoint(endpoint, instance);
            } catch (error) {
              _lastUnifiedError = error.toString();
              _pendingUnifiedEndpoints[instance] = endpoint;
            }
          }());
        },
        onRegistrationFailed: (reason, instance) {
          _lastUnifiedError = "UnifiedPush 登録失敗: ${reason.name}";
        },
        onUnregistered: (instance) {
          _pendingUnifiedEndpoints.remove(instance);
        },
        onMessage: (message, instance) {
          unawaited(_handleUnifiedMessage(message));
        },
        onTempUnavailable: (instance) {
          _lastUnifiedError = "UnifiedPush 配信元が一時的に利用できません";
        },
      );
      if (!_unifiedInitialized) {
        _lastUnifiedError = "UnifiedPush の受信機を初期化できませんでした";
      }
    } catch (error) {
      _lastUnifiedError = error.toString();
      _unifiedInitialized = false;
    }
  }

  Future<void> _registerUnifiedEndpoint(
    PushEndpoint endpoint,
    String instance,
  ) async {
    final account = _unifiedAccounts[instance];
    if (account == null) {
      _pendingUnifiedEndpoints[instance] = endpoint;
      return;
    }
    final keys = endpoint.pubKeySet;
    if (keys == null) {
      _lastUnifiedError = "Distributor から暗号鍵を受け取れませんでした";
      return;
    }
    await _registerDevice(
      account: account,
      provider: "unifiedpush",
      registration: <String, dynamic>{
        "endpoint": endpoint.url,
        "keys": <String, String>{
          "p256dh": keys.pubKey,
          "auth": keys.auth,
        },
        "temporary": endpoint.temporary,
      },
    );
  }

  Future<void> _handleUnifiedMessage(PushMessage message) async {
    if (!message.decrypted) return;
    try {
      final decoded = jsonDecode(utf8.decode(message.content));
      if (decoded is Map<String, dynamic>) {
        final payload = PushNotificationPayload.tryParse(decoded);
        if (payload == null) return;
        await _showNotification(
          title: _stringOrNull(decoded["title"]) ?? "DMSKY Client",
          body: _stringOrNull(decoded["body"]) ?? "新しい通知があります",
          payload: decoded,
          eventId: payload.eventId,
        );
      }
    } catch (_) {
      // Ignore malformed or undecryptable data.
    }
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;
    final title = notification?.title ??
        _stringOrNull(data["title"]) ??
        "DMSKY Client";
    final body = notification?.body ??
        _stringOrNull(data["body"]) ??
        "新しい通知があります";
    if (kIsWeb) {
      try {
        showForegroundPush(
          title,
          body,
          jsonEncode(data),
        );
      } catch (_) {
        // The optional web bridge is absent when the web build is customized.
      }
      return;
    }
    if (!_localInitialized) return;
    await _showNotification(
      title: title,
      body: body,
      payload: data,
      eventId: _stringOrNull(data["eventId"]) ?? message.messageId,
    );
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
    String? eventId,
  }) async {
    if (kIsWeb || !_localInitialized) return;
    final parsed = PushNotificationPayload.tryParse(payload);
    final encodedPayload = parsed == null ? null : jsonEncode(payload);
    final id = (eventId ?? DateTime.now().microsecondsSinceEpoch.toString())
            .hashCode &
        0x7fffffff;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _pushChannelId,
        _pushChannelName,
        channelDescription: "DMSKY Client の新着通知",
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
        tag: eventId,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      linux: const LinuxNotificationDetails(
        urgency: LinuxNotificationUrgency.normal,
      ),
    );
    await _local.show(
      id,
      title,
      body,
      details,
      payload: encodedPayload,
    );
  }

  Future<void> unregisterAccount(Account account) async {
    await _loadEnablement();
    final accountKey = _accountKey(account);
    final hadLocalRegistration =
        _firebaseEnabledAccountKeys.contains(accountKey) ||
        _unifiedEnabledAccountKeys.contains(accountKey);

    if (hadLocalRegistration && gatewayConfigured) {
      final token = account.token;
      if (token == null || token.isEmpty) {
        throw StateError(
          "通知登録を解除するための認証トークンがありません。先に再ログインしてください。",
        );
      }
      // Do not remove the account locally if the remote registration could
      // not be revoked; otherwise the gateway could keep sending notifications.
      await _dio.deleteUri(
        _gatewayUri!.resolve("/v1/device-registrations"),
        data: <String, dynamic>{
          "schemaVersion": 1,
          "deviceId": await _deviceId(),
          "account": <String, String>{
            "host": _accountHost(account),
            "userId": account.userId,
          },
        },
        options: Options(
          headers: <String, String>{
            "Authorization": "Bearer $token",
          },
        ),
      );
    } else if (hadLocalRegistration) {
      throw StateError(
        "配信ゲートウェイが未設定のため通知登録を解除できません。ゲートウェイに接続してからアカウントを削除してください。",
      );
    }

    _firebaseEnabledAccountKeys.remove(accountKey);
    _unifiedEnabledAccountKeys.remove(accountKey);
    await _saveEnablement();

    final instance = _instanceFor(account);
    _unifiedAccounts.remove(instance);
    _pendingUnifiedEndpoints.remove(instance);
    if (AppPlatform.isAndroid && _unifiedInitialized) {
      try {
        await UnifiedPush.unregister(instance);
      } catch (_) {
        // The server registration has already been removed. The distributor
        // may have independently forgotten its local subscription.
      }
    }
  }

  Future<void> _registerDevice({
    required Account account,
    required String provider,
    required Map<String, dynamic> registration,
  }) async {
    final gateway = _gatewayUri;
    if (gateway == null) {
      throw StateError("DMSKY_PUSH_GATEWAY_URL が未設定または不正です。");
    }
    if (account.scheme == "http") {
      throw StateError("プッシュ通知の登録にはHTTPS接続のMisskeyサーバーが必要です。");
    }
    final token = account.token;
    if (token == null || token.isEmpty) {
      throw StateError("このアカウントの認証トークンを取得できません。再ログインしてください。");
    }

    await _dio.postUri(
      gateway.resolve("/v1/device-registrations"),
      data: <String, dynamic>{
        "schemaVersion": 1,
        "deviceId": await _deviceId(),
        "platform": _platformName,
        "provider": provider,
        "account": <String, String>{
          "host": _accountHost(account),
          "userId": account.userId,
        },
        "registration": registration,
      },
      options: Options(
        headers: <String, String>{
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ),
    );
  }

  Future<String> _deviceId() async {
    final preferences = await SharedPreferences.getInstance();
    const key = "dmsky_push_device_id";
    final existing = preferences.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    await preferences.setString(key, created);
    return created;
  }

  String get _platformName {
    if (kIsWeb) return "web";
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => "android",
      TargetPlatform.iOS => "ios",
      TargetPlatform.macOS => "macos",
      TargetPlatform.windows => "windows",
      TargetPlatform.linux => "linux",
      TargetPlatform.fuchsia => "fuchsia",
    };
  }

  String _instanceFor(Account account) =>
      _pushInstancePrefix + Uri.encodeComponent(
        "${_accountHost(account)}|${account.userId}",
      );

  String _accountHost(Account account) {
    final host = account.host.toLowerCase();
    return account.port == null ? host : "$host:${account.port}";
  }

  void _acceptData(Map<String, dynamic> data) {
    final payload = PushNotificationPayload.tryParse(data);
    if (payload == null) return;
    _emitTap(payload);
  }

  void _acceptEncodedPayload(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) _acceptData(decoded);
    } catch (_) {
      // Ignore malformed notification launch payloads.
    }
  }

  void acceptWebLaunchPayload(String? encoded) {
    if (encoded == null || encoded.isEmpty) return;
    _acceptEncodedPayload(encoded);
  }

  void _emitTap(PushNotificationPayload payload) {
    if (_recentEventIds.contains(payload.eventId)) return;
    _recentEventIds.add(payload.eventId);
    if (_recentEventIds.length > 256) {
      _recentEventIds.remove(_recentEventIds.first);
    }
    if (_tapController.hasListener) {
      _tapController.add(payload);
    } else {
      _pendingTaps.add(payload);
      if (_pendingTaps.length > 16) _pendingTaps.removeAt(0);
    }
  }

  List<PushNotificationPayload> takePendingTaps() {
    final pending = List<PushNotificationPayload>.of(_pendingTaps);
    _pendingTaps.clear();
    return pending;
  }

  String get configurationSummary {
    final parts = <String>[];
    parts.add(firebaseConfigured ? "Firebase 設定あり" : "Firebase 設定なし");
    parts.add(gatewayConfigured ? "配信ゲートウェイ設定あり" : "配信ゲートウェイ設定なし");
    if (AppPlatform.isAndroid) {
      parts.add(_unifiedInitialized ? "UnifiedPush 受信機あり" : "UnifiedPush 未初期化");
    }
    if (_lastFirebaseError != null) parts.add("FCM: $_lastFirebaseError");
    if (_lastUnifiedError != null) parts.add("UnifiedPush: $_lastUnifiedError");
    return parts.join(" / ");
  }

  static String? _stringOrNull(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}
