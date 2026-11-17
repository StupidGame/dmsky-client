import 'dart:io';

import 'package:dmsky_client/rust/frb_generated.dart';
import 'package:dmsky_client/view/play_page/play_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_util/native_play_scenario.dart';
import '../../test_util/test_datas.dart';

void main() {
  setUpAll(() async {
    final library = Platform.isWindows
        ? 'rust_lib_aria.dll'
        : Platform.isMacOS
        ? 'librust_lib_aria.dylib'
        : 'librust_lib_aria.so';
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        File(
          'build/native_assets/${Platform.operatingSystem}/$library',
        ).absolute.path,
      ),
    );
  });
  nativePlayScenario();
  test('Play URL validation rejects credentials and non-http schemes', () {
    expect(isPlayUri(Uri.parse('https://play.example/play')), isTrue);
    expect(isPlayUri(Uri.parse('https://play.example/play/id')), isTrue);
    expect(
      isPlayUri(Uri.parse('https://user:pass@play.example/play/id')),
      isFalse,
    );
    expect(isPlayUri(Uri.parse('javascript:/play/id')), isFalse);
    expect(isPlayUri(Uri.parse('https://play.example/play/id/edit')), isFalse);
  });
  test(
    'remote Play uses its own account or an anonymous origin, including ports',
    () {
      final source = TestData.account.copyWith(token: 'source-token');
      final remote = source.copyWith(
        host: 'remote.example',
        token: 'remote-token',
        port: 8443,
      );
      final uri = Uri.parse('https://remote.example:8443/play/id');
      expect(accountForPlay(uri, source, [remote]), same(remote));
      final guest = accountForPlay(uri, source, []);
      expect(guest.token, isNull);
      expect(guest.isDemoAccount, isTrue);
      expect(playServer(guest).origin, uri.origin);
      final otherPort = Uri.parse('https://${source.host}:8443/play/id');
      expect(accountForPlay(otherPort, source, [source]).token, isNull);
    },
  );
  testWidgets('an account token is never used for a different Play origin', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await expectLater(
      openPlay(
        tester.element(find.byType(SizedBox)),
        Uri.parse('https://other.example/play/id'),
        account: TestData.account,
      ),
      throwsArgumentError,
    );
  });
}
