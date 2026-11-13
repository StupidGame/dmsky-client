import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:mockito/mockito.dart";
import "package:url_launcher_platform_interface/url_launcher_platform_interface.dart";
import "package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart";
import "package:dmsky_client/view/play_page/play_page.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:dmsky_client/view/common/misskey_notes/link_navigator.dart";

import "../../test_util/mock.mocks.dart";
import "../../test_util/test_datas.dart";

class _Platform extends WebViewPlatform {
  late _Controller controller;
  late _Delegate delegate;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _Controller(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _Delegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();
  Uri? uri;
  JavaScriptMode? mode;
  _Delegate? delegate;
  int reloads = 0;
  bool back = false;
  int backs = 0;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {
    mode = javaScriptMode;
  }

  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    delegate = handler as _Delegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    uri = params.uri;
    delegate?.finished?.call(uri.toString());
  }

  @override
  Future<bool> canGoBack() async => back;
  @override
  Future<void> goBack() async {
    backs++;
    back = false;
  }

  @override
  Future<void> reload() async {
    reloads++;
    delegate?.finished?.call(uri.toString());
  }
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  NavigationRequestCallback? navigate;
  PageEventCallback? finished;
  WebResourceErrorCallback? failure;
  UrlChangeCallback? changed;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    navigate = callback;
  }

  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback callback) async {
    changed = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    failure = callback;
  }
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text("Play contents"));
}

void main() {
  final uri = Uri.parse("https://play.example/play/game123");
  testWidgets("unsupported hosts offer an explicit browser action", (
    tester,
  ) async {
    expect(WebViewPlatform.instance, isNull);
    final launcher = MockUrlLauncherPlatform();
    UrlLauncherPlatform.instance = launcher;
    await tester.pumpWidget(MaterialApp(home: PlayPage(uri: uri)));
    await tester.pumpAndSettle();
    expect(find.text("ブラウザーで開く"), findsOneWidget);
    verifyNever(launcher.launchUrl(any, any));
  });

  group("embedded Play", () {
    late _Platform platform;
    late WebViewPlatform? original;
    late MockUrlLauncherPlatform launcher;

    setUp(() {
      original = WebViewPlatform.instance;
      platform = _Platform();
      WebViewPlatform.instance = platform;
      launcher = MockUrlLauncherPlatform();
      UrlLauncherPlatform.instance = launcher;
      when(launcher.launchUrl(any, any)).thenAnswer((_) async => true);
    });
    tearDown(() {
      if (original != null) WebViewPlatform.instance = original;
    });

    testWidgets("Play loads inside the app with JavaScript enabled", (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: PlayPage(uri: uri)));
      await tester.pumpAndSettle();
      expect(find.text("Play contents"), findsOneWidget);
      expect(platform.controller.uri, uri);
      expect(platform.controller.mode, JavaScriptMode.unrestricted);
      verifyNever(launcher.launchUrl(any, any));
    });

    testWidgets(
      "same-server navigation stays embedded and script URLs are blocked",
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: PlayPage(uri: uri)));
        await tester.pumpAndSettle();
        expect(
          await platform.delegate.navigate!(
            NavigationRequest(
              url: "https://play.example/play/other",
              isMainFrame: true,
            ),
          ),
          NavigationDecision.navigate,
        );
        expect(
          await platform.delegate.navigate!(
            NavigationRequest(url: "javascript:alert(1)", isMainFrame: true),
          ),
          NavigationDecision.prevent,
        );
        verifyNever(launcher.launchUrl(any, any));
        expect(
          await platform.delegate.navigate!(
            NavigationRequest(url: "https://other.example/", isMainFrame: true),
          ),
          NavigationDecision.prevent,
        );
        verify(launcher.launchUrl("https://other.example/", any)).called(1);
      },
    );

    testWidgets("failed loads can be retried without leaving the app", (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: PlayPage(uri: uri)));
      await tester.pumpAndSettle();
      platform.delegate.failure!(
        WebResourceError(
          errorCode: -2,
          description: "failed",
          isForMainFrame: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("再試行"), findsOneWidget);
      await tester.tap(find.text("再試行"));
      await tester.pumpAndSettle();
      expect(platform.controller.reloads, 1);
      expect(find.text("Play contents"), findsOneWidget);
    });

    testWidgets("back first follows web history, then returns to the app", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openPlay(context, uri),
                child: const Text("Open Play"),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("Open Play"));
      await tester.pumpAndSettle();
      platform.controller.back = true;
      platform.delegate.changed!(UrlChange(url: uri.toString()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("戻る"));
      await tester.pumpAndSettle();
      expect(platform.controller.backs, 1);
      expect(find.byType(PlayPage), findsOneWidget);
      await tester.tap(find.byTooltip("戻る"));
      await tester.pumpAndSettle();
      expect(find.byType(PlayPage), findsNothing);
    });

    testWidgets("a Play note link opens the same embedded screen", (
      tester,
    ) async {
      final account = TestData.account;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AccountContextScope.as(
                account: account,
                child: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () => const LinkNavigator().onTapLink(
                      context,
                      ref,
                      "/play/game123",
                      null,
                    ),
                    child: const Text("Play link"),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("Play link"));
      await tester.pumpAndSettle();
      expect(find.byType(PlayPage), findsOneWidget);
      expect(
        platform.controller.uri,
        Uri.parse("https://${account.host}/play/game123"),
      );
      verifyNever(launcher.launchUrl(any, any));
    });
  });
  test("Play URLs preserve query parameters and keep origin boundaries", () {
    expect(isPlayUri(Uri.parse("https://play.example/play")), isTrue);
    expect(
      isPlayUri(Uri.parse("https://play.example/play/game123?x=1")),
      isTrue,
    );
    expect(
      isPlayUri(Uri.parse("https://user:pass@play.example/play/game123")),
      isFalse,
    );
    expect(isPlayUri(Uri.parse("javascript:/play/game123")), isFalse);
    expect(
      isSamePlayOrigin(Uri.parse("https://play.example:8443/play/x"), uri),
      isFalse,
    );
    expect(isSamePlayOrigin(Uri.parse("http:no-authority"), uri), isFalse);
  });
}
