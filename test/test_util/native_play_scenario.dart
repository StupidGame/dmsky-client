import 'package:dio/dio.dart';
import 'package:dmsky_client/rust/api/aiscript.dart';
import 'package:dmsky_client/rust/frb_generated.dart';
import 'package:dmsky_client/providers.dart';
import 'package:dmsky_client/view/common/misskey_notes/mfm_text.dart';
import 'package:dmsky_client/view/common/account_scope.dart';
import 'package:dmsky_client/view/common/misskey_notes/link_navigator.dart';
import 'package:dmsky_client/view/play_page/play_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:misskey_dart/misskey_dart.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'default_root_widget.dart';
import 'mock.mocks.dart';
import 'test_datas.dart';

const counterScript = r'''
/// @ 1.0.0
var n = 0
let label = Ui:C:text({ text: "カウント: 0" })
let button = Ui:C:button({
  text: "増やす"
  onClick: @() {
    n += 1
    label.update({ text: `カウント: {n}` })
  }
})
Ui:render([label, button, Ui:C:text({text: USER_USERNAME})])
''';

class PlayApi extends Fake implements MisskeyFlash {
  PlayApi(this.script);
  String script;
  bool fail = false;
  int calls = 0;
  @override
  Future<Flash> show(FlashShowRequest request) async {
    calls++;
    if (fail) throw StateError('Offline');
    return Flash(
      id: request.flashId,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      title: 'Native Play',
      summary: 'Flutterで直接実行',
      script: script,
      userId: TestData.user1.id,
      user: TestData.user1,
    );
  }

  @override
  Future<Iterable<Flash>> featured(FlashFeaturedRequest request) async => [
    await show(const FlashShowRequest(flashId: 'native-test')),
  ];
}

Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 500; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  expect(
    finder,
    findsWidgets,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? w.textSpan?.toPlainText())
        .join("\n"),
  );
}

Widget playFixture(
  PlayApi api, {
  bool fromLink = false,
  String link = '/play/native-test',
  Misskey? apiClient,
}) {
  final misskey = MockMisskey();
  when(misskey.flash).thenReturn(api);
  if (apiClient != null) {
    when(misskey.apiService).thenReturn(apiClient.apiService);
  }
  final emojis = MockEmojiRepository();
  when(emojis.emoji).thenReturn([]);
  return ProviderScope(
    overrides: [
      misskeyProvider.overrideWith((ref, account) => misskey),
      emojiRepositoryProvider.overrideWith((ref, account) => emojis),
    ],
    child: DefaultRootNoRouterWidget(
      child: AccountContextScope.as(
        account: TestData.account,
        child: fromLink
            ? Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: TextButton(
                    onPressed: () => const LinkNavigator().onTapLink(
                      context,
                      ref,
                      link,
                      null,
                    ),
                    child: const Text('Playリンク'),
                  ),
                ),
              )
            : PlayPage(account: TestData.account, playId: 'native-test'),
      ),
    ),
  );
}

void nativePlayScenario() {
  setUpAll(() async {
    // FRB creates its callback receive port lazily. Register it before a widget
    // test enters FakeAsync, so later API callbacks use live timers rather than
    // the already-finished zone of the first test.
    if (!RustLib.instance.initialized) {
      await RustLib.init();
    }
    final script = await AiScript.newInstance(read: (_) => '', write: (_) {});
    await script.abort();
    script.dispose();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

  testWidgets(
    'Play link runs native UI, updates through Rust callbacks, and stops',
    (tester) async {
      final launcher = MockUrlLauncherPlatform();
      UrlLauncherPlatform.instance = launcher;
      final api = PlayApi(counterScript);
      await tester.pumpWidget(playFixture(api, fromLink: true));
      await tester.tap(find.text('Playリンク'));
      await pumpUntil(tester, find.text('プレイ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('プレイ'));
      await pumpUntil(tester, find.text('カウント: 0'));
      expect(find.text(TestData.account.i.username), findsOneWidget);
      await tester.tap(
        find.ancestor(
          of: find.text('増やす', findRichText: true),
          matching: find.byType(FilledButton),
        ),
      );
      await pumpUntil(tester, find.text('カウント: 1'));
      await tester.tap(find.text('終了'));
      await pumpUntil(tester, find.text('プレイ'));
      expect(find.text('増やす', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
      verifyNever(launcher.launchUrl(any, any));
    },
  );

  testWidgets(
    'the Play directory opens native details from its featured list',
    (tester) async {
      final api = PlayApi(counterScript);
      await tester.pumpWidget(playFixture(api, fromLink: true, link: '/play'));
      await tester.tap(find.text('Playリンク'));
      await pumpUntil(tester, find.byType(ListTile));
      await tester.tap(find.byType(ListTile).first);
      await pumpUntil(tester, find.text('プレイ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('プレイ'));
      await pumpUntil(tester, find.text('カウント: 0'));
    },
  );

  testWidgets('native switch keeps its state and invokes AiScript', (
    tester,
  ) async {
    final api = PlayApi(r'''
/// @ 1.0.0
let label = Ui:C:text({text: "オフ"})
let toggle = Ui:C:switch({
  label: "切り替え"
  onChange: @(enabled) { label.update({text: if enabled "オン" else "オフ"}) }
})
Ui:render([label, toggle])
''');
    await tester.pumpWidget(playFixture(api));
    await pumpUntil(tester, find.text('プレイ'));
    await tester.tap(find.text('プレイ'));
    await pumpUntil(tester, find.text('切り替え'));
    await tester.tap(find.text('切り替え'));
    await pumpUntil(tester, find.text('オン'));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.text('切り替え'));
    await pumpUntil(tester, find.text('オフ'));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets(
    'MFM game controls dispatch each event ID, including nested markup',
    (tester) async {
      final api = PlayApi(r'''
/// @ 1.0.0
let state = Ui:C:text({text: "未選択", size: 1, color: "#fff"})
Ui:render([
  Ui:C:mfm({
    text: "<center><small>$[clickable.ev=0i1 **左**] $[clickable.ev=2i3 $[scale.x=1.2,y=1.2 右]]</small></center>"
    size: 1
    onClickEv: @(id) { state.update({text: id}) }
  })
  Ui:C:button({text: "**進める**", onClick: @(){ state.update({text: "ボタン成功"}) }})
  state
])
''');
      await tester.pumpWidget(playFixture(api));
      await pumpUntil(tester, find.text('プレイ'));
      await tester.tap(find.text('プレイ'));
      await pumpUntil(tester, find.text('未選択'));
      final mfm = tester
          .widgetList<MfmText>(find.byType(MfmText))
          .firstWhere((widget) => widget.mfmText!.contains('clickable'));
      expect(mfm.style!.fontSize, greaterThanOrEqualTo(12));
      expect(
        tester.widget<Text>(find.text('未選択')).style!.fontSize,
        greaterThanOrEqualTo(12),
      );
      expect(tester.widget<Text>(find.text('未選択')).style!.color, Colors.white);
      await tester.tap(find.byKey(const ValueKey('mfm-click:0i1')));
      await pumpUntil(tester, find.text('0i1'));
      await tester.tap(find.byKey(const ValueKey('mfm-click:2i3')));
      await pumpUntil(tester, find.text('2i3'));
      await tester.tap(
        find.ancestor(
          of: find.text('進める', findRichText: true),
          matching: find.byType(FilledButton),
        ),
      );
      await pumpUntil(tester, find.text('ボタン成功'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'positioned MFM controls receive taps and delayed animations stop safely',
    (tester) async {
      final api = PlayApi(r'''
/// @ 1.0.0
let label = Ui:C:text({text: "操作待ち"})
let board = Ui:C:mfm({text: "", onClickEv: @(id){ label.update({text: id}) }})
Ui:render([
  board
  Ui:C:mfm({text: "$[position.y=-1 $[clickable.ev=pet なでる]]", onClickEv: @(id){ label.update({text: id}) }})
  Ui:C:mfm({text: "$[tada.delay=20s A] $[bounce.delay=20s B] $[jump.delay=20s C] $[jelly.delay=20s D] $[shake.delay=20s E] $[twitch.delay=20s F] $[spin.delay=20s G] $[rainbow.delay=20s H]"})
  Ui:C:button({text: "盤面を描画", onClick: @(){board.update({text: "$[clickable.ev=board 盤面]"})}})
  label
])
''');
      await tester.pumpWidget(playFixture(api));
      await pumpUntil(tester, find.text('プレイ'));
      await tester.tap(find.text('プレイ'));
      await pumpUntil(tester, find.text('操作待ち'));
      await tester.tap(
        find.ancestor(
          of: find.text('盤面を描画', findRichText: true),
          matching: find.byType(FilledButton),
        ),
      );
      await pumpUntil(tester, find.byKey(const ValueKey('mfm-click:board')));
      await tester.tap(find.byKey(const ValueKey('mfm-click:pet')));
      await pumpUntil(tester, find.text('pet'));
      await tester.tap(find.text('終了'));
      await pumpUntil(tester, find.text('プレイ'));
      await tester.pump(const Duration(seconds: 25));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Play API, MFM dialogs and saved state survive restarting', (
    tester,
  ) async {
    final client = Misskey(
      host: TestData.account.host,
      token: TestData.account.token,
    );
    var requests = 0;
    client.apiService.dio.interceptors.clear();
    client.apiService.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          expect(options.path, 'pages/show');
          handler.resolve(
            Response(requestOptions: options, data: {'value': '取得成功'}),
          );
        },
      ),
    );
    final api = PlayApi(r'''
/// @ 1.0.0
let data = Mk:api("pages/show", {name: "game-data"})
let saved = Mk:load("name")
Ui:render([
  Ui:C:text({text: if saved == null data.value else saved})
  Ui:C:button({text: "保存", onClick: @(){
    Mk:save("name", "保存済み")
    Mk:dialog("**記録**", "<center>**保存完了**</center>")
  }})
])
''');
    await tester.pumpWidget(playFixture(api, apiClient: client));
    await pumpUntil(tester, find.text('プレイ'));
    await tester.tap(find.text('プレイ'));
    await pumpUntil(tester, find.text('取得成功'));
    await tester.tap(
      find.ancestor(
        of: find.text('保存', findRichText: true),
        matching: find.byType(FilledButton),
      ),
    );
    await pumpUntil(tester, find.text('保存完了', findRichText: true));
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('終了'));
    await pumpUntil(tester, find.text('プレイ'));
    await tester.tap(find.text('プレイ'));
    await pumpUntil(tester, find.text('保存済み'));
    expect(requests, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fetch errors retry inside the app', (tester) async {
    final api = PlayApi(counterScript)..fail = true;
    await tester.pumpWidget(playFixture(api));
    await pumpUntil(tester, find.text('再試行'));
    api.fail = false;
    await tester.tap(find.text('再試行'));
    await pumpUntil(tester, find.text('プレイ'));
    expect(api.calls, 2);
  });

  testWidgets('script errors are visible and can be restarted', (tester) async {
    final api = PlayApi('this is invalid script !!!');
    await tester.pumpWidget(playFixture(api));
    await pumpUntil(tester, find.text('プレイ'));
    await tester.tap(find.text('プレイ'));
    await pumpUntil(tester, find.textContaining('Playを実行できませんでした'));
    expect(find.text('プレイ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving Play while a timer is running releases its callbacks', (
    tester,
  ) async {
    final api = PlayApi(r'''
/// @ 1.0.0
let label = Ui:C:text({text: "動作中"})
Ui:render([label])
Async:interval(20, @() { label.update({text: "動作中"}) })
''');
    await tester.pumpWidget(playFixture(api));
    await pumpUntil(tester, find.text('プレイ'));
    await tester.tap(find.text('プレイ'));
    await pumpUntil(tester, find.text('動作中'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
