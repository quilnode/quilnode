#!/usr/bin/env python3
"""Exercise the real app updater against disposable, loopback-only fixtures.

This is a local integration gate, not a substitute for clean-Mac qualification.
It never targets QuilNode, its release keys, its preferences, or node data.
"""

import argparse
import contextlib
import functools
import hashlib
import http.server
import json
from pathlib import Path
import plistlib
import shutil
import socket
import subprocess
import tempfile
import threading
import uuid
from xml.sax.saxutils import escape


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()


def tree_digest(root):
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        if path.is_file():
            digest.update(str(path.relative_to(root)).encode())
            digest.update(path.read_bytes())
    return digest.hexdigest()


class FixtureServer(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        if self.path.startswith("/unavailable/"):
            self.send_error(503)
        elif self.path.startswith("/disconnected/"):
            self.send_response(200)
            self.send_header("Content-Length", "1000000")
            self.end_headers()
            self.wfile.write(b"incomplete archive")
            self.wfile.flush()
            self.connection.shutdown(socket.SHUT_RDWR)
            self.connection.close()
        else:
            super().do_GET()


@contextlib.contextmanager
def target_volume(case, bounded):
    if not bounded:
        yield case / "installed"
        return
    # Exhaust only a new 32-MB image, never the workstation filesystem.
    image = case / "bounded.dmg"
    mount = case / "bounded-volume"
    mount.mkdir()
    run("/usr/bin/hdiutil", "create", "-quiet", "-size", "32m", "-fs", "HFS+",
        "-volname", "QuilNode Update Fixture", str(image))
    run("/usr/bin/hdiutil", "attach", "-quiet", "-nobrowse", "-mountpoint", str(mount), str(image))
    try:
        yield mount
    finally:
        run("/usr/bin/hdiutil", "detach", "-quiet", str(mount))


def make_app(path, identifier, version, feed, public_key, executable, policy, large=False):
    contents = path / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    shutil.copy2(executable, contents / "MacOS/Fixture")
    info = {
        "CFBundleIdentifier": identifier,
        "CFBundleName": "Fixture",
        "CFBundleExecutable": "Fixture",
        "CFBundlePackageType": "APPL",
        "CFBundleVersion": str(version),
        "CFBundleShortVersionString": f"1.0.{version}",
        "SUFeedURL": feed,
        "SUPublicEDKey": public_key,
        "SUEnableAutomaticChecks": False,
        "SUAutomaticallyUpdate": False,
        "SUSendProfileInfo": False,
        "SUEnableSystemProfiling": False,
        # HTTP is allowed only for these disposable loopback test feeds.
        "NSAppTransportSecurity": {"NSAllowsLocalNetworking": True},
        **policy,
    }
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    if large:
        resources = contents / "Resources"
        resources.mkdir()
        # HFS+ cannot clone or sparsely install this 64-MB resource into 32 MB.
        (resources / "payload.bin").write_bytes(bytes(64 * 1024 * 1024))
    run("/usr/bin/codesign", "--force", "--sign", "-", str(path))


def appcast(version, url, signature, size, minimum="14.0"):
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
        '<channel><title>Disposable updater qualification</title><item>'
        f'<sparkle:version>{version}</sparkle:version>'
        f'<sparkle:shortVersionString>1.0.{version}</sparkle:shortVersionString>'
        f'<sparkle:minimumSystemVersion>{minimum}</sparkle:minimumSystemVersion>'
        f'<enclosure url="{escape(url)}" sparkle:edSignature="{signature}" '
        f'length="{size}" type="application/octet-stream"/>'
        '</item></channel></rss>\n'
    )


def qualify(args, root, base_url, public_key, policy, resources):
    # Every case has independent preferences, caches, target, and source bundle.
    cases = [
        ("current", "probe", "current"),
        ("replayed-feed", "probe", "current"),
        ("incompatible-os", "probe", "unavailable"),
        ("empty-feed", "probe", "unavailable"),
        ("feed-tampered", "install", "failed"),
        ("archive-tampered", "install", "failed"),
        ("bundle-tampered", "install", "failed"),
        ("feed-unavailable", "install", "failed"),
        ("download-disconnected", "install", "failed"),
        ("cancelled", "cancel", "updateAvailable"),
        ("valid-update", "install", "installing"),
        ("downgrade-payload", "install", "failed"),
        ("interrupted-and-retried", "interrupt", "installing"),
        ("disk-full", "install", "failed"),
    ]
    results = []
    for name, mode, expected_phase in cases:
        case = root / name
        case.mkdir()
        identifier = f"com.quilnode.qualification.fixture.{uuid.uuid4().hex}"
        volume = target_volume(case, name == "disk-full")
        # ExitStack always detaches the fixture image before temporary cleanup.
        target = resources.enter_context(volume) / "Fixture.app"
        candidate = case / "candidate/Fixture.app"
        feed_url = f"{base_url}/{name}/appcast.xml"
        if name == "feed-unavailable":
            feed_url = f"{base_url}/unavailable/appcast.xml"
        for path, version in [(target, 100), (candidate, 99 if name == "downgrade-payload" else 101)]:
            make_app(path, identifier, version, feed_url, public_key, args.executable, policy,
                     large=name == "disk-full" and path == candidate)
        if name == "bundle-tampered":
            plist = candidate / "Contents/Info.plist"
            info = plistlib.loads(plist.read_bytes())
            info["FixtureTampered"] = True
            plist.write_bytes(plistlib.dumps(info))
            check = subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(candidate)],
                                   capture_output=True)
            assert check.returncode != 0, "Tamper fixture must really invalidate code signing"
        archive = case / "update.zip"
        run("/usr/bin/ditto", "-c", "-k", "--keepParent", str(candidate), str(archive))
        signature_file = case / "signature.txt"
        run(str(args.signer), str(archive), str(signature_file))
        size = archive.stat().st_size
        if name == "archive-tampered":
            archive.write_bytes(b"X" + archive.read_bytes()[1:])
        url = f"{base_url}/{name}/update.zip"
        if name == "download-disconnected":
            url = f"{base_url}/disconnected/update.zip"
        version = 100 if name == "current" else 99 if name == "replayed-feed" else 101
        feed = case / "appcast.xml"
        feed.write_text(appcast(version, url, signature_file.read_text().strip(), size,
                               "99.0" if name == "incompatible-os" else "14.0"))
        if name == "empty-feed":
            feed.write_text('<?xml version="1.0"?><rss version="2.0"><channel><title>Fixture</title></channel></rss>\n')
        run(str(args.signer), str(feed))
        if name == "feed-tampered":
            feed.write_bytes(feed.read_bytes().replace(b"Disposable", b"Untrusted!"))
        before = tree_digest(target)
        process = subprocess.run([str(args.runner), str(target), mode],
                                 capture_output=True, text=True, timeout=60)
        interruption = None
        if name == "interrupted-and-retried":
            interruption = {"exitCode": process.returncode, "originalPreserved": tree_digest(target) == before}
            assert interruption == {"exitCode": 75, "originalPreserved": True}
            process = subprocess.run([str(args.runner), str(target), "install"],
                                     capture_output=True, text=True, timeout=60)
        (args.report / f"{name}.log").write_text(process.stdout + process.stderr)
        lines = [line for line in process.stdout.splitlines() if line.startswith("{")]
        evidence = json.loads(lines[-1]) if lines else {}
        with (target / "Contents/Info.plist").open("rb") as stream:
            installed = plistlib.load(stream)["CFBundleVersion"]
        final_phase = evidence.get("phases", [""])[-1]
        preserved = tree_digest(target) == before
        passed = (process.returncode == 0 and final_phase.startswith(expected_phase)
                  and evidence.get("lastAttemptRecorded") is True
                  and (installed == "101" if name in ("valid-update", "interrupted-and-retried") else preserved))
        if name not in ("valid-update", "interrupted-and-retried"):
            passed = passed and evidence.get("canCheck") is True
        # Reject failures at the wrong layer: a broken installer must not make
        # a signature or downgrade test look successful.
        required_cause = {"feed-tampered": 3002, "archive-tampered": 3002,
                          "bundle-tampered": 3002, "downgrade-payload": 4006,
                          "feed-unavailable": 2001, "download-disconnected": 2001}.get(name)
        if required_cause:
            passed = passed and any(item["domain"] == "SUSparkleErrorDomain"
                                    and item["code"] == required_cause
                                    for item in evidence.get("errorChain", []))
        if name == "disk-full":
            passed = passed and "disk space" in final_phase
        result = {"case": name, "passed": bool(passed), "exitCode": process.returncode,
                  "installedBuild": installed, "originalPreserved": preserved, **evidence}
        if interruption:
            result["interruption"] = interruption
        results.append(result)
        print(f"{'PASS' if passed else 'FAIL'}: {name}", flush=True)
        (args.report / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return all(item["passed"] for item in results)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("runner", "signer", "executable", "info", "report"):
        parser.add_argument(f"--{name}", required=True, type=Path)
    args = parser.parse_args()
    args.report.mkdir(parents=True, exist_ok=True)
    with args.info.open("rb") as stream:
        info = plistlib.load(stream)
    policy = {key: info[key] for key in (
        "SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction", "SUSignedFeedFailureExpirationInterval",
    ) if key in info}
    if policy.get("SURequireSignedFeed") is not True or policy.get("SUVerifyUpdateBeforeExtraction") is not True:
        raise SystemExit("Production updater trust settings are missing")
    with tempfile.TemporaryDirectory(prefix="quilnode-update-lab-") as temporary, contextlib.ExitStack() as resources:
        root = Path(temporary).resolve()
        probe = root / "test-key.txt"
        probe.write_text("Disposable fixture")
        public_key = run(str(args.signer), str(probe), str(root / "test-key.sig"))
        driver = root / "driver/Fixture.app"
        make_app(driver, f"com.quilnode.qualification.fixture.{uuid.uuid4().hex}", 100,
                 "http://127.0.0.1/unused", public_key, args.runner, policy)
        args.runner = driver / "Contents/MacOS/Fixture"
        handler = functools.partial(FixtureServer, directory=str(root))
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            passed = qualify(args, root, f"http://127.0.0.1:{server.server_port}", public_key, policy, resources)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
