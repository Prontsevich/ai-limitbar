# AI Limitbar

AI Limitbar is a macOS menu bar app for viewing normalized AI provider usage
snapshots in one compact place. The MVP is intentionally honest about data
quality: values can be live, delayed, local estimates, manual checks, or
unknown.

## Current MVP

- SwiftUI `MenuBarExtra` primary interface.
- Mock provider with refreshable local-estimate data.
- Manual placeholder adapters for OpenAI Codex and Ollama Cloud.
- Claude Code `statusLine` helper that writes opt-in local-estimate rate-limit
  snapshots.
- Provider enablement settings.
- Configurable refresh interval with manual-only as the default.
- Local JSON storage in Application Support.
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

## Claude Code StatusLine Source

Claude Code can run the bundled `AILimitBarClaudeStatusLine` helper. It reads the
documented `statusLine` JSON from stdin and writes an AI Limitbar-owned local
snapshot. This is a local estimate, not authoritative account-level quota.

In Settings, create or edit a Claude Code account, choose `Local snapshot`, and
use `Install or Repair Helper`. Add the displayed `statusLine` object to
`~/.claude/settings.json` explicitly. AI Limitbar does not edit Claude Code
settings automatically, and the helper replaces the current custom `statusLine`
when enabled.

```json
{
  "schemaVersion": 1,
  "planName": "Max",
  "periodLabel": "5-hour window",
  "usedPercent": 64,
  "remainingLabel": "Approx. 36% remaining",
  "resetAt": "2026-07-07T18:00:00Z",
  "limitWindows": [
    {
      "id": "rolling-5-hour",
      "displayName": "5-hour",
      "usedPercent": 64,
      "remainingLabel": "Approx. 36% remaining",
      "resetAt": "2026-07-07T18:00:00Z"
    }
  ],
  "lastUpdatedAt": "2026-07-07T10:15:00Z"
}
```

`schemaVersion` and `lastUpdatedAt` are required. Dates must be ISO 8601
strings. `usedPercent` and every `limitWindows[].usedPercent`, when present,
must be between 0 and 100. Claude Code's `five_hour` and `seven_day` statusLine
windows are mapped to provider-defined `limitWindows` entries.
The local snapshot must not contain credentials, cookies, tokens, raw provider
responses, or free-form provider warnings.

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

Snapshots and provider settings are stored as JSON files under the user's
Application Support directory:

- `snapshots.json`
- `providers.json`
- `refresh-settings.json`

These files must not contain provider credentials, raw tokens, cookies, or raw
provider responses.

If `snapshots.json` is malformed or uses another format version, AI Limitbar
does not decode it as current data. Before the next save replaces that document,
the original file is copied beside it with a `.backup` suffix.
