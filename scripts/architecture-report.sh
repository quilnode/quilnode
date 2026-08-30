#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

printf 'QuilNode source inventory\n\n'
printf '%-24s %8s %10s\n' 'Target' 'Files' 'Swift LOC'
for target_path in Sources/*; do
    [[ -d "$target_path" ]] || continue
    target="${target_path#Sources/}"
    file_count="$(find "$target_path" -type f -name '*.swift' | wc -l | tr -d ' ')"
    line_count="$({ find "$target_path" -type f -name '*.swift' -print0 | xargs -0 wc -l; } \
        | awk '$2 == "total" { print $1 }')"
    if [[ -z "$line_count" ]]; then
        line_count="$({ find "$target_path" -type f -name '*.swift' -print0 | xargs -0 wc -l; } \
            | awk 'NF == 2 { total += $1 } END { print total + 0 }')"
    fi
    printf '%-24s %8s %10s\n' "$target" "$file_count" "$line_count"
done

printf '\nLargest production Swift files\n'
find Sources -type f -name '*.swift' -print0 \
    | xargs -0 wc -l \
    | awk '$2 != "total" { print $1, $2 }' \
    | sort -nr \
    | head -n 15

printf '\nDependency contract\n'
printf '%s\n' \
    'QuilNodeApp -> QuilNodeCore -> QuilNodeShared' \
    'QuilNodeApp ----------------> QuilNodeShared' \
    'QuilNodeHelperCLI -> QuilNodeHelperKit -> QuilNodeShared' \
    'QuilNodeProbe -> QuilNodeCore'
