import 'dart:io';

import 'package:dmsky_client/rust/api/aiscript.dart';
import 'package:dmsky_client/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    // flutter_tester has no packaged app library search path. Load the actual
    // build-hook output so these tests also verify the bundled bridge symbols.
    final library = Platform.isWindows
        ? 'rust_lib_aria.dll'
        : Platform.isMacOS
        ? 'librust_lib_aria.dylib'
        : 'librust_lib_aria.so';
    final file = File(
      'build/native_assets/${Platform.operatingSystem}/$library',
    );
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Rust build-hook output is missing',
    );
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(file.absolute.path),
    );
  });

  for (final legacy in [true, false]) {
    test(
      'bundled AiScript runtime executes ${legacy ? "v0" : "v1"} and calls Dart',
      () async {
        final messages = <String>[];
        final script = await AiScript.newInstance(
          read: (_) => '',
          write: messages.add,
        );
        try {
          await script.exec(input: '<: (1 + 1)', isLegacy: legacy);
          expect(messages, ['num<2>']);
        } finally {
          await script.abort();
          script.dispose();
        }
      },
    );
  }
}
