"""Real Ed25519 tests with an isolated, intentionally disposable test identity."""

import base64
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest

RELEASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RELEASE))
from evidence.files import EvidenceError, canonical, sha256
from evidence.report import EVIDENCE_FILES, checksum_text
from evidence.verification import verify_release
from test_evidence import info


class VerificationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tools_directory = tempfile.TemporaryDirectory()
        tools = Path(cls.tools_directory.name)
        cls.verifier = tools / "verify"
        cls.signer = tools / "sign-fixture"
        for source, output in [(RELEASE / "verify-ed25519.swift", cls.verifier),
                               (RELEASE / "tests/sign-fixture.swift", cls.signer)]:
            subprocess.run(["xcrun", "swiftc", "-O", str(source), "-o", str(output)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.tools_directory.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "release"
        self.root.mkdir()
        self.project = self.base / "project"
        resources = self.project / "Resources"
        resources.mkdir(parents=True)
        (resources / "QuilNodeReleaseSigning.cer").write_bytes(b"test public certificate")
        (resources / "Info.plist").write_bytes(plistlib.dumps(info()))
        self.dmg = self.root / "QuilNode-0.1.0-alpha.1.dmg"
        self.dmg.write_bytes(b"disposable archive fixture")
        signature = self.base / "archive.sig"
        self.public_key = self.sign(self.dmg, signature)
        self.feed_text = ('<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
                         '<channel><item><title>QuilNode 0.1.0-alpha.1</title>'
                         '<sparkle:version>111</sparkle:version>'
                         '<sparkle:shortVersionString>0.1.0-alpha.1</sparkle:shortVersionString>'
                         '<enclosure url="https://github.com/quilnode/quilnode/releases/download/'
                         'v0.1.0-alpha.1/QuilNode-0.1.0-alpha.1.dmg" '
                         f'length="{self.dmg.stat().st_size}" sparkle:edSignature="{signature.read_text().strip()}"/>'
                         '</item></channel></rss>\n')
        for name in EVIDENCE_FILES:
            (self.root / name).write_bytes(b"{}\n")
        self.write_feed(self.feed_text)
        self.report = {
            "schemaVersion": 1, "distributionProfile": "community-signed", "purpose": "release",
            "application": {"bundleIdentifier": "com.quilnode.app", "architecture": "arm64",
                            "version": "0.1.0", "releaseVersion": "0.1.0-alpha.1", "build": "111"},
            "source": {"tag": "v0.1.0-alpha.1", "signatureVerified": True, "commit": "a" * 40, "tree": "b" * 40},
            "signing": {"updatePublicKey": self.public_key,
                        "applicationCertificateSHA256": sha256(resources / "QuilNodeReleaseSigning.cer")},
            "artifacts": {},
        }
        self.seal()

    def sign(self, path, signature=None):
        arguments = [str(self.signer), str(path)]
        if signature:
            arguments.append(str(signature))
        return subprocess.check_output(arguments, text=True).strip()

    def write_feed(self, text):
        feed = self.root / "appcast.xml"
        feed.write_text(text)
        self.sign(feed)

    def seal(self):
        self.report["artifacts"] = {
            name: {"sha256": sha256(self.root / name), "size": (self.root / name).stat().st_size}
            for name in (*EVIDENCE_FILES, self.dmg.name)
        }
        self.sign_report()

    def sign_report(self):
        report = self.root / "release-report.json"
        report.write_bytes(canonical(self.report))
        self.sign(report, self.root / "release-report.sig")
        (self.root / "SHA256SUMS").write_text(checksum_text(self.root, self.report))

    def verify(self, rehearsal=False):
        return verify_release(self.project, self.root, self.verifier, self.public_key, rehearsal)

    def test_valid_signatures_and_exact_artifact_set_pass(self):
        _, version = self.verify()
        self.assertEqual(version["releaseVersion"], "0.1.0-alpha.1")

    def test_changed_archive_feed_inventory_report_and_signature_are_rejected(self):
        for name in (self.dmg.name, "appcast.xml", "dependencies.json", "release-report.json", "release-report.sig", "SHA256SUMS"):
            path = self.root / name
            original = path.read_bytes()
            path.write_bytes(original + b"tamper")
            with self.subTest(name=name), self.assertRaises((EvidenceError, ValueError)):
                self.verify()
            path.write_bytes(original)

    def test_recomputed_checksums_cannot_hide_archive_tampering(self):
        self.dmg.write_bytes(b"changed archive")
        self.seal()  # even a re-signed report cannot replace the archive's own signature
        with self.assertRaises(EvidenceError):
            self.verify()

    def test_rehearsal_is_never_mistaken_for_public_release(self):
        self.report["purpose"] = "rehearsal"
        self.report["source"]["signatureVerified"] = False
        self.write_feed(self.feed_text.replace("<item>", "<item><sparkle:channel>rehearsal</sparkle:channel>"))
        self.seal()
        with self.assertRaises(EvidenceError):
            self.verify()
        self.verify(rehearsal=True)

    def test_wrong_public_key_fails_before_report_trust(self):
        self.public_key = base64.b64encode(b"x" * 32).decode()
        with self.assertRaises(EvidenceError):
            self.verify()

    def test_signed_but_wrong_certificate_is_rejected(self):
        self.report["signing"]["applicationCertificateSHA256"] = "c" * 64
        self.sign_report()
        with self.assertRaises(EvidenceError):
            self.verify()

    def test_replayed_build_is_not_the_selected_candidate(self):
        self.report["application"]["build"] = "110"
        self.sign_report()
        with self.assertRaises(EvidenceError):
            self.verify()

    def test_signed_unexpected_paths_are_rejected_without_reading_them(self):
        self.report["artifacts"]["../outside"] = {"sha256": "a" * 64, "size": 1}
        (self.root / "release-report.json").write_bytes(canonical(self.report))
        self.sign(self.root / "release-report.json", self.root / "release-report.sig")
        with self.assertRaises(EvidenceError):
            self.verify()

    def test_symlinks_missing_assets_and_extra_files_are_rejected(self):
        original = (self.root / "dependencies.json").read_bytes()
        (self.root / "dependencies.json").unlink()
        outside = self.base / "outside"
        outside.write_bytes(original)
        (self.root / "dependencies.json").symlink_to(outside)
        with self.assertRaises((EvidenceError, OSError)):
            self.verify()
        (self.root / "dependencies.json").unlink()
        with self.assertRaises(EvidenceError):
            self.verify()
        (self.root / "dependencies.json").write_bytes(original)
        (self.root / "unexpected").write_bytes(b"extra")
        with self.assertRaises(EvidenceError):
            self.verify()

    def test_signed_feed_still_requires_exact_version_url_and_length(self):
        for text in (self.feed_text.replace("github.com", "example.invalid"),
                     self.feed_text.replace("<sparkle:version>111", "<sparkle:version>110"),
                     self.feed_text.replace(f'length="{self.dmg.stat().st_size}"', 'length="1"')):
            self.write_feed(text)
            self.seal()
            with self.subTest(text=text), self.assertRaises(EvidenceError):
                self.verify()


if __name__ == "__main__":
    unittest.main()
