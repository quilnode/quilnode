"""Verify an exact signed source tag against a separately selected signer."""

import os
import re
import subprocess

from .files import require, run
from .version import PUBLIC_VERSION


def verify_source(project, version, expected_signer=None, rehearsal=False):
    require(re.fullmatch(PUBLIC_VERSION, version), "Expected a valid public release version")
    require(not run(["git", "status", "--porcelain", "--untracked-files=all"], project),
            "Release requires clean, committed source; no dirty-tree bypass is supported")
    tag = "v" + version
    commit = run(["git", "rev-parse", "HEAD"], project)
    tree = run(["git", "rev-parse", "HEAD^{tree}"], project)
    if rehearsal:
        return {"tag": tag, "tagObject": None, "commit": commit, "tree": tree,
                "signatureVerified": False, "signerFingerprint": None}
    expected_signer = expected_signer or os.environ.get("QUILNODE_RELEASE_TAG_SIGNER", "")
    require(re.fullmatch(r"(?:SHA256:[A-Za-z0-9+/]{43}|[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})",
                         expected_signer),
            "Set QUILNODE_RELEASE_TAG_SIGNER to the independently approved signing-key fingerprint")
    ref = "refs/tags/" + tag
    require(run(["git", "cat-file", "-t", ref], project) == "tag", "Release tag must be annotated")
    require(run(["git", "rev-parse", ref + "^{commit}"], project) == commit,
            "Release tag does not point to HEAD")
    command = ["git", "-c", "gpg.minTrustLevel=fully"]
    allowed_signers = os.environ.get("QUILNODE_RELEASE_TAG_ALLOWED_SIGNERS")
    if allowed_signers:
        command += ["-c", "gpg.ssh.allowedSignersFile=" + allowed_signers]
    result = subprocess.run(command + ["verify-tag", "--raw", ref], cwd=project,
                            capture_output=True, timeout=30)
    require(result.returncode == 0, "Release tag signature is invalid or its key is not trusted")
    diagnostic = result.stderr.decode("utf-8", errors="replace")
    if expected_signer.startswith("SHA256:"):
        fingerprints = re.findall(r"\bSHA256:[A-Za-z0-9+/]{43}(?=\s|$)", diagnostic)
    else:
        fingerprints = []
        for line in diagnostic.splitlines():
            if line.startswith("[GNUPG:] VALIDSIG "):
                fields = line.split()
                fingerprints.extend([fields[2], fields[-1]])
        expected_signer = expected_signer.upper()
    require(expected_signer in fingerprints, "Release tag was signed by a different key")
    return {"tag": tag, "tagObject": run(["git", "rev-parse", ref], project),
            "commit": commit, "tree": tree,
            "signatureVerified": True, "signerFingerprint": expected_signer}
