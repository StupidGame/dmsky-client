import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:dmsky_client/view/time_line_page/timeline_layout.dart";

void main() {
  for (final (size, deckMode, expectedLayout) in [
    (const Size(412, 915), true, "compact"),
    (const Size(915, 412), true, "compact"),
    (const Size(599, 900), true, "compact"),
    (const Size(600, 960), true, "deck"),
    (const Size(1280, 800), true, "deck"),
    (const Size(1280, 800), false, "compact"),
  ]) {
    testWidgets("$size with deck mode $deckMode uses $expectedLayout", (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final builtLayouts = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: TimelineLayout(
            deckMode: deckMode,
            compactBuilder: (_) {
              builtLayouts.add("compact");
              return const Text("compact");
            },
            deckBuilder: (_) {
              builtLayouts.add("deck");
              return const Text("deck");
            },
          ),
        ),
      );

      expect(find.text(expectedLayout), findsOneWidget);
      expect(builtLayouts, everyElement(expectedLayout));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("layout responds to resizing and preference changes", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final deckMode = ValueNotifier(true);
    addTearDown(deckMode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: deckMode,
          builder: (_, enabled, _) => TimelineLayout(
            deckMode: enabled,
            compactBuilder: (_) => const Text("compact"),
            deckBuilder: (_) => const Text("deck"),
          ),
        ),
      ),
    );
    expect(find.text("deck"), findsOneWidget);

    tester.view.physicalSize = const Size(412, 915);
    await tester.pump();
    expect(find.text("compact"), findsOneWidget);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    expect(find.text("deck"), findsOneWidget);

    deckMode.value = false;
    await tester.pump();
    expect(find.text("compact"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
