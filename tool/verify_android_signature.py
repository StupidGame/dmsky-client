#!/usr/bin/env python3
"""Check the selected APK architecture and the app's fixed signing identity."""

import argparse
import os
from pathlib import Path
import re
import subprocess
import zipfile


def validate_certificate_report(output, expected):
    # apksigner uses either "Signer #1" or SDK-specific signer labels for v3.1.
    # See AOSP ApkSignerTool.java's printCertificate calls. Multiple SDK ranges
    # may repeat the same certificate; every signer must still be our fixed key.
    found = {
        digest.lower()
        for digest in re.findall(
            r"^Signer (?:#\d+|\([^\r\n]+\)) certificate SHA-256 digest:\s*([a-fA-F0-9]{64})\s*$",
            output,
            re.MULTILINE,
        )
    }
    if found != {expected.lower()}:
        raise SystemExit(
            f"APK signer mismatch. Expected: {expected.lower()}; "
            f"observed: {sorted(found) or 'no recognized signer certificate'}."
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--variant", choices=["arm64", "universal"], default="arm64")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk:
        raise SystemExit("Android SDK is required for signature verification.")
    candidates = list((Path(sdk) / "build-tools").glob("*/apksigner"))
    if not candidates:
        raise SystemExit("apksigner is unavailable.")
    signer = max(candidates, key=lambda p: tuple(int(n) for n in re.findall(r"\d+", p.parent.name)))
    apk = args.apk
    with zipfile.ZipFile(apk) as archive:
        files = set(archive.namelist())
        abis = ["arm64-v8a"] if args.variant == "arm64" else ["armeabi-v7a", "arm64-v8a", "x86_64"]
        for abi in abis:
            if f"lib/{abi}/libapp.so" not in files:
                raise SystemExit(f"APK is missing required architecture {abi}.")
    result = subprocess.run(
        [str(signer), "verify", "--verbose", "--print-certs", str(apk)],
        check=True, text=True, capture_output=True,
    )
    # Certificate reports contain public material and make failures diagnosable.
    print(result.stdout, end="")
    expected = (root / "android/signing/certificate.sha256").read_text().strip().lower()
    validate_certificate_report(result.stdout, expected)
    print(f"Verified {args.variant} APK: {apk.name}; SHA-256 signer: {expected}")


if __name__ == "__main__":
    main()
