# AI Limitbar

AI Limitbar is a macOS menu bar app for viewing normalized AI provider usage
snapshots in one compact place. The MVP is intentionally honest about data
quality: values can be live, delayed, local estimates, manual checks, or
unknown.

## Current MVP

- SwiftUI `MenuBarExtra` primary interface.
- Mock provider with refreshable local-estimate data.
- Manual placeholder adapters for OpenAI Codex and Ollama Cloud.
- Claude Code local snapshot adapter for opt-in local-estimate data.
- Provider enablement settings.
- Configurable refresh interval with manual-only as the default.
- Local JSON storage in Application Support.
- Disabled credential surface and a Keychain service interface for future real
  integrations.

No real provider credentials are required for the MVP.

## Claude Code Local Snapshot

Claude Code can be configured to read an AI Limitbar-owned local JSON snapshot.
This is a local estimate, not authoritative account-level quota.

```json
{
  "schemaVersion": 1,
  "planName": "Max",
  "periodLabel": "5-hour window",
  "usedPercent": 64,
  "remainingLabel": "Approx. 36% remaining",
  "resetAt": "2026-07-07T18:00:00Z",
  "lastUpdatedAt": "2026-07-07T10:15:00Z"
}
```

`schemaVersion` and `lastUpdatedAt` are required. Dates must be ISO 8601
strings. `usedPercent`, when present, must be between 0 and 100.
The local snapshot must not contain credentials, cookies, tokens, raw provider
responses, or free-form provider warnings.

## Build

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
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

## Storage

Snapshots and provider settings are stored as JSON files under the user's
Application Support directory:

- `snapshots.json`
- `providers.json`
- `refresh-settings.json`

These files must not contain provider credentials, raw tokens, cookies, or raw
provider responses.
