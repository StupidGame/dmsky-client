import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/view/login_page/login_page.dart";
import "package:dmsky_client/view/themes/dmsky_circuit.dart";

import "../test_util/default_root_widget.dart";

void main() {
  for (final size in [const Size(360, 740), const Size(1280, 800)]) {
    testWidgets(
      "DMSKY login fits ${size.width.toInt()}px and switches authentication",
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: DefaultRootNoRouterWidget(child: LoginPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DmskyBrand), findsOneWidget);
        expect(find.text("DMSKY"), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(Tab).last);
        await tester.pumpAndSettle();
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(
          fields.any((field) => field.obscureText && !field.enableSuggestions),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
