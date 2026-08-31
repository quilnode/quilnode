#!/usr/bin/env python3
"""Small builder-side entry point for bundle inventory and public verification."""

import argparse
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

from evidence.bundle import inventory, plist, prepare_bundle
from evidence.files import EvidenceError, output_path, read_json, write_json
from evidence.report import checksums, generate
from evidence.source import verify_source
from evidence.verification import verify_bundle, verify_release
from evidence.version import release_version

PROJECT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    bundle = commands.add_parser("prepare-bundle")
    bundle.add_argument("app", type=Path)
    bundle.add_argument("openssl", type=Path)
    check = commands.add_parser("inventory")
    check.add_argument("app", type=Path)
    output = commands.add_parser("output-path")
    output.add_argument("path", type=Path)
    source = commands.add_parser("source")
    source.add_argument("output", type=Path)
    source.add_argument("--rehearsal", action="store_true")
    report = commands.add_parser("report")
    report.add_argument("app", type=Path)
    report.add_argument("root", type=Path)
    report.add_argument("source", type=Path)
    report.add_argument("--rehearsal", action="store_true")
    sums = commands.add_parser("checksums")
    sums.add_argument("root", type=Path)
    verify = commands.add_parser("verify")
    verify.add_argument("root", type=Path)
    verify.add_argument("verifier", type=Path)
    verify.add_argument("public_key")
    verify.add_argument("--rehearsal", action="store_true")
    delivered = commands.add_parser("verify-bundle")
    delivered.add_argument("app", type=Path)
    delivered.add_argument("root", type=Path)
    args = parser.parse_args()
    if args.command == "prepare-bundle":
        prepare_bundle(PROJECT, args.app, args.openssl)
    elif args.command == "inventory":
        inventory(PROJECT, args.app)
    elif args.command == "output-path":
        print(output_path(PROJECT, args.path))
    elif args.command == "source":
        version = release_version(plist(PROJECT / "Resources/Info.plist"))
        write_json(args.output, verify_source(PROJECT, version["releaseVersion"], rehearsal=args.rehearsal))
    elif args.command == "report":
        generate(PROJECT, args.app, args.root, read_json(args.source), rehearsal=args.rehearsal)
    elif args.command == "checksums":
        checksums(args.root)
    elif args.command == "verify":
        _, version = verify_release(PROJECT, args.root, args.verifier, args.public_key, args.rehearsal)
        print(version["dmg"])
    elif args.command == "verify-bundle":
        verify_bundle(PROJECT, args.app, args.root)


if __name__ == "__main__":
    try:
        main()
    except (EvidenceError, OSError, ValueError, KeyError, TypeError, ET.ParseError,
            subprocess.TimeoutExpired) as error:
        print(f"Release evidence failed: {error}", file=sys.stderr)
        sys.exit(1)
