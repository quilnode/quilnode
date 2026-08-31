"""Tag tests occur only in a disposable repository with disposable SSH keys."""

from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from evidence.files import EvidenceError
from evidence.source import verify_source


class SourceTests(unittest.TestCase):
    def setUp(self):
        # Release preflight supplies real signer settings. Disposable keys must
        # never depend on or read that trust list; restore it after each test.
        environment = patch.dict(os.environ)
        environment.start()
        self.addCleanup(environment.stop)
        for name in ("QUILNODE_RELEASE_TAG_SIGNER", "QUILNODE_RELEASE_TAG_ALLOWED_SIGNERS"):
            os.environ.pop(name, None)
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release-test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        (self.repo / "fixture").write_text("disposable release test")
        self.git("add", "fixture")
        self.git("commit", "-qm", "Fixture")
        self.key = self.root / "signing-key"
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", "release-test", "-f", str(self.key)], check=True)
        self.fingerprint = subprocess.check_output(["ssh-keygen", "-lf", str(self.key) + ".pub"], text=True).split()[1]
        allowed = self.root / "allowed-signers"
        allowed.write_text("release-test " + Path(str(self.key) + ".pub").read_text())
        self.git("config", "gpg.format", "ssh")
        self.git("config", "user.signingkey", str(self.key))
        self.git("config", "gpg.ssh.allowedSignersFile", str(allowed))
        self.allowed_signers = allowed

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, stderr=subprocess.PIPE, text=True).strip()

    def test_signed_alpha_tag_and_fingerprint_are_verified(self):
        self.git("tag", "-s", "v0.1.0-alpha.1", "-m", "Disposable candidate")
        source = verify_source(self.repo, "0.1.0-alpha.1", self.fingerprint)
        self.assertTrue(source["signatureVerified"])
        self.assertEqual(source["commit"], self.git("rev-parse", "HEAD"))
        with self.assertRaises(EvidenceError):
            verify_source(self.repo, "0.1.0-alpha.1", "SHA256:" + "A" * 43)

    def test_unsigned_tag_is_not_a_release(self):
        self.git("tag", "-a", "v0.1.0-alpha.1", "-m", "Unsigned")
        with self.assertRaises(EvidenceError):
            verify_source(self.repo, "0.1.0-alpha.1", self.fingerprint)

    def test_release_environment_selects_the_exact_signer_and_trust_list(self):
        self.git("tag", "-s", "v0.1.0-alpha.1", "-m", "Disposable candidate")
        empty = self.root / "empty-signers"
        empty.write_text("")
        self.git("config", "gpg.ssh.allowedSignersFile", str(empty))
        with patch.dict(os.environ, {
            "QUILNODE_RELEASE_TAG_SIGNER": self.fingerprint,
            "QUILNODE_RELEASE_TAG_ALLOWED_SIGNERS": str(self.allowed_signers),
        }):
            self.assertTrue(verify_source(self.repo, "0.1.0-alpha.1")["signatureVerified"])
            os.environ["QUILNODE_RELEASE_TAG_ALLOWED_SIGNERS"] = str(empty)
            with self.assertRaises(EvidenceError):
                verify_source(self.repo, "0.1.0-alpha.1")

    def test_tag_must_point_to_head(self):
        self.git("tag", "-s", "v0.1.0-alpha.1", "-m", "Old")
        self.git("commit", "--allow-empty", "-qm", "Later")
        with self.assertRaises(EvidenceError):
            verify_source(self.repo, "0.1.0-alpha.1", self.fingerprint)

    def test_rehearsal_is_explicit_and_still_requires_clean_source(self):
        source = verify_source(self.repo, "0.1.0-alpha.1", rehearsal=True)
        self.assertFalse(source["signatureVerified"])
        self.assertIsNone(source["tagObject"])
        (self.repo / "fixture").write_text("uncommitted change")
        with self.assertRaises(EvidenceError):
            verify_source(self.repo, "0.1.0-alpha.1", rehearsal=True)


if __name__ == "__main__":
    unittest.main()
