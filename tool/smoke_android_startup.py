#!/usr/bin/env python3
"""Install the release APK on a disposable emulator and check launcher startup."""

import json
import os
from pathlib import Path
import subprocess
import sys
import time


PACKAGE = "app.dmsky.dmsky_client"
REPORTS = Path("test-results/android-startup")
DEVICE = f"emulator-{os.environ.get('EMULATOR_PORT', '5554')}"


def adb(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["adb", "-s", DEVICE, *args], capture_output=True, check=check, timeout=90
    )


def capture(name: str) -> None:
    logs = adb("logcat", "-d", "-v", "threadtime", check=False)
    (REPORTS / f"{name}-logcat.txt").write_bytes(logs.stdout + logs.stderr)
    image = adb("exec-out", "screencap", "-p", check=False)
    if image.returncode == 0:
        (REPORTS / f"{name}.png").write_bytes(image.stdout)
    activity = adb("shell", "dumpsys", "activity", "activities", check=False)
    (REPORTS / f"{name}-activities.txt").write_bytes(activity.stdout)


def is_foreground() -> bool:
    activity = adb("shell", "dumpsys", "activity", "activities").stdout.decode()
    return any(
        "topResumedActivity=" in line and PACKAGE in line
        for line in activity.splitlines()
    )


def launch(name: str) -> str:
    result = adb(
        "shell", "am", "start", "-W",
        "-a", "android.intent.action.MAIN",
        "-c", "android.intent.category.LAUNCHER",
        "-f", "0x10200000", "-n", f"{PACKAGE}/.MainActivity",
    )
    (REPORTS / f"{name}-launch.txt").write_bytes(result.stdout + result.stderr)
    if b"Status: ok" not in result.stdout or b"Error:" in result.stdout:
        raise RuntimeError(f"{name}: Android could not start the launcher activity")

    initial_pid = ""
    for _ in range(20):
        process = adb("shell", "pidof", PACKAGE, check=False)
        pid = process.stdout.decode().strip()
        if not pid:
            raise RuntimeError(f"{name}: app process exited after launcher startup")
        if initial_pid and pid != initial_pid:
            raise RuntimeError(f"{name}: app process restarted unexpectedly")
        initial_pid = pid
        time.sleep(1)
    if not is_foreground():
        raise RuntimeError(f"{name}: launcher did not display the app in the foreground")
    return initial_pid


def main() -> None:
    REPORTS.mkdir(parents=True, exist_ok=True)
    adb("install", "-r", sys.argv[1])
    adb("logcat", "-c")
    try:
        adb("shell", "am", "force-stop", PACKAGE)
        cold_pid = launch("cold")
        capture("cold")
        adb("shell", "input", "keyevent", "KEYCODE_HOME")
        for _ in range(20):
            if not is_foreground():
                break
            time.sleep(0.25)
        else:
            raise RuntimeError("Home did not move the app into the background")
        warm_pid = launch("reopen")
        if warm_pid != cold_pid:
            raise RuntimeError("Reopening the app replaced its running process")
        capture("reopen")
        (REPORTS / "result.json").write_text(
            json.dumps({
                "cold_start": "passed", "reopen": "passed", "pid": cold_pid,
                "cold_foreground": True, "reopen_foreground": True,
            })
        )
        print("Release APK survived cold startup and launcher reopen.")
    finally:
        capture("final")


if __name__ == "__main__":
    main()
