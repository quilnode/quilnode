"""Exercise public verification against modified copies of the real candidate."""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

RELEASE = Path(__file__).resolve().parents[1]
PROJECT = RELEASE.parents[1]
sys.path.insert(0, str(RELEASE))
from evidence.files import EvidenceError
from evidence.verification import verify_release

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("root", type=Path)
parser.add_argument("--rehearsal", action="store_true")
args = parser.parse_args()
# Read only the checked-in public key, not any private signing capability.
import plistlib
with (PROJECT / "Resources/Info.plist").open("rb") as stream:
    public_key = plistlib.load(stream)["SUPublicEDKey"]

with tempfile.TemporaryDirectory(prefix="quilnode-tamper-") as directory:
    temporary = Path(directory)
    verifier = temporary / "verify"
    subprocess.run(["xcrun", "swiftc", "-O", str(RELEASE / "verify-ed25519.swift"), "-o", str(verifier)], check=True)
    _, version = verify_release(PROJECT, args.root, verifier, public_key, args.rehearsal)
    candidate = temporary / "candidate"
    shutil.copytree(args.root, candidate, symlinks=True)
    for name in (version["dmg"], "appcast.xml", "release-report.json", "release-report.sig", "dependencies.json", "SHA256SUMS"):
        path = candidate / name
        with path.open("ab") as stream:
            stream.write(b"tamper")
        try:
            verify_release(PROJECT, candidate, verifier, public_key, args.rehearsal)
        except (EvidenceError, OSError, ValueError):
            print("PASS: modified " + name + " rejected before disk mounting")
        else:
            raise SystemExit("FAIL: modified release data was accepted")
        shutil.copyfile(args.root / name, path)
