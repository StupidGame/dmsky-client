"""Build release Play tests before the emulator, then run them with adb."""

import argparse
from pathlib import Path
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

from run_with_download_retry import run_with_retry


def parse_instrumentation_result(output, minimum=9):
    if re.search(r"INSTRUMENTATION_FAILED|Process crashed|FAILURES!!!|shortMsg=", output):
        raise ValueError("Android instrumentation failed")
    summary = re.search(r"^OK \((\d+) tests?\)\s*$", output, re.MULTILINE)
    names = list(dict.fromkeys(re.findall(r"^INSTRUMENTATION_STATUS: test=(.+)\r?$", output, re.MULTILINE)))
    if not summary or int(summary[1]) < minimum or len(names) != int(summary[1]):
        raise ValueError("Native Play scenarios did not all report success")
    if not re.search(r"^INSTRUMENTATION_CODE: -1\s*$", output, re.MULTILINE):
        raise ValueError("Android instrumentation did not finish")
    return names


def build(root):
    # R8 and Flutter compilation run without an emulator competing for memory.
    return run_with_retry([
        str(root / "android/gradlew"), "--project-dir", str(root / "android"),
        ":app:assembleRelease", ":app:assembleReleaseAndroidTest",
        "-Pdmsky-native-play-test=true",
        f"-Ptarget={root / 'integration_test/native_play_test.dart'}",
        "-Ptarget-platform=android-x64", "-Ptree-shake-icons=false", "--no-daemon",
        "--max-workers=2", "-Dorg.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g",
    ])


def run(root):
    folder = root / "build/app/outputs/androidTest-results/native-play"
    folder.mkdir(parents=True, exist_ok=True)
    adb = ["adb", "-s", os.environ.get("ANDROID_SERIAL", "emulator-5554")]
    target = root / "build/app/outputs/apk/release/app-release.apk"
    tests = root / "build/app/outputs/apk/androidTest/release/app-release-androidTest.apk"
    suite = ET.Element("testsuite", name="Native Play release")
    output = ""
    capture = None
    try:
        with (folder / "logcat.txt").open("w") as log:
            capture = subprocess.Popen([*adb, "logcat", "-v", "threadtime"], stdout=log, stderr=subprocess.STDOUT)
            for apk in (target, tests):
                if not apk.is_file():
                    raise FileNotFoundError(f"Build the instrumentation APKs first: {apk}")
                # API 36 CI images have returned blank errors from streamed installs.
                # Transfer the APK separately and retain the installer's diagnostics.
                installed = subprocess.run([
                    *adb, "install", "--no-streaming", "-r", "-t", str(apk),
                ], capture_output=True, text=True, timeout=180)
                (folder / f"install-{apk.name}.txt").write_text(installed.stdout + installed.stderr)
                installed.check_returncode()
            result = subprocess.run([
                *adb, "shell", "am", "instrument", "-w", "-r",
                "app.dmsky.dmsky_client.test/androidx.test.runner.AndroidJUnitRunner",
            ], capture_output=True, text=True, timeout=600, check=True)
            output = result.stdout + result.stderr
            names = parse_instrumentation_result(output)
            for name in names:
                ET.SubElement(suite, "testcase", name=name, classname="NativePlayTest")
            print(f"Native Play release integration: {len(names)} scenarios passed.")
            return 0
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        if not output:
            parts = (getattr(error, "stdout", None), getattr(error, "stderr", None))
            output = "".join(
                part.decode(errors="replace") if isinstance(part, bytes) else part or ""
                for part in parts
            )
        detail = output or str(error)
        case = ET.SubElement(suite, "testcase", name="Android instrumentation", classname="NativePlayTest")
        ET.SubElement(case, "failure", message=str(error)).text = detail
        print(detail, file=sys.stderr)
        return 1
    finally:
        if capture is not None:
            capture.terminate()
            try:
                capture.wait(timeout=5)
            except subprocess.TimeoutExpired:
                capture.kill()
                capture.wait()
        (folder / "instrumentation.txt").write_text(output)
        ET.ElementTree(suite).write(folder / "TEST-native-play.xml", encoding="utf-8", xml_declaration=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-only", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    return build(root) if args.build_only else run(root)


if __name__ == "__main__":
    sys.exit(main())
