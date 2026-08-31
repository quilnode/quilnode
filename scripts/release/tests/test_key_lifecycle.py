"""Signing scratch files are removed even when a callback fails."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest

COMMON = Path(__file__).resolve().parents[1] / "release-common.sh"


class SigningKeyLifecycleTests(unittest.TestCase):
    def test_failed_signing_callback_removes_the_temporary_key(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            password = root / "password"
            password.write_text("disposable-test-passphrase")
            plaintext = root / "fixture"
            plaintext.write_text("disposable-signing-fixture")
            encrypted = root / "fixture.enc"
            subprocess.run(["openssl", "enc", "-aes-256-cbc", "-pbkdf2", "-iter", "600000",
                            "-in", str(plaintext), "-out", str(encrypted), "-pass", "file:" + str(password)], check=True)
            record = root / "scratch-path"
            script = ('set -euo pipefail\nsource "$1"\n'
                      'fail_signing() { test -s "$1"; printf "%s" "$1" > "$TEST_SCRATCH_RECORD"; return 23; }\n'
                      'with_decrypted_update_key fail_signing\n')
            environment = dict(os.environ, QUILNODE_UPDATE_KEY_PASSWORD_FILE=str(password),
                               QUILNODE_ENCRYPTED_UPDATE_KEY=str(encrypted), TEST_SCRATCH_RECORD=str(record))
            result = subprocess.run(["bash", "-c", script, "test-key-cleanup", str(COMMON)], env=environment,
                                    capture_output=True)
            self.assertEqual(result.returncode, 23)
            self.assertFalse(Path(record.read_text()).exists())
            self.assertFalse(Path(record.read_text()).parent.exists())
            password.write_text("incorrect-test-passphrase")
            record.unlink()
            result = subprocess.run(["bash", "-c", script, "test-key-cleanup", str(COMMON)], env=environment,
                                    capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(record.exists(), "Failed decryption must not invoke the signer")


if __name__ == "__main__":
    unittest.main()
