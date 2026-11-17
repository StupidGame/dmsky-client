import unittest
from unittest.mock import Mock

from run_with_download_retry import run_once, run_with_retry


RATE_LIMIT = """
Could not resolve org.jetbrains.kotlin:kotlin-gradle-plugins-bom:2.2.20.
> Could not GET 'https://repo.maven.apache.org/maven2/example.pom'.
  Received status code 429 from server: Too Many Requests
"""


class DownloadRetryTest(unittest.TestCase):
    def run_build(self, results):
        runner = Mock(side_effect=results)
        sleep = Mock()
        code = run_with_retry(["flutter", "build", "apk"], runner=runner, sleep=sleep)
        return code, runner, sleep

    def test_success_does_not_retry(self):
        code, runner, sleep = self.run_build([(0, "Built APK")])
        self.assertEqual(code, 0)
        runner.assert_called_once_with(["flutter", "build", "apk"])
        sleep.assert_not_called()

    def test_gradle_rate_limit_retries_then_succeeds(self):
        code, runner, sleep = self.run_build([(1, RATE_LIMIT), (0, "Built APK")])
        self.assertEqual(code, 0)
        self.assertEqual(runner.call_count, 2)
        sleep.assert_called_once_with(30)

    def test_server_errors_and_timeouts_retry(self):
        for diagnostic in [
            "Received status code 503 from server: Service Unavailable",
            "Read timed out",
            "Connection reset",
        ]:
            with self.subTest(diagnostic=diagnostic):
                code, runner, sleep = self.run_build([
                    (1, f"Could not GET 'https://repo.example/file'. {diagnostic}"),
                    (0, "Built APK"),
                ])
                self.assertEqual(code, 0)
                self.assertEqual(runner.call_count, 2)
                sleep.assert_called_once_with(30)

    def test_compile_authentication_and_missing_artifacts_fail_immediately(self):
        for output in [
            "e: MainActivity.kt: Unresolved reference 'example'",
            "Could not GET 'https://repo.example/file'. Received status code 401",
            "Could not GET 'https://repo.example/file'. Received status code 403",
            "Could not GET 'https://repo.example/file'. Received status code 404",
            "Expected HTTP 429 but was 200: test assertion failed",
        ]:
            with self.subTest(output=output):
                code, runner, sleep = self.run_build([(7, output)])
                self.assertEqual(code, 7)
                self.assertEqual(runner.call_count, 1)
                sleep.assert_not_called()

    def test_retry_budget_preserves_failure_and_increases_delay(self):
        code, runner, sleep = self.run_build([(9, RATE_LIMIT)] * 4)
        self.assertEqual(code, 9)
        self.assertEqual(runner.call_count, 4)
        self.assertEqual([call.args[0] for call in sleep.call_args_list], [30, 60, 120])

    def test_compiler_failure_after_download_retry_is_not_retried(self):
        code, runner, sleep = self.run_build([
            (1, RATE_LIMIT), (2, "Compilation failed: unresolved reference"),
        ])
        self.assertEqual(code, 2)
        self.assertEqual(runner.call_count, 2)
        sleep.assert_called_once_with(30)

    def test_real_command_captures_stderr_and_exit_code(self):
        import sys
        code, output = run_once([
            sys.executable, "-c",
            "import sys; print('diagnostic', file=sys.stderr); sys.exit(3)",
        ])
        self.assertEqual(code, 3)
        self.assertIn("diagnostic", output)


if __name__ == "__main__":
    unittest.main()
