import "package:dmsky_client/util/app_platform.dart";
import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/const.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/marionette_debug.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/model/push_notification_payload.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/services/push_notification_service.dart";
import "package:misskey_dart/misskey_dart.dart";
import "package:dmsky_client/view/common/dialog/dialog_scope.dart";
import "package:dmsky_client/view/common/error_dialog_listener.dart";
import "package:dmsky_client/view/common/sharing_intent_listener.dart";
import "package:dmsky_client/view/themes/app_theme_scope.dart";
import "package:stack_trace/stack_trace.dart" as stack_trace;
import "package:window_manager/window_manager.dart";

Future<void> main(List<String> args) async {
  // debug ビルドでは marionette の binding が立ち上がる。
  // release では通常の WidgetsFlutterBinding と同じ。
  initializeMarionetteBinding();
  await PushNotificationService.instance.initialize(args);
  if (args.contains("--unifiedpush-bg")) return;
  if (kIsWeb) {
    PushNotificationService.instance.acceptWebLaunchPayload(
      Uri.base.queryParameters["dmsky_push"],
    );
  }
  if (!kIsWeb &&
      (AppPlatform.isWindows || AppPlatform.isMacOS || AppPlatform.isLinux)) {
    await windowManager.ensureInitialized();
  }
  FlutterError.demangleStackTrace = (stack) {
    if (stack is stack_trace.Trace) return stack.vmTrace;
    if (stack is stack_trace.Chain) return stack.toTrace().vmTrace;
    return stack;
  };

  runApp(ProviderScope(observers: marionetteObservers, child: const Miria()));
}

class Miria extends HookConsumerWidget with WidgetsBindingObserver {
  const Miria({super.key});

  @override
  Future<void> didChangePlatformBrightness() async {
    super.didChangePlatformBrightness();
    if (!isDesktop) return;

    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    /// Set up window brightness follow system theme mode.
    await WindowManager.instance.setBrightness(brightness);
    await WindowManager.instance.setTitleBarStyle(TitleBarStyle.normal);
  }

  Future<void> _initWindow(WidgetRef ref) async {
    if (!isDesktop) return;
    await windowManager.setPreventClose(true);
    final config = ref.read(desktopSettingsRepositoryProvider).settings;

    final size = (config.window.w > 0 && config.window.h > 0)
        ? Size(config.window.w, config.window.h)
        : const Size(400, 700);

    final position = (config.window.x != null && config.window.y != null)
        ? Offset(config.window.x!, config.window.y!)
        : null;

    final opt = WindowOptions(
      size: size,
      center: position == null,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    if (position != null) {
      await windowManager.setPosition(position);
    }

    await windowManager.waitUntilReadyToShow(opt, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      if (!isDesktop) return null;
      final windowListener = ref.read(miriaWindowListenerProvider);
      WidgetsBinding.instance.addObserver(this);
      windowManager.addListener(windowListener);
      return () {
        WidgetsBinding.instance.removeObserver(this);
        windowManager.removeListener(windowListener);
      };
    }, const []);
    useMemoized(() {
      unawaited(() async {
        if (isDesktop) {
          await ref.read(desktopSettingsRepositoryProvider).load();
        }
        await _initWindow(ref);
      }());
    });

    final accounts = ref.watch(accountsProvider);
    useEffect(() {
      unawaited(PushNotificationService.instance.syncAccounts(accounts));
      return null;
    }, [accounts]);

    useEffect(() {
      final service = PushNotificationService.instance;
      void handleTap(PushNotificationPayload payload) {
        unawaited(_openPushNotification(ref, payload));
      }

      final subscription = service.onNotificationTap.listen(handleTap);
      for (final payload in service.takePendingTaps()) {
        handleTap(payload);
      }
      return subscription.cancel;
    }, const []);

    final language = ref.watch(
      generalSettingsRepositoryProvider.select(
        (value) => value.settings.languages,
      ),
    );
    final appRouter = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: "DMSKY Client",
      debugShowCheckedModeBanner: false,
      locale: Locale(language.countryCode, language.languageCode),
      supportedLocales: const [
        Locale("ja", "JP"),
        Locale("ja", "OJ"),
        Locale("zh", "CN"),
      ],
      scrollBehavior: AppScrollBehavior(),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, widget) {
        return AppThemeScope(
          child: DialogScope(
            child: SharingIntentListener(
              router: appRouter,
              child: ErrorDialogListener(child: widget ?? Container()),
            ),
          ),
        );
      },
      routerConfig: appRouter.config(),
    );
  }
}

Future<void> _openPushNotification(
  WidgetRef ref,
  PushNotificationPayload payload,
) async {
  final accounts = ref.read(accountsProvider);
  Account? account;
  for (final candidate in accounts) {
    final host = "${candidate.host.toLowerCase()}${candidate.port == null ? "" : ":${candidate.port}"}";
    if (host == payload.host) {
      account = candidate;
      break;
    }
  }
  if (account == null) return;

  final accountContext = AccountContext.as(account);
  final router = ref.read(appRouterProvider);
  try {
    switch (payload.target) {
      case PushNotificationTarget.note:
        final note = await ref
            .read(misskeyProvider(account))
            .notes
            .show(NotesShowRequest(noteId: payload.noteId!));
        await router.push(
          NoteDetailRoute(note: note, accountContext: accountContext),
        );
        break;
      case PushNotificationTarget.user:
        await router.push(
          UserRoute(
            userId: payload.userId!,
            accountContext: accountContext,
          ),
        );
        break;
      case PushNotificationTarget.chat:
        final chatId = payload.chatId!;
        final misskey = ref.read(misskeyProvider(account));
        if (chatId.startsWith("room:")) {
          final roomId = chatId.substring("room:".length);
          final room = await misskey.chat.rooms.show(
            ChatRoomsShowRequest(roomId: roomId),
          );
          await router.push(
            RoomChatRoute(room: room, accountContext: accountContext),
          );
        } else if (chatId.startsWith("user:")) {
          final userId = chatId.substring("user:".length);
          final user = await misskey.users.show(
            UsersShowRequest(userId: userId),
          );
          await router.push(
            UserChatRoute(user: user, accountContext: accountContext),
          );
        } else {
          throw FormatException("未対応のチャット通知IDです");
        }
        break;
      case PushNotificationTarget.notifications:
        await router.push(
          NotificationRoute(accountContext: accountContext),
        );
        break;
    }
  } catch (_) {
    await router.push(
      NotificationRoute(accountContext: accountContext),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
