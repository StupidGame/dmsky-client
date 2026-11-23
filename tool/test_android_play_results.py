import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import run_android_play_tests as runner
from run_android_play_tests import parse_instrumentation_result


def passed_result(count=9):
    names = "\n".join(f"INSTRUMENTATION_STATUS: test=scenario {i}" for i in range(count))
    return f"{names}\nINSTRUMENTATION_RESULT: stream=\nTime: 52.3\n\nOK ({count} tests)\n\nINSTRUMENTATION_CODE: -1\n"


class InstrumentationResultsTest(unittest.TestCase):
    def test_nine_completed_scenarios(self):
        self.assertEqual(len(parse_instrumentation_result(passed_result())), 9)

    def test_failed_or_incomplete_runs_are_rejected_even_with_success_text(self):
        for output in (
            passed_result() + "INSTRUMENTATION_FAILED: Process crashed\n",
            passed_result().replace("INSTRUMENTATION_CODE: -1", ""),
            passed_result().replace("test=scenario 8", "test=scenario 7"),
            passed_result(8),
            "INSTRUMENTATION_CODE: -1\nFAILURES!!!\nTests run: 9, Failures: 1\n",
        ):
            with self.subTest(output=output), self.assertRaises(ValueError):
                parse_instrumentation_result(output)

    def test_start_and_finish_packets_do_not_double_count_tests(self):
        result = passed_result().replace("INSTRUMENTATION_RESULT:", "INSTRUMENTATION_STATUS: test=scenario 8\nINSTRUMENTATION_RESULT:")
        self.assertEqual(len(parse_instrumentation_result(result)), 9)

    def test_install_failure_preserves_both_streams_in_diagnostics_and_junit(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk = root / "build/app/outputs/apk/release/app-release.apk"
            apk.parent.mkdir(parents=True)
            apk.touch()
            failed = subprocess.CompletedProcess(
                ["adb", "install"], 1, "Performing Push Install\n",
                "Failure [INSTALL_FAILED_INVALID_APK]\n",
            )
            with patch.object(runner.subprocess, "Popen"), \
                    patch.object(runner.subprocess, "run", return_value=failed), \
                    contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(runner.run(root), 1)
            reports = root / "build/app/outputs/androidTest-results/native-play"
            expected = failed.stdout + failed.stderr
            self.assertEqual((reports / "install-app-release.apk.txt").read_text(), expected)
            self.assertEqual((reports / "instrumentation.txt").read_text(), expected)
            failure = ET.parse(reports / "TEST-native-play.xml").find("testcase/failure")
            self.assertEqual(failure.text, expected)

    def test_interrupted_instrumentation_keeps_stdout_and_stderr_and_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path in ("release/app-release.apk", "androidTest/release/app-release-androidTest.apk"):
                apk = root / "build/app/outputs/apk" / path
                apk.parent.mkdir(parents=True)
                apk.touch()
            interrupted = subprocess.CalledProcessError(
                255, ["adb", "shell", "am", "instrument"],
                output="INSTRUMENTATION_STATUS: test=started\n", stderr="error: device offline\n",
            )
            with patch.object(runner.subprocess, "Popen"), \
                    patch.object(runner.subprocess, "run", side_effect=[
                        subprocess.CompletedProcess(["adb"], 0, "Success\n", ""),
                        subprocess.CompletedProcess(["adb"], 0, "Success\n", ""),
                        interrupted,
                    ]), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(runner.run(root), 1)
            reports = root / "build/app/outputs/androidTest-results/native-play"
            failure = ET.parse(reports / "TEST-native-play.xml").find("testcase/failure")
            self.assertIn("test=started", failure.text)
            self.assertIn("device offline", failure.text)


if __name__ == "__main__":
    unittest.main()
