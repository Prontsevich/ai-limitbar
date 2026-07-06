# AI Limitbar Plan

## Purpose

AI Limitbar is a macOS menu bar app for monitoring AI provider usage limits in
one place. The app should make it clear which limits are known precisely, which
are estimates, and which require opening the provider's own usage page.

The first version focuses on visibility and reliability, not on perfect
coverage. A provider integration is acceptable only if the app can explain where
the number came from and how fresh it is.

## Initial Providers

- OpenAI Codex
- Claude Code
- Ollama Cloud
- Mock provider for UI and storage development

## MVP Scope

The MVP should provide a working macOS menu bar app with:

- A menu bar status item summarizing provider state.
- A compact provider list with current usage snapshots.
- Manual refresh.
- A settings window for enabling providers.
- A local JSON snapshot store.
- Provider adapters behind a shared interface.
- Clear source and confidence labels for every displayed value.

The MVP does not need a WidgetKit widget yet. The widget should come after the
menu bar app can reliably produce normalized snapshots.

## MVP Implementation Status

The current implementation is a SwiftPM-based macOS app with a SwiftUI
`MenuBarExtra`, a settings scene, normalized provider snapshots, local JSON
storage, provider enablement settings, and a project-local build/run script.

The app ships with:

- `MockProviderAdapter`, enabled by default, for refreshable local-estimate data.
- Manual placeholder adapters for OpenAI Codex, Claude Code, and Ollama Cloud.
- `snapshots.json` for persisted normalized snapshots.
- `providers.json` for persisted provider enablement state.
- A disabled credential surface plus a Keychain service interface for future
  real provider integrations.

The MVP deliberately does not fetch real OpenAI, Claude, or Ollama usage yet.
Those providers are visible as manual-confidence placeholders until the research
spikes confirm stable machine-readable usage sources.

## Non-Goals For MVP

- Perfect real-time quota accuracy for every provider.
- Browser automation as a default data source.
- Unofficial scraping that cannot be isolated behind a clearly marked
  experimental provider mode.
- Cross-device usage reconciliation.
- Team administration dashboards.
- Linear backlog setup.

## Product Principles

- Be honest about data quality.
- Prefer official APIs and CLI surfaces over scraping.
- Keep secrets in Keychain, not in plain JSON files.
- Keep the widget passive: it should render stored snapshots, not authenticate
  or fetch provider data directly.
- Treat provider integrations as replaceable adapters.
- Design for a small, glanceable menu bar experience before adding richer views.

## Usage Snapshot Model

Every provider should normalize its state into a common snapshot shape:

```json
{
  "providerID": "claude-code",
  "displayName": "Claude Code",
  "status": "ok",
  "planName": "Max",
  "periodLabel": "5-hour window",
  "usedPercent": 64,
  "remainingLabel": "Approx. 36% remaining",
  "resetAt": "2026-07-07T18:00:00Z",
  "lastUpdatedAt": "2026-07-07T10:15:00Z",
  "confidence": "local-estimate",
  "source": "Claude Code local usage data",
  "warnings": []
}
```

Fields can be absent when the provider cannot supply them. The UI should handle
missing values deliberately instead of inventing defaults.

## Confidence Levels

- `live`: fetched from an official current usage API or equivalent live source.
- `delayed`: official data, but known to lag.
- `local-estimate`: derived from local CLI history, logs, or local accounting.
- `manual`: provider page must be opened to inspect the current state.
- `unknown`: the app cannot determine the current state.

Confidence is part of the product, not an implementation detail. It should be
visible enough that users do not mistake estimates for authoritative limits.

## Provider Adapter Contract

Each provider adapter should be responsible for:

- Detecting whether it is configured.
- Fetching or deriving a usage snapshot.
- Returning structured errors.
- Reporting the data source and confidence level.
- Providing a provider usage URL when available.

Adapters should not write UI state directly. They should return normalized
snapshots to an app-level store.

## Provider Assumptions

### OpenAI Codex

Codex exposes usage and rate-limit information through product surfaces such as
CLI commands and status UI. Enterprise workspaces also have analytics-style
reporting, but that data can lag and may not represent a personal real-time
remaining quota.

Initial integration should be treated as best-effort until a stable,
documented source for the target account type is confirmed.

MVP status: manual-confidence placeholder only. The app can open the provider
surface, but it does not parse Codex usage or store Codex credentials.

### Claude Code

Claude Code has local usage visibility and plan usage displays. Some data may be
derived from local history, so it may not reflect use from other machines or
other Claude surfaces.

Initial integration should separate local estimates from official account-level
usage if both become available.

MVP status: manual-confidence placeholder only. The app does not parse local
Claude Code files or CLI output until the source format is verified.

### Ollama Cloud

Ollama Cloud supports cloud model access and account usage pages. The first
research pass should determine whether account usage is available through a
documented API endpoint or only through authenticated web settings.

Initial integration should prefer API-key based access if usage data is exposed
there.

MVP status: manual-confidence placeholder only. The app does not call Ollama
Cloud APIs until a documented usage endpoint is confirmed.

## App Architecture

The app should be structured around:

- `MenuBarExtra` for the primary interface.
- `Settings` scene for provider configuration.
- `UsageSnapshotStore` for persisted snapshots.
- `ProviderRegistry` for available adapters.
- `ProviderAdapter` protocol for provider-specific logic.
- Keychain-backed credential storage.
- A refresh coordinator that can run manual and scheduled refreshes.

The first scaffold can use a mock provider and local JSON storage before adding
real provider clients.

## Storage

The initial snapshot store can be a JSON file stored in application support.
Later, when WidgetKit is added, snapshots should move to an App Group container
so the widget extension can read them.

Stored snapshots must not contain raw tokens, API keys, cookies, or provider
session data.

## Security

- Store provider credentials in Keychain.
- Do not log secrets.
- Do not store raw provider responses if they may contain sensitive account
  details.
- Keep any experimental scraping or browser-derived provider mode disabled by
  default and clearly marked.

## UI Direction

The menu bar UI should be compact and utility-focused:

- Provider name.
- Status indicator.
- Usage percent or textual status.
- Reset time when known.
- Last updated age.
- Confidence/source label.
- Refresh and settings actions.

The settings UI should support:

- Enabling/disabling providers.
- Selecting auth/source mode where applicable.
- Testing provider connection.
- Opening the provider's usage page.

## Widget Direction

WidgetKit should be added only after the app produces reliable snapshots.

The widget should:

- Read snapshots from shared storage.
- Show a compact provider summary.
- Avoid direct network calls.
- Show stale data clearly.
- Deep-link back into the menu bar app/settings when action is needed.

## Open Questions

- Which exact account types should be supported first for OpenAI Codex?
- Can Claude Code expose current plan usage through a stable machine-readable
  command or file, or only through UI output?
- Does Ollama Cloud expose usage through a documented API endpoint?
- What refresh interval is useful without hitting provider limits?
- Should the app be menu-bar-only, or should it also keep a Dock/main window?

## First Implementation Slice

Build a macOS app skeleton with:

- Mock provider.
- `UsageSnapshot` model.
- `ProviderAdapter` protocol.
- JSON snapshot store.
- Menu bar provider list.
- Settings window placeholder.
- Manual refresh.

Real provider integrations should be added only after this skeleton is working.

## Local Development

Build:

```zsh
swift build
```

Test:

```zsh
swift test
```

Run and verify the menu bar app process:

```zsh
./script/build_and_run.sh --verify
```
