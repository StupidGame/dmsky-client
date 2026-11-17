import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:mockito/mockito.dart";
import "package:dmsky_client/model/general_settings.dart";
import "package:dmsky_client/model/tab_setting.dart";
import "package:dmsky_client/model/tab_icon.dart";
import "package:dmsky_client/model/tab_type.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/repository/time_line_repository.dart";
import "package:dmsky_client/repository/general_settings_repository.dart";
import "package:dmsky_client/view/time_line_page/time_line_page.dart";
import "package:dmsky_client/view/time_line_page/timeline_tab_button.dart";
import "package:dmsky_client/view/time_line_page/timeline_tablet_ui.dart";

import "../../test_util/default_root_widget.dart";
import "../../test_util/mock.mocks.dart";
import "../../test_util/test_datas.dart";

class _EmptyTimeline extends TimelineRepository {
  _EmptyTimeline(super.notes, super.settings, super.tab);
}

class _Settings extends GeneralSettingsRepository {
  _Settings(this.position);
  final TabPosition position;

  @override
  GeneralSettings get settings =>
      GeneralSettings(isDeckMode: true, tabPosition: position);
}

void main() {
  for (final (size, position, scale) in [
    (const Size(320, 690), TabPosition.top, 1.0),
    (const Size(412, 915), TabPosition.top, 1.0),
    (const Size(915, 412), TabPosition.top, 1.0),
    (const Size(412, 915), TabPosition.bottom, 1.0),
    (const Size(412, 915), TabPosition.top, 2.0),
  ]) {
    testWidgets(
      "phone timeline fills $size with $position tabs and text scale $scale",
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final tab = TabSetting(
          icon: TabIcon(codePoint: Icons.home.codePoint),
          tabType: TabType.homeTimeline,
          acct: TestData.account.acct,
          name: "ホーム",
        );
        final tabs = MockTabSettingsRepository();
        when(tabs.tabSettings).thenReturn([tab]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accountsProvider.overrideWith((ref) => [TestData.account]),
              tabSettingsRepositoryProvider.overrideWith((ref) => tabs),
              generalSettingsRepositoryProvider.overrideWith(
                (ref) => _Settings(position),
              ),
              timelineProvider.overrideWith(
                (ref, setting) => _EmptyTimeline(
                  MockNoteRepository(),
                  GeneralSettingsRepository(),
                  setting,
                ),
              ),
              emojiRepositoryProvider.overrideWith(
                (ref, account) => MockEmojiRepository(),
              ),
            ],
            child: DefaultRootNoRouterWidget(
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: TimeLinePage(initialTabSetting: tab),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.byType(TimelineTablet), findsNothing);
        expect(find.byType(TimelineTabButton), findsOneWidget);
        expect(find.byIcon(Icons.menu), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        final rect = tester.getRect(find.byType(PageView));
        expect(rect.width, size.width);
        expect(rect.height, greaterThan(100));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(tester.getSize(find.byType(AppBar).last).height, lessThan(120));

        final state = tester.state<TimeLinePageState>(
          find.byType(TimeLinePage),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(
          state.scrollControllers.every((controller) => controller.isDisposed),
          isTrue,
        );
      },
    );
  }
}
