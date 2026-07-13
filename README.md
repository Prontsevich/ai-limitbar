# AI Limitbar

AI Limitbar is a macOS menu bar app for viewing normalized AI provider usage
snapshots in one compact place. The MVP is intentionally honest about data
quality: values can be live, delayed, local estimates, manual checks, or
unknown.

## Current MVP

- SwiftUI `MenuBarExtra` primary interface.
- Mock provider with refreshable local-estimate data.
- OpenAI Codex with a manual fallback and an opt-in experimental app-server
  source for structured local rate-limit windows.
- Opt-in experimental Ollama Cloud settings-page source with isolated WebKit
  sessions and normalized session/weekly windows.
- Claude Code `statusLine` helper that writes opt-in local-estimate rate-limit
  snapshots.
- Provider enablement settings.
- Configurable refresh interval with manual-only as the default.
- Device-local `Compact` (320 pt), `Standard` (440 pt), and `Tall` (640 pt)
  dashboard-height presets in Settings > Refresh.
- Local SQLite storage in Application Support.
- Disabled credential surface and a Keychain service interface for future real
  integrations.

No real provider credentials are required for the MVP.

AI Limitbar is intentionally menu-bar-only. The staged app bundle uses
`LSUIElement`, so it does not add a Dock icon or a conventional main window.

## Platform Direction

AI Limitbar is a modern-only macOS app targeting macOS 26 Tahoe or later. The
UI should target the current Liquid Glass-capable macOS baseline instead of
preserving macOS 14-era compatibility.

Development should treat Liquid Glass and current macOS interaction behavior as
the default design baseline:

- Use system sidebars, toolbars, sheets, forms, pickers, toggles, menus, and
  buttons because they already carry the intended modern appearance and
  behavior.
- Keep native hover, pressed, focus, keyboard, and accessibility behavior.
- Use custom Liquid Glass surfaces for AI Limitbar-specific compositions, not
  to recreate standard controls.
- Prefer SwiftUI scenes and system controls for UI and windowing.

The menu bar dashboard and its account-details popover are the deliberate
exception: they use a compact terminal-fieldset status composition rather than
Liquid Glass cards. See [`docs/dashboard-design.md`](docs/dashboard-design.md)
for the approved visual and interaction requirements.

## OpenAI Codex Experimental App-Server Source

OpenAI Codex accounts use `Manual` by default. For one explicitly configured
account, Settings also offers `Experimental app-server`. On refresh, AI
Limitbar starts a short-lived local process:

```text
codex app-server --listen stdio://
```

It completes the documented app-server initialization handshake and requests
`account/rateLimits/read` over JSONL. The app normalizes only the explicitly
identified `codex` rate-limit bucket, its `primary` window, and its optional
`secondary` window. The resulting snapshot is marked `live` and visibly labeled
as experimental because the local CLI protocol may change; a successful read is
still presented as `OK`.

Leave `Codex executable` blank to use automatic discovery from the shell PATH
and standard local install locations, or select a specific executable for that
account. AI Limitbar does not open a terminal, drive `/status` through a PTY,
read browser content, session files, cookies, tokens, or credentials. It
discards raw JSON-RPC messages and deliberately excludes credits, opaque reset
identifiers, and other unneeded account fields before a snapshot is created.

Only one OpenAI Codex account can use this source at a time, since it reflects
the currently authenticated local Codex CLI identity. If the CLI is missing,
not authenticated, unsupported, malformed, or times out, the account shows a
recoverable diagnostic and the existing manual usage-page workflow remains
available.

## Claude Code StatusLine Source

Claude Code can run the bundled `AILimitBarClaudeStatusLine` helper. It reads the
documented `statusLine` JSON from stdin and writes a normalized AI Limitbar
snapshot to the app-owned SQLite database. This is a local estimate, not
authoritative account-level quota.

In Settings, create or edit a Claude Code account, choose `Managed statusLine`,
save it, and then use `Install or Repair Helper`. Add the displayed `statusLine`
object to
`~/.claude/settings.json` explicitly. AI Limitbar does not edit Claude Code
settings automatically. The generated command contains that account's stable
`--account-id`; it does not accept a database path or a user-managed snapshot
path.

The database is at `~/Library/Application Support/AI Limitbar/AI Limitbar.sqlite`.
AI Limitbar enables SQLite WAL mode, foreign keys, and a bounded write timeout so
the helper can update it while the app is closed or reading. Invalid helper input
does not change the last stored snapshot.

On the first database launch, AI Limitbar imports supported legacy JSON accounts,
snapshots, refresh settings, and Claude Code statusLine data. It does not delete
or rewrite those files, so they remain recovery backups. A custom legacy snapshot
path is read only once; Settings then shows an actionable migration warning and
requires the managed helper for future updates. The database never stores
credentials, cookies, WebKit data, raw provider responses, or raw statusLine
payloads.

## Ollama Cloud Experimental Web Page Source

Ollama Cloud does not currently document an account-usage API. AI Limitbar keeps
`Manual` as the default source and offers an opt-in `Experimental web page`
source for an Ollama account.

In Settings, save the account with `Experimental web page`, then choose
`Connect Ollama…`. Sign in only in the AI Limitbar-owned WebKit view. Each
account receives its own persistent WebKit data store identified by an opaque
UUID; AI Limitbar never reads, imports, exports, logs, or stores cookies,
passwords, tokens, browser profile data, raw HTML, or raw bridge payloads.

The source loads `https://ollama.com/settings` and extracts only the semantic
`Session usage` and `Weekly usage` sections, resolving each value from its own
usage card even when Ollama wraps both cards in a shared section.
The source also reports the reset time for each window when Ollama exposes it.
During interactive sign-in, WebKit may follow Ollama's documented authentication
redirect through `api.workos.com`,
`signin.ollama.com`, Google, or GitHub; scheduled refreshes do not follow those
auth redirects. Interactive sign-in remains open until it completes or the user
cancels it; scheduled refreshes retain a 20-second load timeout. After login,
extraction remains restricted to the settings page.
The values are labeled `Ollama settings web page (Experimental)` with `live`
confidence. The page structure is undocumented and may change, but a successful
read is presented as `OK`; model request counts, extra-usage balance, and
billing values are intentionally excluded.

`Reconnect` is available when the session expires or the page structure changes.
Scheduled refreshes never foreground the login view or attempt unattended
reauthentication. A failed refresh keeps the last valid snapshot and falls back
to a visible recovery warning; switching back to `Manual` remains supported.

## Build

Requirements:

- macOS 26 or later.
- Xcode 26 or later with a Swift 6.2-compatible toolchain.

```zsh
swift build
```

## Test

```zsh
swift test
```

## Run

```zsh
./script/build_and_run.sh
```

The run script builds the SwiftPM product, stages a local app bundle in
`dist/AILimitBar.app`, stops any existing `AILimitBar` process, and launches the
fresh bundle.

Useful modes:

```zsh
./script/build_and_run.sh --verify
./script/build_and_run.sh --debug
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

Every mode stages and launches the same menu-bar-only `.app` bundle. Debug mode
opens that bundle and attaches LLDB to its process instead of launching the raw
SwiftPM executable. The local bundle is ad-hoc signed and validated after
staging.

## Storage

Accounts, normalized snapshots, refresh settings, and safe source diagnostics
are stored in `~/Library/Application Support/AI Limitbar/AI Limitbar.sqlite`.
The device-local dashboard-height preset is stored separately in `UserDefaults`;
it is not provider or account data. Neither store contains provider credentials,
raw tokens, cookies, raw provider responses, or raw statusLine payloads.

Legacy `snapshots.json`, `providers.json`, and `refresh-settings.json` files are
imported once when valid and then retained as recovery backups.
