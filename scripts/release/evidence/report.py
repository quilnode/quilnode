"""Assemble a signed-report payload without workstation names or raw logs."""

import datetime
from .bundle import inventory, plist
from .files import read_json, require, run, sha256, write_json
from .sbom import cyclonedx, spdx
from .source import verify_source
from .version import release_version

EVIDENCE_FILES = ("bundle-manifest.json", "dependencies.json", "sbom.cdx.json", "sbom.spdx.json", "appcast.xml")
REPORT_FILE = "release-report.json"
SIGNATURE_FILE = "release-report.sig"


def build_report(project, app, root, source, toolchain, gates, created=None, rehearsal=False):
    """Pure assembly after the caller establishes source and bundle trust."""
    created = created or datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    info = plist(app / "Contents/Info.plist")
    version = release_version(info)
    require(source["tag"] == version["tag"], "Tag and built application version differ")
    dmg_name = version["dmg"]
    digest = sha256(root / dmg_name)
    download_url = f"https://github.com/quilnode/quilnode/releases/download/{source['tag']}/{dmg_name}"
    dependencies, manifest = inventory(project, app)
    write_json(root / "bundle-manifest.json", manifest)
    write_json(root / "dependencies.json", dependencies)
    write_json(root / "sbom.cdx.json", cyclonedx(dependencies, digest, created))
    write_json(root / "sbom.spdx.json", spdx(dependencies, digest, created, download_url))
    report = {
        "schemaVersion": 1, "createdAt": created, "distributionProfile": "community-signed",
        "purpose": "rehearsal" if rehearsal else "release",
        "application": {"bundleIdentifier": info["CFBundleIdentifier"], "version": version["version"],
                        "releaseVersion": version["releaseVersion"],
                        "build": str(info["CFBundleVersion"]), "minimumSystemVersion": info["LSMinimumSystemVersion"],
                        "architecture": "arm64"},
        "source": source, "toolchain": toolchain,
        "signing": {"applicationCertificateSHA256": sha256(project / "Resources/QuilNodeReleaseSigning.cer"),
                    "updatePublicKey": info["SUPublicEDKey"], "algorithm": "Ed25519", "appleNotarized": False},
        "entitlements": plist(project / "Resources/QuilNode.entitlements"),
        "gates": gates,
        "qualification": {"cleanMachineMatrix": "not-attested-by-packager", "offlineRecovery": "not-attested-by-packager",
                          "independentSecurityReview": "not-attested-by-packager"},
        "artifacts": {name: {"sha256": sha256(root / name), "size": (root / name).stat().st_size}
                      for name in (*EVIDENCE_FILES, dmg_name)},
    }
    write_json(root / REPORT_FILE, report)
    return report


def generate(project, app, root, expected_source, rehearsal=False):
    version = release_version(plist(app / "Contents/Info.plist"))
    source = verify_source(project, version["releaseVersion"], rehearsal=rehearsal)
    require(source == expected_source, "Source changed during packaging")
    run([str(project / "scripts/release/audit-app-bundle.sh"), str(app)])
    run([str(project / "scripts/release/audit-metadata-privacy.sh"), "artifact", str(app)])
    toolchain = {
        "xcode": run(["xcodebuild", "-version"]),
        "swift": run(["xcrun", "swift", "--version"]),
        "sdkVersion": run(["xcrun", "--sdk", "macosx", "--show-sdk-version"]),
        "sdkBuild": run(["xcrun", "--sdk", "macosx", "--show-sdk-build-version"]),
        "macOSVersion": run(["sw_vers", "-productVersion"]),
        "macOSBuild": run(["sw_vers", "-buildVersion"]),
    }
    gates = {"signedSourceTag": "not-verified" if rehearsal else "passed",
             "sealedBundle": "passed", "bundleMetadataPrivacy": "passed",
             "reviewedLicensesAndDependencies": "passed"}
    return build_report(project, app, root, source, toolchain, gates, rehearsal=rehearsal)


def checksum_text(root, report):
    names = sorted([*report["artifacts"], REPORT_FILE, SIGNATURE_FILE])
    return "".join(f"{sha256(root / name)}  {name}\n" for name in names)


def checksums(root):
    report = read_json(root / REPORT_FILE)
    with (root / "SHA256SUMS").open("x") as stream:
        stream.write(checksum_text(root, report))
