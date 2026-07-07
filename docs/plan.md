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

Research date: 2026-07-07.

Official sources checked:

- <https://developers.openai.com/codex/auth>
- <https://developers.openai.com/codex/pricing>
- <https://developers.openai.com/codex/cli/slash-commands>
- <https://developers.openai.com/codex/enterprise/governance>

Supported source strategy by account type:

| Account type | Supported source | Fit for AI Limitbar |
| --- | --- | --- |
| ChatGPT Plus, Pro, Business, Edu, or Enterprise signed in through Codex | Codex usage dashboard for current limits; CLI `/status` for remaining limits during an active CLI session; CLI `/usage` for daily, weekly, or cumulative token activity when service account auth is present. | MVP should use `manual` confidence and open the Codex usage dashboard or instruct the user to inspect `/status` or `/usage`. There is no documented non-interactive local API for current remaining quota in the checked docs. |
| API key auth | Usage-based access charged through the OpenAI Platform account. | Treat as separate from ChatGPT Codex included limits. A future API-key mode may link to Platform usage, but it should not be displayed as ChatGPT Codex remaining quota. |
| Enterprise/Edu admin or analytics viewer | Codex Analytics Dashboard and Analytics API. The API returns daily or weekly workspace/per-user usage buckets and requires `codex.enterprise.analytics.read`. The dashboard data can lag by up to 12 hours. | Future admin-only mode can use `delayed` confidence for workspace reporting. It is not a personal live limit source and should not be the default provider mode. |
| Enterprise compliance workflows | Compliance API exports audit records and token metadata for ChatGPT-authenticated Codex activity. | Useful for governance/audit integrations, not for a compact remaining-limit widget. |

Selected initial confidence level: `manual`.

Selected MVP source mode: open the Codex usage dashboard and label the snapshot
as manual. Do not parse browser pages, raw local auth state, CLI TUI output, or
undocumented Codex service endpoints. Revisit implementation only if an
official non-interactive source for current personal Codex limits is documented
or if an enterprise user explicitly configures the delayed Analytics API mode.

### Claude Code

Claude Code has local usage visibility and plan usage displays. Some data may be
derived from local history, so it may not reflect use from other machines or
other Claude surfaces.

Initial integration should separate local estimates from official account-level
usage if both become available.

MVP status: manual-confidence placeholder only. The app does not parse local
Claude Code files or CLI output until the source format is verified.

Research date: 2026-07-07.

Official sources checked:

- <https://code.claude.com/docs/en/costs>
- <https://code.claude.com/docs/en/commands>
- <https://code.claude.com/docs/en/statusline>
- <https://code.claude.com/docs/en/monitoring-usage>
- <https://code.claude.com/docs/en/analytics>

Supported source strategy:

| Source | Output shape | Fit for AI Limitbar |
| --- | --- | --- |
| Claude Code `/usage`, `/cost`, and `/stats` commands | Interactive session screen showing session cost, plan usage limits, activity stats, and per-feature breakdown on supported plans. API session cost is computed locally from token counts. Pro, Max, Team, and Enterprise plans include plan usage bars and breakdowns; day/week breakdown is approximate and computed from local session history on the current machine. | Good manual source. Not a reliable parser target for MVP because the checked docs describe an interactive command, not a stable JSON CLI/API output for current remaining plan quota. |
| Claude Code status line | User-configured command receives JSON session data on stdin and can render context window usage, costs, model, git state, or custom data. | Useful for a future opt-in local helper if the user chooses to install an AI Limitbar status-line script. It measures current-session/context data, not authoritative account-level plan usage. |
| OpenTelemetry export | Metrics and logs/events for organization usage, cost, token counters, active time, tool activity, and API request events when telemetry is enabled. | Future team/admin mode can ingest telemetry with `local-estimate` or organization-reporting confidence. It requires explicit telemetry configuration and is not a default personal account source. |
| Claude Code analytics dashboard | Team/Enterprise usage and contribution dashboards, with CSV export; API customers have Console team insights. | Future admin/reporting mode only. Not a live personal remaining-limit source. |
| Claude Console Usage page | Authoritative billing for API users. | Manual source for API billing. It should not be shown as Claude subscription plan remaining quota. |

Selected initial confidence level: `manual`.

Selected MVP source mode: open or instruct the user to inspect Claude Code
`/usage`. Do not parse the interactive `/usage` screen, undocumented local
session files, or status-line JSON as an account quota source. A future opt-in
`local-estimate` mode can be added only if AI Limitbar owns the collection
mechanism, such as a documented telemetry export or a user-installed status-line
helper with a clearly scoped snapshot schema.

First real provider decision: Claude Code is the initial Milestone 5 provider.
The first implementation should not attempt to parse Claude's interactive
screens or private local files. It should add an opt-in local-estimate mode that
reads an AI Limitbar-owned JSON snapshot file written by a future helper. The
snapshot contract must be documented, versioned, and clearly labeled as local
machine data rather than authoritative account-level quota.

Configuration requirements:

- Provider settings persist a source mode for each provider.
- Claude Code supports `manual` and `local-snapshot` source modes.
- Claude Code local-snapshot mode persists a user-provided JSON file path.
- Existing provider settings without source fields must continue to load as
  `manual` mode.

Local snapshot schema version 1:

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

`schemaVersion` and `lastUpdatedAt` are required. Dates use ISO 8601 strings.
`usedPercent` is optional, but if present it must be in the inclusive `0...100`
range. The adapter maps this payload to a normalized `UsageSnapshot` with
`local-estimate` confidence and adds a warning that the data is local only.
The schema intentionally excludes free-form provider warnings, raw responses,
credentials, cookies, and tokens so the app does not persist arbitrary provider
text outside Keychain.

OpenAI Codex remains manual-first because the checked sources do not document a
non-interactive personal quota API. Ollama Cloud remains manual-first because
the checked API docs do not expose account usage or remaining-limit endpoints.

### Ollama Cloud

Ollama Cloud supports cloud model access and account usage pages. The first
research pass should determine whether account usage is available through a
documented API endpoint or only through authenticated web settings.

Initial integration should prefer API-key based access if usage data is exposed
there.

MVP status: manual-confidence placeholder only. The app does not call Ollama
Cloud APIs until a documented usage endpoint is confirmed.

Research date: 2026-07-07.

Official sources checked:

- <https://docs.ollama.com/cloud>
- <https://docs.ollama.com/api/introduction>
- <https://docs.ollama.com/api/authentication>
- <https://docs.ollama.com/api/usage>
- <https://docs.ollama.com/api/tags>
- <https://docs.ollama.com/llms.txt>

Supported source strategy:

| Source | Output shape | Fit for AI Limitbar |
| --- | --- | --- |
| Local Ollama API at `http://localhost:11434/api` | Per-request response metrics such as `total_duration`, `load_duration`, `prompt_eval_count`, `eval_count`, and related timing fields. Streaming responses include usage fields in the final chunk. | Useful for request-level local model accounting only when AI Limitbar observes or proxies requests. It does not provide account-level Ollama Cloud usage or remaining quota. |
| Ollama Cloud API at `https://ollama.com/api` | Same Ollama model interaction API for cloud models, authenticated with an API key. Documented endpoints include model generation/chat, embeddings, tags, running models, model details, and model management. | Supports cloud model calls, but the checked docs do not list a billing, account usage, quota, or remaining-limit endpoint. |
| Ollama API keys/settings | API keys for programmatic access to `ollama.com`; keys can be revoked and currently do not expire. | Required for future cloud model API calls. Not enough to expose usage limits. |
| Ollama account pages | Authenticated web settings may show account or billing state. | Manual source only unless Ollama documents a usage endpoint. Do not scrape. |

Selected initial confidence level: `manual`.

Selected MVP source mode: open Ollama account/settings pages and label the
snapshot as manual. Do not call Ollama Cloud for usage monitoring until a
documented account usage endpoint exists. If AI Limitbar later becomes an
Ollama request proxy, it can expose its own `local-estimate` counters for
observed requests, but that must be labeled as partial and not account-wide.

## App Architecture

The app should be structured around:

- `MenuBarExtra` for the primary interface.
- `Settings` scene for provider configuration.
- `UsageSnapshotStore` for persisted snapshots.
- `ProviderRegistry` for available adapters.
- `ProviderAdapter` protocol for provider-specific logic.
- `ProviderRefreshCoordinator` for converting configured adapter refresh
  requests into normalized snapshots.
- Keychain-backed credential storage.
- A refresh coordinator that can run manual and scheduled refreshes.

The first scaffold can use a mock provider and local JSON storage before adding
real provider clients.

## Storage

The initial snapshot store can be a JSON file stored in application support.
Later, when WidgetKit is added, snapshots should move to an App Group container
so the widget extension can read them.

Snapshot storage location is represented by `SnapshotStorageContainer`. The
current `LocalSnapshotStorageContainer` points at Application Support, while a
future App Group container can replace it without changing provider adapters or
the JSON snapshot store format.

Provisional App Group identifier: `group.com.lestroy.ai-limitbar`. This must be
verified against the final Apple Developer Team and bundle identifiers before
signing a WidgetKit build.

Shared snapshot format version: `1`. `snapshots.json` is a JSON document with
`formatVersion` and `snapshots` fields. Version 1 stores normalized
`UsageSnapshot` values only.

Local-to-shared migration path: `SnapshotStorageMigrator` copies `snapshots.json`
from the current local container to a destination container only when the
destination file does not exist. The migrator reads through `JSONSnapshotStore`,
so legacy array files are rewritten as versioned format-1 documents.

Stored snapshots must not contain raw tokens, API keys, cookies, or provider
session data.

Snapshots are considered stale after 24 hours in manual-only mode or after two
missed configured refresh intervals in scheduled mode. Staleness is runtime UI
state derived from `lastUpdatedAt`; it is not persisted into the snapshot file.

Provider refreshes retry transient `ProviderAdapterError` failures with a small
exponential backoff. Configuration, schema, and validation errors are permanent
by default and are surfaced immediately without retry.

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
