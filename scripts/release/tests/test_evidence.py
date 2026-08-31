"""Fast release invariants with disposable files, never operator state."""

import hashlib
import importlib.util
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch

RELEASE = Path(__file__).resolve().parents[1]
PROJECT = RELEASE.parents[1]
sys.path.insert(0, str(RELEASE))

from evidence.bundle import inventory, policy, prepare_bundle
from evidence.files import EvidenceError, output_path, read_json, read_regular, relative_path, sha256, tree_manifest
from evidence.sbom import cyclonedx, spdx
from evidence.version import release_version


def info(label="0.1.0-alpha.1"):
    return {"CFBundleIdentifier": "com.quilnode.app", "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "111", "QuilNodeReleaseVersion": label}


class VersionTests(unittest.TestCase):
    def test_alpha_and_stable_share_numeric_ordering(self):
        for label in ("0.1.0", "0.1.0-alpha.1", "0.1.0-beta.2", "0.1.0-rc.3"):
            version = release_version(info(label))
            self.assertEqual(version["build"], "111")
            self.assertEqual(version["tag"], "v" + label)
            self.assertEqual(version["dmg"], "QuilNode-" + label + ".dmg")

    def test_invalid_labels_and_mismatches_fail(self):
        for value in (None, 1, "0.1.0-alpha", "0.1.0-alpha.0", "0.1.0-alpha.01",
                      "0.2.0-alpha.1", "../0.1.0", "0.1.0\n", "0.1.0+local", "v0.1.0"):
            with self.subTest(value=value), self.assertRaises(EvidenceError):
                release_version(info(value))

    def test_build_and_numeric_version_are_strict(self):
        for field, values in [("CFBundleVersion", ("0", "01", 111, "111.1", "-1")),
                              ("CFBundleShortVersionString", ("0.1", "00.1.0", "0.1.0-alpha.1"))]:
            for value in values:
                candidate = info()
                candidate[field] = value
                with self.subTest(field=field, value=value), self.assertRaises(EvidenceError):
                    release_version(candidate)

    def test_feed_labeling_checks_the_build_and_asset(self):
        spec = importlib.util.spec_from_file_location("release_version_cli", RELEASE / "release-version.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        version = release_version(info())
        url = f"https://github.com/quilnode/quilnode/releases/download/{version['tag']}/{version['dmg']}"
        text = ('<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>'
                '<title>Old</title><sparkle:version>111</sparkle:version>'
                '<sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>'
                f'<enclosure url="{url}"/></item></channel></rss>')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "appcast.xml"
            path.write_text(text)
            module.label_appcast(path, version)
            self.assertIn("0.1.0-alpha.1", path.read_text())
            path.write_text(text.replace("<sparkle:version>111", "<sparkle:version>110"))
            with self.assertRaises(EvidenceError):
                module.label_appcast(path, version)


class FileTests(unittest.TestCase):
    def test_output_paths_resolve_aliases_and_cannot_enter_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            project = root / "repo"
            project.mkdir()
            alias = root / "alias"
            alias.symlink_to(project)
            for path in (project / "output", alias / "output", root / "alias/../repo/output", root):
                with self.subTest(path=path), self.assertRaises(EvidenceError):
                    output_path(project, path)
            self.assertEqual(output_path(project, root / "release"), root / "release")

    def test_paths_cannot_escape_or_normalize_silently(self):
        for value in (None, "/tmp/data", "../data", "a/../data", "./data", "a//data", "a\\data", "a\nb"):
            with self.subTest(value=value), self.assertRaises(EvidenceError):
                relative_path(value)

    def test_duplicate_json_properties_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.json"
            path.write_text('{"a": 1, "a": 2}')
            with self.assertRaises(EvidenceError):
                read_json(path)

    def test_streamed_hash_matches_standard_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "archive"
            data = b"test data" * 300_000
            path.write_bytes(data)
            self.assertEqual(sha256(path), hashlib.sha256(data).hexdigest())
            with self.assertRaises(EvidenceError):
                read_regular(path, maximum=10)

    def test_links_and_special_files_are_rejected(self):
        import os
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / "original"
            original.write_bytes(b"data")
            alias = root / "alias"
            alias.symlink_to(original)
            for read in (sha256, read_regular):
                with self.assertRaises((OSError, EvidenceError)):
                    read(alias)
            alias.unlink()
            os.link(original, alias)
            with self.assertRaises(EvidenceError):
                sha256(alias)
            fifo = root / "fifo"
            os.mkfifo(fifo)
            with self.assertRaises(EvidenceError):
                sha256(fifo)

    def test_bundle_manifest_accepts_only_contained_relative_links(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "file").write_bytes(b"data")
            (root / "link").symlink_to("file")
            self.assertEqual(len(tree_manifest(root)["entries"]), 2)
            (root / "link").unlink()
            (root / "link").symlink_to("/Applications")
            with self.assertRaises(EvidenceError):
                tree_manifest(root)


class BundleTests(unittest.TestCase):
    def test_policy_matches_exact_dependency_and_license_inputs(self):
        self.assertEqual(len(policy(PROJECT)["components"]), 3)

    def test_inventory_includes_the_linked_library_without_duplicate_frameworks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / "QuilNode.app"
            resources = app / "Contents/Resources"
            resources.mkdir(parents=True)
            helpers = app / "Contents/Helpers"
            helpers.mkdir()
            (helpers / "QuilNodeReleaseVerifier").write_bytes(b"fixture verifier")
            (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info()))
            framework = app / "Contents/Frameworks/Sparkle.framework/Resources"
            framework.mkdir(parents=True)
            (framework / "Info.plist").write_bytes(plistlib.dumps({"CFBundleShortVersionString": "2.9.6"}))
            openssl = root / "toolchain"
            (openssl / "lib").mkdir(parents=True)
            (openssl / "lib/libcrypto.a").write_bytes(b"fixture static archive")
            with patch("evidence.bundle.run", return_value="OpenSSL 3.5.8"):
                prepare_bundle(PROJECT, app, openssl)
            dependencies, manifest = inventory(PROJECT, app)
            self.assertEqual([item["id"] for item in dependencies["components"]], ["quilnode", "sparkle", "openssl"])
            self.assertEqual(dependencies["components"][0]["version"], "0.1.0-alpha.1")
            self.assertEqual(dependencies["components"][2]["linkage"], "static")
            self.assertGreater(len(manifest["entries"]), 5)
            cdx = cyclonedx(dependencies, "a" * 64, "2026-01-01T00:00:00Z")
            self.assertEqual(len(cdx["components"]), 2)
            self.assertEqual(cdx["metadata"]["component"]["version"], "0.1.0-alpha.1")
            spdx_doc = spdx(dependencies, "a" * 64, "2026-01-01T00:00:00Z", "https://example.invalid/app.dmg")
            self.assertEqual(spdx_doc["dataLicense"], "CC0-1.0")
            self.assertEqual(len(spdx_doc["packages"]), 3)
            (resources / "Licenses/OpenSSL.txt").write_text("changed")
            with self.assertRaises(EvidenceError):
                inventory(PROJECT, app)


if __name__ == "__main__":
    unittest.main()
