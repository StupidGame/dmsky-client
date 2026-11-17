"""Run the native Play scenarios against an R8-optimized Android release app."""

from pathlib import Path
import sys
import subprocess
import xml.etree.ElementTree as ET

from run_with_download_retry import run_with_retry


def main():
    root = Path(__file__).resolve().parent.parent
    log_path = root / "build/app/outputs/androidTest-results/native-play-logcat.txt"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w") as log:
        capture = subprocess.Popen(["adb", "logcat", "-v", "threadtime"], stdout=log, stderr=subprocess.STDOUT)
        try:
            code = run_with_retry([
                str(root / "android/gradlew"), "--project-dir", str(root / "android"),
                ":app:connectedReleaseAndroidTest",
                "-Pdmsky-native-play-test=true",
                f"-Ptarget={root / 'integration_test/native_play_test.dart'}",
                "-Ptarget-platform=android-x64", "-Ptree-shake-icons=false", "--no-daemon",
            ])
        finally:
            capture.terminate()
            try:
                capture.wait(timeout=5)
            except subprocess.TimeoutExpired:
                capture.kill()
                capture.wait()
    if code:
        return code
    reports = list((root / "build/app/outputs/androidTest-results").rglob("TEST-*.xml"))
    cases = [case for report in reports for case in ET.parse(report).iter("testcase")]
    if len(cases) < 9 or any(case.find("failure") is not None or case.find("error") is not None for case in cases):
        sys.exit("Native Play integration scenarios did not all pass; inspect the Android test reports")
    print(f"Native Play release integration: {len(cases)} scenarios passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
