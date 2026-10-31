#!/usr/bin/env python3
"""Restore the fixed Android signer without storing plaintext keys in the repo."""

import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    passphrase = os.environ.get("ANDROID_SIGNING_PASSPHRASE")
    if not passphrase:
        raise SystemExit(
            "Set the repository Actions secret ANDROID_SIGNING_PASSPHRASE. "
            "Release builds never fall back to a debug or newly generated key."
        )
    result = subprocess.run(
        [
            "gpg", "--batch", "--quiet", "--pinentry-mode", "loopback",
            "--passphrase-fd", "0", "--decrypt",
            str(root / "android/signing/release-key.gpg"),
        ],
        input=passphrase.encode(), capture_output=True,
    )
    if result.returncode:
        raise SystemExit("Unable to decrypt the fixed Android signing key.")
    bundle = json.loads(result.stdout)
    expected = (root / "android/signing/certificate.sha256").read_text().strip()
    if bundle["certificate_sha256"] != expected:
        raise SystemExit("The signing bundle does not match the committed certificate.")
    raw = base64.b64decode(bundle["keystore_base64"], validate=True)
    if hashlib.sha256(raw).hexdigest() != bundle["keystore_sha256"]:
        raise SystemExit("Invalid signing keystore checksum.")

    parent = Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir()))
    destination = parent / "dmsky-client-signing"
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)
    destination.chmod(0o700)
    keystore = destination / "release.p12"
    keystore.write_bytes(raw)
    keystore.chmod(0o600)
    values = {
        "ANDROID_KEYSTORE_PATH": str(keystore),
        "ANDROID_KEYSTORE_PASSWORD": bundle["keystore_password"],
        "ANDROID_KEY_ALIAS": bundle["key_alias"],
        "ANDROID_KEY_PASSWORD": bundle["key_password"],
    }
    if any("\n" in value or "\r" in value for value in values.values()):
        raise SystemExit("Invalid signing environment value.")
    env_file = Path(os.environ.get("GITHUB_ENV", str(destination / "signing.env")))
    with env_file.open("a") as stream:
        for key, value in values.items():
            stream.write(f"{key}={value}\n")
    if "GITHUB_ACTIONS" in os.environ:
        print(f"::add-mask::{bundle['keystore_password']}")
        print(f"::add-mask::{bundle['key_password']}")
    else:
        env_file.chmod(0o600)
        print(f"Signing environment written to {env_file}")
    print(f"Fixed signing certificate SHA-256: {expected}")


if __name__ == "__main__":
    main()
