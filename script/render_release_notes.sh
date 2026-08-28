#!/bin/bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly english_changelog_path="${script_dir}/../CHANGELOG.md"
readonly russian_changelog_path="${script_dir}/../CHANGELOG.ru.md"

usage() {
    printf 'Usage: %s vMAJOR.MINOR.PATCH\n' "${0##*/}" >&2
}

if [[ $# -ne 1 || ! $1 =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    usage
    exit 64
fi

version="$1"

extract_release_notes() {
    local changelog_path="$1"

    awk -v version="$version" '
        $0 == "## " version || index($0, "## " version " ") == 1 {
            found = 1
            printing = 1
            next
        }
        printing {
            if ($0 ~ /^## /) {
                exit
            }
            if ($0 ~ /^[[:space:]]*$/) {
                if (!content) {
                    next
                }
            } else {
                content = 1
            }
            print
        }
        END {
            if (!found || !content) {
                exit 1
            }
        }
    ' "$changelog_path"
}

if ! english_notes="$(extract_release_notes "$english_changelog_path")"; then
    printf 'English release notes for %s were not found in %s.\n' \
        "$version" "$english_changelog_path" >&2
    exit 1
fi

if ! russian_notes="$(extract_release_notes "$russian_changelog_path")"; then
    printf 'Russian release notes for %s were not found in %s.\n' \
        "$version" "$russian_changelog_path" >&2
    exit 1
fi

printf '## English\n\n%s\n\n## Русский\n\n%s\n' "$english_notes" "$russian_notes"
