#!/usr/bin/env python3
"""Reject APKs signed with any certificate other than this app's fixed key."""

import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile


def main():
    root = Path(__file__).resolve().parents[1]
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk:
        raise SystemExit("Android SDK is required for signature verification.")
    candidates = list((Path(sdk) / "build-tools").glob("*/apksigner"))
    if not candidates:
        raise SystemExit("apksigner is unavailable.")
    signer = max(candidates, key=lambda p: tuple(int(n) for n in re.findall(r"\d+", p.parent.name)))
    apk = Path(sys.argv[1])
    with zipfile.ZipFile(apk) as archive:
        files = set(archive.namelist())
        for abi in ["armeabi-v7a", "arm64-v8a", "x86_64"]:
            if f"lib/{abi}/libapp.so" not in files:
                raise SystemExit(f"Universal APK is missing {abi}.")
    result = subprocess.run(
        [str(signer), "verify", "--verbose", "--print-certs", str(apk)],
        check=True, text=True, capture_output=True,
    )
    expected = (root / "android/signing/certificate.sha256").read_text().strip().lower()
    found = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]+)", result.stdout)
    if len(found) != 1 or found[0].lower() != expected:
        raise SystemExit("APK signature does not match the fixed signing certificate.")
    print(f"Verified universal APK: {apk.name}; SHA-256 signer: {expected}")


if __name__ == "__main__":
    main()
