import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/common.dart';
import 'package:integration_test/integration_test.dart';

import '../test/test_util/native_play_scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final report = reportTestException;
  reportTestException = (details, description) {
    report(details, description);
    // FlutterErrorDetails.toString() omits diagnostic text in release mode.
    // Preserve the actual failure and stack in Android's JUnit report.
    binding.results[description] = Failure(
      description,
      '${details.exceptionAsString()}\n${details.stack}',
    );
  };
  nativePlayScenario();
}
