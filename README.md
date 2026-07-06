# AI Limitbar

AI Limitbar is a macOS menu bar app for viewing normalized AI provider usage
snapshots in one compact place. The MVP is intentionally honest about data
quality: values can be live, delayed, local estimates, manual checks, or
unknown.

## Current MVP

- SwiftUI `MenuBarExtra` primary interface.
- Mock provider with refreshable local-estimate data.
- Manual placeholder adapters for OpenAI Codex, Claude Code, and Ollama Cloud.
- Provider enablement settings.
- Local JSON storage in Application Support.
- Disabled credential surface and a Keychain service interface for future real
  integrations.

No real provider credentials are required for the MVP.

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

These files must not contain provider credentials, raw tokens, cookies, or raw
provider responses.
