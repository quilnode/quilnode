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

printf '\nApplication feature responsibility inventory\n'
printf '%-38s %8s %10s\n' 'Feature / responsibility' 'Files' 'Swift LOC'
for responsibility_path in Sources/QuilNodeApp/Features/*/*; do
    [[ -d "$responsibility_path" ]] || continue
    responsibility="${responsibility_path#Sources/QuilNodeApp/Features/}"
    file_count="$(find "$responsibility_path" -type f -name '*.swift' | wc -l | tr -d ' ')"
    line_count="$({ find "$responsibility_path" -type f -name '*.swift' -print0 | xargs -0 wc -l; } \
        | awk '$2 == "total" { print $1 }')"
    if [[ -z "$line_count" ]]; then
        line_count="$({ find "$responsibility_path" -type f -name '*.swift' -print0 | xargs -0 wc -l; } \
            | awk 'NF == 2 { total += $1 } END { print total + 0 }')"
    fi
    printf '%-38s %8s %10s\n' "$responsibility" "$file_count" "$line_count"
done

printf '\nTest inventory\n'
printf '%-24s %8s %10s\n' 'Target' 'Files' 'Swift LOC'
for target_path in Tests/*; do
    [[ -d "$target_path" ]] || continue
    target="${target_path#Tests/}"
    file_count="$(find "$target_path" -type f -name '*.swift' | wc -l | tr -d ' ')"
    line_count="$({ find "$target_path" -type f -name '*.swift' -print0 | xargs -0 wc -l; } \
        | awk '$2 == "total" { print $1 }')"
    if [[ -z "$line_count" ]]; then
        line_count="$({ find "$target_path" -type f -name '*.swift' -print0 | xargs -0 wc -l; } \
            | awk 'NF == 2 { total += $1 } END { print total + 0 }')"
    fi
    printf '%-24s %8s %10s\n' "$target" "$file_count" "$line_count"
done

printf '\nApplication feature inventory\n'
printf '%-24s %8s %10s\n' 'Feature' 'Files' 'Swift LOC'
for feature_path in Sources/QuilNodeApp/Features/*; do
    [[ -d "$feature_path" ]] || continue
    feature="${feature_path##*/}"
    file_count="$(find "$feature_path" -type f -name '*.swift' | wc -l | tr -d ' ')"
    line_count="$({ find "$feature_path" -type f -name '*.swift' -print0 | xargs -0 wc -l; } \
        | awk '$2 == "total" { print $1 }')"
    if [[ -z "$line_count" ]]; then
        line_count="$({ find "$feature_path" -type f -name '*.swift' -print0 | xargs -0 wc -l; } \
            | awk 'NF == 2 { total += $1 } END { print total + 0 }')"
    fi
    printf '%-24s %8s %10s\n' "$feature" "$file_count" "$line_count"
done

printf '\nLargest production Swift files (review budget: 375 lines)\n'
find Sources -type f -name '*.swift' -print0 \
    | xargs -0 wc -l \
    | awk '$2 != "total" { print $1, $2 }' \
    | sort -nr \
    | head -n 20

printf '\nLargest test Swift files (review budget: 350 lines)\n'
find Tests -type f -name '*.swift' -print0 \
    | xargs -0 wc -l \
    | awk '$2 != "total" { print $1, $2 }' \
    | sort -nr \
    | head -n 10

printf '\nDependency contract\n'
printf '%s\n' \
    'QuilNodeApp -> QuilNodeCore -> QuilNodeShared' \
    'QuilNodeApp ----------------> QuilNodeShared' \
    'QuilNodeHelperCLI -> QuilNodeHelperKit -> QuilNodeShared' \
    'QuilNodeProbe -> QuilNodeCore'

printf '\nResponsibility contract\n'
printf '%s\n' \
    'App: SwiftUI composition, operator workflows, presentation, coordination' \
    'Core: deterministic domain rules and local observation adapters; no UI frameworks' \
    'Shared: wire and filesystem contracts with no implementation-module dependency' \
    'HelperKit: authenticated privileged capabilities; no dependency on App or Core' \
    'CLI/Probe: minimal composition roots only'
