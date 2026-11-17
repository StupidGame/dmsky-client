import 'package:dmsky_client/providers.dart';
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
  for (var i = 0; i < 150; i++) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  expect(finder, findsWidgets);
}

Widget playFixture(
  PlayApi api, {
  bool fromLink = false,
  String link = '/play/native-test',
}) {
  final misskey = MockMisskey();
  when(misskey.flash).thenReturn(api);
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Play link runs native UI, updates through Rust callbacks, and stops',
    (tester) async {
      final launcher = MockUrlLauncherPlatform();
      UrlLauncherPlatform.instance = launcher;
      final api = PlayApi(counterScript);
      await tester.pumpWidget(playFixture(api, fromLink: true));
      await tester.tap(find.text('Playリンク'));
      await pumpUntil(tester, find.text('プレイ'));
      await tester.tap(find.text('プレイ'));
      await pumpUntil(tester, find.text('カウント: 0'));
      expect(find.text(TestData.account.i.username), findsOneWidget);
      await tester.tap(find.text('増やす'));
      await pumpUntil(tester, find.text('カウント: 1'));
      await tester.tap(find.text('終了'));
      await pumpUntil(tester, find.text('プレイ'));
      expect(find.text('増やす'), findsNothing);
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
