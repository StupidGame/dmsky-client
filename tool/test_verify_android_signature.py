import unittest
from pathlib import Path

from verify_android_signature import validate_certificate_report


class CertificateReportTest(unittest.TestCase):
    key = "a" * 64
    other_key = "b" * 64

    def test_actual_android_sdk_v2_report(self):
        root = Path(__file__).resolve().parents[1]
        report = (root / "tool/testdata/apksigner-v2.txt").read_text()
        expected = (root / "android/signing/certificate.sha256").read_text().strip()
        validate_certificate_report(report, expected)

    def test_actual_report_with_wrong_key_is_rejected(self):
        report = (Path(__file__).parent / "testdata/apksigner-v2.txt").read_text()
        with self.assertRaises(SystemExit):
            validate_certificate_report(report, self.other_key)

    def test_different_key_in_another_signature_scheme_is_rejected(self):
        with self.assertRaises(SystemExit):
            validate_certificate_report(
                f"V2 Signer: certificate SHA-256 digest: {self.key}\n"
                f"V3 Signer: certificate SHA-256 digest: {self.other_key}\n",
                self.key,
            )

    def test_same_key_in_multiple_signature_schemes(self):
        validate_certificate_report(
            f"V2 Signer: certificate SHA-256 digest: {self.key}\n"
            f"V3.1 Signer: certificate SHA-256 digest: {self.key}\n",
            self.key,
        )

    def test_numbered_signer(self):
        validate_certificate_report(
            f"Signer #1 certificate SHA-256 digest: {self.key}\n", self.key,
        )

    def test_sdk_specific_signer(self):
        validate_certificate_report(
            f"Signer (minSdkVersion=33, maxSdkVersion=2147483647) certificate SHA-256 digest: {self.key}\n",
            self.key,
        )

    def test_same_key_in_multiple_sdk_ranges(self):
        output = "\n".join([
            f"Signer (minSdkVersion=33, maxSdkVersion=2147483647) certificate SHA-256 digest: {self.key}",
            f"Signer (minSdkVersion=24, maxSdkVersion=32) certificate SHA-256 digest: {self.key}",
        ])
        validate_certificate_report(output, self.key)

    def test_source_stamp_does_not_replace_app_identity(self):
        with self.assertRaises(SystemExit):
            validate_certificate_report(
                f"Source Stamp Signer certificate SHA-256 digest: {self.key}\n",
                self.key,
            )

    def test_different_signing_key_is_rejected(self):
        with self.assertRaises(SystemExit):
            validate_certificate_report(
                f"Signer #1 certificate SHA-256 digest: {self.other_key}\n",
                self.key,
            )

    def test_rotation_to_another_key_is_rejected(self):
        with self.assertRaises(SystemExit):
            validate_certificate_report(
                f"Signer (minSdkVersion=24, maxSdkVersion=32) certificate SHA-256 digest: {self.key}\n"
                f"Signer (minSdkVersion=33, maxSdkVersion=2147483647) certificate SHA-256 digest: {self.other_key}\n",
                self.key,
            )


if __name__ == "__main__":
    unittest.main()
