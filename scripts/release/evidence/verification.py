"""Verify public release evidence before mounting any delivered disk image."""

import base64
import re
import xml.etree.ElementTree as ET

from .bundle import inventory, plist
from .files import read_json, read_regular, require, run, sha256
from .report import EVIDENCE_FILES, REPORT_FILE, SIGNATURE_FILE, checksum_text
from .version import release_version

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def signature(path):
    value = read_regular(path, maximum=128).decode("ascii").strip()
    require(re.fullmatch(r"[A-Za-z0-9+/]{86}==", value), "Invalid detached signature")
    require(len(base64.b64decode(value, validate=True)) == 64, "Invalid signature length")
    return value


def verify_feed(root, version, verifier, public_key, rehearsal=False):
    feed = root / "appcast.xml"
    run([str(verifier), "feed", public_key, str(feed)])
    raw = read_regular(feed, maximum=2 * 1024 * 1024)
    require(b"<!DOCTYPE" not in raw and b"<!ENTITY" not in raw, "Unexpected XML declaration")
    xml = ET.fromstring(raw)
    items = xml.findall("./channel/item")
    require(xml.tag == "rss" and len(items) == 1, "Expected one release item")
    item = items[0]
    channels = item.findall(f"{{{SPARKLE}}}channel")
    require((len(channels) == 1 and channels[0].text == "rehearsal") if rehearsal else not channels,
            "Feed channel does not match the release purpose")
    for name, value in [("version", version["build"]), ("shortVersionString", version["releaseVersion"])]:
        matches = item.findall(f"{{{SPARKLE}}}{name}")
        require(len(matches) == 1 and matches[0].text == value, "Feed version differs from report")
    enclosures = item.findall("enclosure")
    require(len(enclosures) == 1, "Expected one archive")
    enclosure = enclosures[0]
    expected_url = f"https://github.com/quilnode/quilnode/releases/download/{version['tag']}/{version['dmg']}"
    require(enclosure.get("url") == expected_url, "Feed points outside the exact release")
    archive = root / version["dmg"]
    require(enclosure.get("length") == str(archive.stat().st_size), "Feed archive size mismatch")
    signature_value = enclosure.get(f"{{{SPARKLE}}}edSignature", "")
    run([str(verifier), "file", public_key, str(archive), signature_value])


def verify_release(project, root, verifier, public_key, rehearsal=False):
    # Trust comes from the independently selected public key, never a key or
    # a list of executable commands supplied by the downloaded report.
    run([str(verifier), "file", public_key, str(root / REPORT_FILE), signature(root / SIGNATURE_FILE)])
    report = read_json(root / REPORT_FILE)
    require(report["schemaVersion"] == 1 and report["distributionProfile"] == "community-signed",
            "Unsupported release report")
    require(report["purpose"] == ("rehearsal" if rehearsal else "release"),
            "Rehearsal artifacts cannot be verified as a public release")
    app = report["application"]
    version = release_version({"CFBundleShortVersionString": app["version"],
                               "CFBundleVersion": app["build"], "QuilNodeReleaseVersion": app["releaseVersion"]})
    require(version == release_version(plist(project / "Resources/Info.plist")),
            "Artifact does not match the version and build selected by this source checkout")
    require(app["bundleIdentifier"] == "com.quilnode.app" and app["architecture"] == "arm64",
            "Unexpected application identity or architecture")
    require(report["source"]["tag"] == version["tag"], "Report tag and version differ")
    require(report["source"]["signatureVerified"] is (not rehearsal), "Unexpected source signature state")
    for key in ("commit", "tree"):
        require(re.fullmatch(r"[0-9a-f]{40}", report["source"][key]), "Invalid source identity")
    require(report["signing"]["updatePublicKey"] == public_key, "Update identity mismatch")
    require(report["signing"]["applicationCertificateSHA256"] ==
            sha256(project / "Resources/QuilNodeReleaseSigning.cer"), "Application certificate mismatch")
    expected = set(EVIDENCE_FILES) | {version["dmg"]}
    require(set(report["artifacts"]) == expected, "Release evidence is incomplete or contains extra paths")
    require({path.name for path in root.iterdir()} == expected | {REPORT_FILE, SIGNATURE_FILE, "SHA256SUMS"},
            "Release directory contains missing or unexpected entries")
    for name, entry in report["artifacts"].items():
        require(entry["sha256"] == sha256(root / name) and entry["size"] == (root / name).stat().st_size,
                "Release artifact differs from signed report: " + name)
    require(read_regular(root / "SHA256SUMS").decode("ascii") == checksum_text(root, report),
            "Checksums differ from the signed artifact inventory")
    verify_feed(root, version, verifier, public_key, rehearsal)
    return report, version


def verify_bundle(project, app, root):
    report = read_json(root / REPORT_FILE)
    info = plist(app / "Contents/Info.plist")
    version = release_version(info)
    for name in ("version", "releaseVersion", "build"):
        require(version[name] == report["application"][name], "Delivered bundle version mismatch")
    require(info["SUPublicEDKey"] == report["signing"]["updatePublicKey"], "Delivered update key mismatch")
    dependencies, manifest = inventory(project, app)
    require(dependencies == read_json(root / "dependencies.json"), "Delivered dependencies differ from inventory")
    require(manifest == read_json(root / "bundle-manifest.json"), "Delivered bundle differs from manifest")
