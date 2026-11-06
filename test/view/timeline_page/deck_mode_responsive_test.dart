import "package:flutter_test/flutter_test.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/general_settings.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/repository/general_settings_repository.dart";
import "package:dmsky_client/view/time_line_page/time_line_page.dart";
import "package:dmsky_client/view/time_line_page/timeline_tablet_ui.dart";

import "timeline_page_test_util.dart";

class _DeckModeSettingsRepository extends GeneralSettingsRepository {
  @override
  GeneralSettings get settings => const GeneralSettings(isDeckMode: true);

  @override
  Future<void> load() async {}
}

void main() {
  testWidgets("deck mode uses the compact timeline layout on phones", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final timelineTester = TimelinePageTest(tabType: TabType.homeTimeline);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          generalSettingsRepositoryProvider.overrideWith(
            (ref) => _DeckModeSettingsRepository(),
          ),
        ],
        child: timelineTester.buildWidget(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(TimelineTablet), findsNothing);
    expect(find.byType(TimeLinePage), findsOneWidget);
  });
}
