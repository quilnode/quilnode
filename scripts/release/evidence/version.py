"""Keep the public release label separate from macOS/Sparkle version ordering."""

import re

from .files import require

NUMBER = r"(?:0|[1-9][0-9]*)"
NUMERIC_VERSION = rf"{NUMBER}\.{NUMBER}\.{NUMBER}"
PUBLIC_VERSION = rf"{NUMERIC_VERSION}(?:-(?:alpha|beta|rc)\.[1-9][0-9]*)?"


def release_version(info):
    version = info.get("CFBundleShortVersionString")
    build = info.get("CFBundleVersion")
    public = info.get("QuilNodeReleaseVersion")
    require(isinstance(version, str) and re.fullmatch(NUMERIC_VERSION, version),
            "Bundle short version must contain three numeric components")
    require(isinstance(build, str) and re.fullmatch(r"[1-9][0-9]*", build),
            "Bundle build must be a positive integer string")
    require(isinstance(public, str) and re.fullmatch(PUBLIC_VERSION, public),
            "Set QuilNodeReleaseVersion to the approved stable or alpha/beta/rc release label")
    require(public.split("-", 1)[0] == version,
            "Public release label does not match the numeric bundle version")
    return {"version": version, "build": build, "releaseVersion": public,
            "tag": "v" + public, "dmg": f"QuilNode-{public}.dmg"}
