#!/usr/bin/env python3
"""Read validated release fields, or label a generated appcast before signing."""

import argparse
from pathlib import Path
import plistlib
import sys
import xml.etree.ElementTree as ET

from evidence.files import EvidenceError, read_regular, require
from evidence.version import release_version

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def label_appcast(path, version, rehearsal=False):
    # Only the locally generated, single-candidate feed is accepted here. The
    # packager must sign the resulting bytes; this function never signs content.
    raw = read_regular(path, maximum=2 * 1024 * 1024)
    require(b"<!DOCTYPE" not in raw and b"<!ENTITY" not in raw, "Unexpected XML declaration")
    root = ET.fromstring(raw)
    items = root.findall("./channel/item")
    require(root.tag == "rss" and len(items) == 1, "Expected one generated release item")
    item = items[0]
    builds = item.findall(f"{{{SPARKLE}}}version")
    require(len(builds) == 1 and builds[0].text == version["build"], "Appcast build does not match bundle")
    enclosures = item.findall("enclosure")
    expected = f"https://github.com/quilnode/quilnode/releases/download/{version['tag']}/{version['dmg']}"
    require(len(enclosures) == 1 and enclosures[0].get("url") == expected, "Appcast asset does not match release")
    for tag, value in [("title", "QuilNode " + version["releaseVersion"]),
                       (f"{{{SPARKLE}}}shortVersionString", version["releaseVersion"])]:
        nodes = item.findall(tag)
        require(len(nodes) == 1, "Missing or duplicate appcast version label")
        nodes[0].text = value
    require(not item.findall(f"{{{SPARKLE}}}channel"), "Unexpected preconfigured feed channel")
    if rehearsal:
        # The app's updater never opts into this channel. A copied test feed
        # therefore cannot offer the rehearsal as a normal application update.
        ET.SubElement(item, f"{{{SPARKLE}}}channel").text = "rehearsal"
        item.find("title").text += " — Local rehearsal"
    ET.register_namespace("sparkle", SPARKLE)
    # Serialization deliberately removes any old whole-feed signature comment.
    # The next packaging step signs the final bytes, including these labels.
    Path(path).write_bytes(ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plist", type=Path)
    parser.add_argument("field", choices=["version", "build", "releaseVersion", "tag", "dmg", "validate", "label-feed"])
    parser.add_argument("--feed", type=Path)
    parser.add_argument("--rehearsal", action="store_true")
    args = parser.parse_args()
    version = release_version(plistlib.loads(read_regular(args.plist)))
    if args.field == "label-feed":
        require(args.feed is not None, "Supply --feed for appcast labeling")
        label_appcast(args.feed, version, args.rehearsal)
    elif args.field != "validate":
        print(version[args.field])


if __name__ == "__main__":
    try:
        main()
    except (EvidenceError, OSError, ValueError, ET.ParseError, plistlib.InvalidFileException) as error:
        print(f"Release version validation failed: {error}", file=sys.stderr)
        sys.exit(1)
