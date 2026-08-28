#!/bin/bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly renderer="${script_dir}/render_release_notes.sh"
readonly temporary_directory="$(mktemp -d)"

cleanup() {
    rm -rf "$temporary_directory"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_rejected() {
    local description="$1"
    shift

    if "$renderer" "$@" >"${temporary_directory}/stdout" 2>"${temporary_directory}/stderr"; then
        fail "$description was accepted"
    fi
}

"$renderer" v0.5.0 >"${temporary_directory}/actual"

cat >"${temporary_directory}/expected" <<'EOF'
## English

### Added

- Experimental MiniMax Global Token Plan usage source for remaining capacity.
- Subscription Key setup in Settings, with each saved key stored only in the macOS Keychain.
- MiniMax account controls in Settings for managing its Subscription Key.
- MiniMax quota presentation on the dashboard, with independent Current and Weekly windows for each supported category.

### Notes

- The MiniMax source is opt-in and experimental. It supports the Global personal Default Team boundary only; it does not combine Teams, regions, or credentials.

## Русский

### Добавлено

- Экспериментальный источник использования MiniMax Global Token Plan для просмотра оставшихся лимитов.
- Настройка Subscription Key в Settings; каждый сохранённый ключ хранится только в macOS Keychain.
- Элементы управления аккаунтом MiniMax в Settings для управления его Subscription Key.
- Представление квот MiniMax на dashboard с независимыми окнами Current и Weekly для каждой поддерживаемой категории.

### Примечания

- Источник MiniMax подключается пользователем по желанию и является экспериментальным. Он поддерживает только Global personal Default Team и не объединяет Teams, регионы или credentials.
EOF

if ! diff -u "${temporary_directory}/expected" "${temporary_directory}/actual"; then
    fail 'v0.5.0 output did not match the release notes source'
fi

assert_rejected 'missing version'
assert_rejected 'invalid semantic version' 0.5.0
assert_rejected 'noncanonical semantic version' v01.2.3
assert_rejected 'missing changelog section' v9.9.9

printf 'PASS: release notes renderer\n'
