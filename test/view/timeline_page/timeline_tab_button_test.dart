import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/model/acct.dart";
import "package:dmsky_client/model/tab_icon.dart";
import "package:dmsky_client/model/tab_setting.dart";
import "package:dmsky_client/model/tab_type.dart";
import "package:dmsky_client/view/time_line_page/timeline_tab_button.dart";

TabSetting tab(String username, String host, {String? name = "ホーム"}) =>
    TabSetting(
      icon: TabIcon(codePoint: Icons.home.codePoint),
      tabType: TabType.homeTimeline,
      acct: Acct(username: username, host: host),
      name: name,
    );

Widget root(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale("ja"),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets("tabs show distinct usernames and hosts with the same name", (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      root(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TimelineTabButton(
                tabSetting: tab("alice", "one.example"),
                active: true,
                onPressed: () {},
              ),
              TimelineTabButton(
                tabSetting: tab("alice", "two.example"),
                active: false,
                onPressed: () {},
              ),
              TimelineTabButton(
                tabSetting: tab("bob", "two.example"),
                active: false,
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("ホーム"), findsNWidgets(3));
    expect(find.text("@alice@one.example"), findsOneWidget);
    expect(find.text("@alice@two.example"), findsOneWidget);
    expect(find.text("@bob@two.example"), findsOneWidget);
    expect(find.byTooltip("ホーム\n@alice@two.example"), findsOneWidget);

    await tester.ensureVisible(find.text("@bob@two.example"));
    await tester.tap(find.text("@bob@two.example"));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets("long account names fit narrow headers with readable scaling", (
    tester,
  ) async {
    final setting = tab("a_very_long_username", "a.very.long.server.example");
    await tester.pumpWidget(
      root(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 150,
            child: TimelineTabLabel(tabSetting: setting),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(setting.acct.toString()), findsOneWidget);
    expect(find.byTooltip("ホーム\n${setting.acct}"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("unnamed tabs use the localized timeline name", (tester) async {
    await tester.pumpWidget(
      root(
        TimelineTabLabel(tabSetting: tab("alice", "one.example", name: null)),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(TimelineTabLabel));
    expect(find.text(S.of(context).homeTimeline), findsOneWidget);
    expect(find.text("@alice@one.example"), findsOneWidget);
  });
}
