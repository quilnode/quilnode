"""Bounded files, canonical evidence, and bundle-relative inventory paths."""

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess


class EvidenceError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise EvidenceError(message)


def run(arguments, cwd=None):
    result = subprocess.run(arguments, cwd=cwd, capture_output=True, timeout=120)
    require(result.returncode == 0, f"Required release tool failed: {Path(arguments[0]).name}")
    return result.stdout.decode("utf-8").strip()


def read_regular(path, maximum=16 * 1024 * 1024):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(stream.fileno())
        require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1,
                "Evidence must be a regular, singly linked file")
        require(before.st_size <= maximum, "Evidence exceeds its size limit")
        data = stream.read(maximum + 1)
        after = os.fstat(stream.fileno())
        require((before.st_size, before.st_mtime_ns, before.st_ctime_ns) ==
                (after.st_size, after.st_mtime_ns, after.st_ctime_ns), "Evidence changed while reading")
        require(len(data) == before.st_size, "Evidence length changed while reading")
        return data


def sha256(path):
    # Hash large archives without allocating an archive-sized buffer.
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1,
                "Hash input must be a regular, singly linked file")
        require(before.st_size <= 1024 * 1024 * 1024, "Hash input exceeds its size limit")
        digest = hashlib.sha256()
        count = 0
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            count += len(block)
            require(count <= before.st_size, "Hash input grew while reading")
            digest.update(block)
        after = os.fstat(fd)
        require((before.st_size, before.st_mtime_ns, before.st_ctime_ns) ==
                (after.st_size, after.st_mtime_ns, after.st_ctime_ns)
                and count == before.st_size, "Hash input changed while reading")
        return digest.hexdigest()


def canonical(value):
    return (json.dumps(value, ensure_ascii=True, indent=2, sort_keys=True) + "\n").encode()


def write_json(path, value):
    with Path(path).open("xb") as stream:
        stream.write(canonical(value))


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON property")
        result[key] = value
    return result


def read_json(path):
    return json.loads(read_regular(path), object_pairs_hook=unique_object)


def relative_path(value):
    require(isinstance(value, str), "Evidence path must be a string")
    path = PurePosixPath(value)
    require(isinstance(value, str) and value and not path.is_absolute()
            and ".." not in path.parts and str(path) == value
            and not any(c in value for c in "\n\r\\\x00"), "Unsafe evidence path")
    return path


def output_path(project, candidate):
    path = Path(candidate)
    require(path.is_absolute(), "Release output must be an absolute path")
    path = path.resolve()
    require(not path.is_relative_to(project.resolve()), "Release output must live outside the source repository")
    require(not path.exists(), "Refusing to overwrite an existing release directory")
    return path


def tree_manifest(root):
    root = Path(root).resolve(strict=True)
    entries = []
    for parent, directories, files in os.walk(root, followlinks=False):
        for name in sorted(directories + files):
            path = Path(parent) / name
            relative = path.relative_to(root).as_posix()
            relative_path(relative)
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                target = os.readlink(path)
                require(not os.path.isabs(target), "Absolute bundle link")
                require(path.resolve(strict=True).is_relative_to(root), "Bundle link escapes its root")
                entries.append({"path": relative, "type": "symlink", "target": target})
            elif stat.S_ISREG(mode):
                entries.append({"path": relative, "type": "file", "sha256": sha256(path),
                                "size": path.stat().st_size, "executable": bool(mode & 0o111)})
            else:
                require(stat.S_ISDIR(mode), "Special file in application bundle")
    return {"schemaVersion": 1, "entries": sorted(entries, key=lambda entry: entry["path"])}
