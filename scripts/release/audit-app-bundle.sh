#!/usr/bin/env bash
set -euo pipefail

app="${1:-}"
expected_authority="${2:-QuilNode Project Release Signing}"
[[ -d "$app" ]] || { echo "Usage: $0 /path/to/QuilNode.app [signing-authority]" >&2; exit 64; }
project="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
certificate_sha1="$(openssl x509 -inform der -in "$project/Resources/QuilNodeReleaseSigning.cer" \
    -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)"
[[ "$certificate_sha1" =~ ^[A-Fa-f0-9]{40}$ ]]
# A leading '=' tells codesign this is literal requirement text, not a filename.
certificate_requirement="=certificate leaf = H\"$certificate_sha1\""

codesign --verify --deep --strict --verbose=2 "$app"
codesign --verify --strict -R "$certificate_requirement" "$app"
[[ "$(lipo -archs "$app/Contents/MacOS/QuilNode")" == "arm64" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == "com.quilnode.app" ]]
[[ ! -e "$app/Contents/Resources/qclient" ]]
[[ -d "$app/Contents/Frameworks/Sparkle.framework" ]]
[[ -x "$app/Contents/Helpers/QuilNodeHelper" ]]
[[ -x "$app/Contents/Helpers/QuilNodeReleaseVerifier" ]]
[[ ! -e "$app/Contents/Resources/QuilNodeLocalSigning.cer" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SURequireSignedFeed' "$app/Contents/Info.plist")" == "true" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUVerifyUpdateBeforeExtraction' "$app/Contents/Info.plist")" == "true" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUAllowsAutomaticUpdates' "$app/Contents/Info.plist")" == "false" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUEnableAutomaticChecks' "$app/Contents/Info.plist")" == "true" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUScheduledCheckInterval' "$app/Contents/Info.plist")" == "3600" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUEnableSystemProfiling' "$app/Contents/Info.plist")" == "false" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$app/Contents/Info.plist")" == https://* ]]
[[ -n "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")" ]]
if /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity:NSAllowsArbitraryLoads' \
    "$app/Contents/Info.plist" >/dev/null 2>&1; then
    echo "The application weakens App Transport Security." >&2
    exit 1
fi

if find "$app" -type f -perm -022 -print -quit | grep -q .; then
    echo "The application contains a group/world-writable file." >&2
    exit 1
fi
if find "$app" -type f \( -perm -4000 -o -perm -2000 \) -print -quit | grep -q .; then
    echo "The application contains a set-user-ID or set-group-ID file." >&2
    exit 1
fi

while IFS= read -r -d '' candidate; do
    file "$candidate" | grep -q 'Mach-O' || continue
    codesign --verify --strict -R "$certificate_requirement" "$candidate"
    authority="$(codesign -dvv "$candidate" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
    [[ "$authority" == "$expected_authority" ]] || {
        echo "Unexpected code-signing authority for $candidate: $authority" >&2
        exit 1
    }
    signature_metadata="$(codesign -dvvv "$candidate" 2>&1)"
    if ! printf '%s' "$signature_metadata" | rg -q 'flags=.*\(runtime\)'; then
        echo "Hardened runtime is missing from $candidate" >&2
        exit 1
    fi
    if otool -L "$candidate" | rg -q '^[[:space:]]+/(Users|private/tmp|tmp|opt/homebrew|usr/local)/'; then
        echo "A distributable executable links to a build-machine dependency: $candidate" >&2
        exit 1
    fi
    if otool -l "$candidate" | awk '
        $1 == "cmd" && $2 == "LC_RPATH" { getline; getline; print $2 }
    ' | rg -q '^/(Users|private/tmp|tmp|opt/homebrew|usr/local)/'; then
        echo "A distributable executable contains a build-machine runtime search path: $candidate" >&2
        exit 1
    fi
    if file "$candidate" | rg -q 'Mach-O .* executable' &&
       ! otool -hv "$candidate" | rg -q '\bPIE\b'; then
        echo "A distributable executable is not position-independent: $candidate" >&2
        exit 1
    fi
    entitlements="$(codesign -d --entitlements :- "$candidate" 2>/dev/null || true)"
    if printf '%s' "$entitlements" | rg -q \
        'get-task-allow|allow-dyld-environment-variables|allow-jit|allow-unsigned-executable-memory|disable-executable-page-protection|com\.apple\.private'; then
        echo "Dangerous entitlement detected in $candidate" >&2
        exit 1
    fi
    if [[ "$candidate" != "$app/Contents/MacOS/QuilNode" ]] &&
       printf '%s' "$entitlements" | rg -q 'disable-library-validation'; then
        echo "Library-validation weakening escaped the host executable: $candidate" >&2
        exit 1
    fi
done < <(find "$app" -type f -print0)

host_entitlements="$(codesign -d --entitlements :- "$app" 2>/dev/null)"
printf '%s' "$host_entitlements" | rg -q 'com\.apple\.security\.cs\.disable-library-validation'
[[ "$(printf '%s' "$host_entitlements" | rg -c '<key>')" -eq 1 ]]
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/audit-metadata-privacy.sh" artifact "$app"
echo "PASS: sealed app code, hardened runtime, PIE, updater policy, authority, entitlements, permissions, and dependency boundary"
