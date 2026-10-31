import "package:flutter_test/flutter_test.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/repository/account_repository.dart";
import "package:mockito/mockito.dart";

import "../test_util/mock.mocks.dart";

void main() {
  test(
    "MiAuth preserves the server port, creates new sessions, and avoids administrator permissions",
    () async {
      final misskey = MockMisskey();
      when(misskey.endpoints()).thenAnswer((_) async => ["emojis", "meta"]);
      final container = ProviderContainer(
        overrides: [
          misskeyWithoutAccountProvider.overrideWith((ref, host) => misskey),
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(accountRepositoryProvider.notifier);
      final first = await repository.prepareMiAuth("http://localhost:3000");
      final second = await repository.prepareMiAuth("http://localhost:3000");

      expect(first.origin, "http://localhost:3000");
      expect(first.queryParameters["name"], "DMSKY Client");
      expect(first.queryParameters["permission"], contains("write:notes"));
      expect(first.queryParameters["permission"], isNot(contains("admin:")));
      expect(first.path, isNot(second.path));
      expect(repository.authorizationUri, second);

      await expectLater(
        repository.validateMiAuth("http://localhost:3001"),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
