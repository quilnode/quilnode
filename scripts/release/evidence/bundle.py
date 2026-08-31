"""Seal reviewed licenses and build inputs; inventory the delivered bundle."""

import plistlib
import re

from .files import read_json, read_regular, require, run, sha256, tree_manifest, write_json
from .version import release_version


def policy(project):
    document = read_json(project / "config/release/dependencies.json")
    require(document["schemaVersion"] == 1, "Unsupported dependency policy")
    components = {item["id"]: item for item in document["components"]}
    require(len(components) == len(document["components"]) == 3
            and set(components) == {"quilnode", "sparkle", "openssl"}, "Review dependency policy changes")
    pins = read_json(project / "Package.resolved")["pins"]
    require(len(pins) == 1 and pins[0]["identity"] == "sparkle", "Unreviewed Swift dependency")
    require(pins[0]["state"]["version"] == components["sparkle"]["version"]
            and pins[0]["state"]["revision"] == components["sparkle"]["revision"],
            "Sparkle dependency policy differs from the lockfile")
    for component in components.values():
        require(sha256(project / component["licenseSource"]) == component["licenseSHA256"],
                "Reviewed license bytes have changed")
    return document


def plist(path):
    return plistlib.loads(read_regular(path))


def prepare_bundle(project, app, openssl):
    document = policy(project)
    components = {item["id"]: item for item in document["components"]}
    openssl_policy = components["openssl"]
    version = run([str(openssl / "bin/openssl"), "version"]).split()[1]
    require(version == openssl_policy["version"], "Unreviewed OpenSSL toolchain")
    toolchain_policy = (project / "scripts/release/toolchain-policy.sh").read_text()
    for key, expected in [("VERSION", version), ("SHA256", openssl_policy["archiveSHA256"])]:
        require(f'QUILNODE_OPENSSL_{key}="{expected}"' in toolchain_policy,
                "OpenSSL dependency policy differs from the build policy")
    resources = app / "Contents/Resources"
    licenses = resources / "Licenses"
    licenses.mkdir()
    for component in components.values():
        (licenses / component["licenseFile"]).write_bytes(read_regular(project / component["licenseSource"]))
    (licenses / "NOTICE.txt").write_bytes(read_regular(project / "NOTICE.md"))
    verifier = app / "Contents/Helpers/QuilNodeReleaseVerifier"
    # Recorded at the link boundary, before codesigning changes the binary.
    write_json(resources / "BuildDependencies.json", {
        "schemaVersion": 1, "opensslVersion": version,
        "opensslStaticArchiveSHA256": sha256(openssl / "lib/libcrypto.a"),
        "opensslSourceArchiveSHA256": openssl_policy["archiveSHA256"],
        "linkage": "static", "binary": "Contents/Helpers/QuilNodeReleaseVerifier",
        "unsignedLinkedBinarySHA256": sha256(verifier),
    })


def inventory(project, app):
    reviewed = policy(project)
    info = plist(app / "Contents/Info.plist")
    require(info["CFBundleIdentifier"] == "com.quilnode.app", "Unexpected application identifier")
    version = release_version(info)
    receipt = read_json(app / "Contents/Resources/BuildDependencies.json")
    require(receipt["schemaVersion"] == 1 and receipt["linkage"] == "static"
            and receipt["binary"] == "Contents/Helpers/QuilNodeReleaseVerifier", "Invalid build receipt")
    framework = app / "Contents/Frameworks/Sparkle.framework"
    sparkle_info = plist((framework / "Resources/Info.plist").resolve(strict=True))
    manifest = tree_manifest(app)
    components = []
    for item in reviewed["components"]:
        component = {key: item[key] for key in ("id", "name", "supplier", "license", "source")}
        component["version"] = version["releaseVersion"] if item["id"] == "quilnode" else item["version"]
        license_path = "Contents/Resources/Licenses/" + item["licenseFile"]
        require(sha256(app / license_path) == item["licenseSHA256"], "Bundled license differs from reviewed bytes")
        component["licenseFile"] = license_path
        component["licenseSHA256"] = item["licenseSHA256"]
        if item["id"] == "sparkle":
            require(sparkle_info["CFBundleShortVersionString"] == item["version"], "Bundled Sparkle version mismatch")
            component["linkage"] = "embedded-framework"
            component["files"] = [entry["path"] for entry in manifest["entries"]
                                  if entry["type"] == "file" and entry["path"].startswith("Contents/Frameworks/Sparkle.framework/")]
        elif item["id"] == "openssl":
            require(receipt["opensslVersion"] == item["version"]
                    and receipt["opensslSourceArchiveSHA256"] == item["archiveSHA256"], "OpenSSL build receipt mismatch")
            for field in ("opensslStaticArchiveSHA256", "unsignedLinkedBinarySHA256"):
                require(re.fullmatch(r"[0-9a-f]{64}", receipt[field]), "Malformed link evidence")
            component["linkage"] = "static"
            component["files"] = [receipt["binary"]]
            component["staticArchiveSHA256"] = receipt["opensslStaticArchiveSHA256"]
            component["evidence"] = "Version and link inputs from the code-signed build receipt; final binary hash in bundle manifest."
        else:
            component["linkage"] = "application"
            component["files"] = [entry["path"] for entry in manifest["entries"]
                                  if entry["type"] == "file" and not entry["path"].startswith("Contents/Frameworks/")]
        if "archiveURL" in item:
            component.update({"upstreamArchive": item["archiveURL"], "upstreamArchiveSHA256": item["archiveSHA256"]})
        components.append(component)
    require(sha256(app / "Contents/Resources/Licenses/NOTICE.txt") == sha256(project / "NOTICE.md"), "Missing project notice")
    # Additional binary distributions must enter the reviewed policy before shipping.
    require({path.name for path in (app / "Contents/Frameworks").iterdir()} == {"Sparkle.framework"},
            "Unreviewed bundled framework")
    return {"schemaVersion": 1, "scope": reviewed["scope"], "components": components}, manifest
