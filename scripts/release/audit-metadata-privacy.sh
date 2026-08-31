#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
shift || true
if [[ "$mode" != "repository" && "$mode" != "artifact" ]] || (( $# == 0 )); then
    echo "Usage: $0 repository|artifact <path> [path ...]" >&2
    exit 64
fi

for required in file strings rg sips xattr otool; do
    command -v "$required" >/dev/null 2>&1 || {
        echo "Missing metadata-audit dependency: $required" >&2
        exit 1
    }
done

failures=0
fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

# These values are intentionally discovered at audit time and never printed.
# They identify the build workstation and never belong in release artifacts.
sensitive_literals=()
append_sensitive_literal() {
    local value="$1"
    [[ ${#value} -ge 4 ]] || return 0
    sensitive_literals+=("$value")
}

append_sensitive_literal "${HOME:-}"
append_sensitive_literal "$(id -un 2>/dev/null || true)"
for host_key in ComputerName LocalHostName HostName; do
    append_sensitive_literal "$(scutil --get "$host_key" 2>/dev/null || true)"
done
if [[ -n "${QUILNODE_METADATA_DENY_FILE:-}" && -r "$QUILNODE_METADATA_DENY_FILE" ]]; then
    while IFS= read -r literal || [[ -n "$literal" ]]; do
        append_sensitive_literal "$literal"
    done < "$QUILNODE_METADATA_DENY_FILE"
fi

scan_media_metadata() {
    local candidate="$1"
    case "$candidate" in
        *.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG|*.tif|*.TIF|*.tiff|*.TIFF|*.heic|*.HEIC|*.icns|*.ICNS)
            if sips -g all "$candidate" 2>/dev/null | tail -n +2 | rg -qi \
                '^[[:space:]]+(artist|author|camera|make|model|software|creation|datetime|gps|latitude|longitude|comment|description|copyright):'; then
                fail "embedded creator, device, location, or timestamp metadata: $candidate"
            fi
            ;;
    esac
}

scan_file_content() {
    local candidate="$1"
    local relative="$2"
    local extracted
    extracted="$(LC_ALL=C strings -a "$candidate" 2>/dev/null || true)"

    local literal
    for literal in "${sensitive_literals[@]}"; do
        if printf '%s\n' "$extracted" | rg -q --fixed-strings "$literal"; then
            fail "build-machine identity or path in $relative"
            break
        fi
    done

    if [[ "$mode" == "artifact" ]] && printf '%s\n' "$extracted" | rg -q \
        '(/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|/private/var/folders/[A-Za-z0-9._/-]+|file:///Users/)'; then
        fail "concrete user-home or temporary build path in $relative"
    fi

    if file "$candidate" | rg -q 'Mach-O'; then
        if otool -l "$candidate" 2>/dev/null | rg -q 'segname __DWARF|sectname __debug_'; then
            fail "embedded DWARF debug section in $relative"
        fi
    fi
    scan_media_metadata "$candidate"
}

scan_target() {
    local target="$1"
    [[ -e "$target" ]] || {
        fail "metadata-audit target does not exist: $target"
        return
    }
    local root
    root="$(cd "$target" 2>/dev/null && pwd || true)"
    if [[ -z "$root" ]]; then
        root="$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
    fi

    if [[ "$mode" == "artifact" ]]; then
        while IFS= read -r -d '' entry; do
            while IFS= read -r attribute; do
                [[ -n "$attribute" ]] || continue
                # macOS can attach this platform provenance marker to files
                # created by a sandboxed builder, even after an explicit xattr
                # removal. It contains no operator-selected name or path. Every
                # other attribute—including quarantine, Finder metadata,
                # resource forks, download origins, MACL data, and custom
                # metadata—is rejected.
                if [[ "$attribute" != "com.apple.provenance" ]]; then
                    fail "privacy-bearing extended attribute on distributable entry: ${entry#"$root"/} ($attribute)"
                fi
            done < <(xattr -s "$entry" 2>/dev/null || true)
            case "$(basename "$entry")" in
                *.dSYM|*.bcsymbolmap|*.swiftmodule|*.swiftdoc|*.dia|*.dwarf)
                    fail "debug or compiler metadata file in distributable: ${entry#"$root"/}"
                    ;;
            esac
        done < <(find "$target" -print0)
    fi

    while IFS= read -r -d '' candidate; do
        scan_file_content "$candidate" "${candidate#"$root"/}"
    done < <(
        if [[ "$mode" == "repository" ]]; then
            find "$target" \
                \( -path '*/.git' -o -path '*/.build' -o -path '*/.cache' -o \
                   -path '*/.swiftpm' -o -path '*/Audit' -o -path '*/dist' -o \
                   -path '*/output' -o -path '*/tmp' -o -path '*/QuilNode.xcodeproj' \) \
                -prune -o -type f -print0
        else
            find "$target" -type f -print0
        fi
    )
}

for target in "$@"; do
    scan_target "$target"
done

if (( failures > 0 )); then
    echo "Metadata privacy audit failed with $failures finding(s)." >&2
    exit 1
fi
echo "PASS: no private builder identity, home paths, image metadata, privacy-bearing xattrs, or debug payloads"
