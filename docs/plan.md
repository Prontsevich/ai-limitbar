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
`MenuBarExtra`, normalized provider snapshots, local JSON storage, provider
account settings, and a project-local build/run script.

The app ships with:

- `MockProviderAdapter` for refreshable local-estimate data.
- Manual placeholder adapter for OpenAI Codex.
- `OllamaCloudProviderAdapter` with manual and opt-in experimental web-page modes.
- `ClaudeCodeProviderAdapter` with manual and opt-in local-snapshot modes.
- `snapshots.json` for persisted normalized snapshots.
- `providers.json` for persisted provider enablement state.
- A disabled credential surface plus a Keychain service interface for future
  real provider integrations.

The MVP deliberately does not fetch authoritative live OpenAI, Claude, or Ollama
quota data. Ollama's experimental page source is live but undocumented and is
not treated as authoritative. Claude Code can read an AI Limitbar-owned local snapshot as an
explicit local estimate; the other provider paths remain manual-confidence
placeholders until stable machine-readable sources are verified.

The planned Ollama Cloud web-page mode is an explicit exception to the
manual-first baseline. It remains disabled by default and is not part of the
current implementation until Milestone 14 is complete.

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
- Target modern macOS technology and current system UI patterns instead of
  preserving old OS compatibility.
- Prefer standard SwiftUI controls and structures because they already carry
  the current Liquid Glass appearance, pointer behavior, focus behavior, and
  accessibility.

## Platform Baseline

AI Limitbar is a modern-only macOS app. The project targets macOS 26 Tahoe as
the current Liquid Glass-capable baseline and should not shape UI architecture
around macOS 14-era compatibility.

Modern-only means:

- The SwiftPM manifest uses SwiftPM 6.2, macOS 26, and Swift 6 language mode.
- The deployment target can move forward when current SwiftUI/macOS APIs make
  the app simpler, more native, or more visually correct.
- Standard system controls, sidebars, toolbars, sheets, focus handling, pointer
  states, and keyboard behavior are preferred over hand-built replacements.
- Liquid Glass is the design baseline. Standard SwiftUI controls should provide
  most of that behavior directly; custom glass should be reserved for
  product-specific compositions, not for recreating system controls.
- SwiftUI scenes and system controls are preferred for UI and windowing.
  AppKit window lifecycle bridges are out of scope for the modern Settings path.
- Compatibility fallbacks for older macOS releases are out of scope unless this
  product decision is explicitly reopened.

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
  "limitWindows": [
    {
      "id": "weekly",
      "displayName": "Weekly",
      "usedPercent": 52,
      "remainingLabel": "Approx. 48% remaining",
      "resetAt": "2026-07-14T00:00:00Z"
    },
    {
      "id": "rolling-5-hour",
      "displayName": "5-hour",
      "usedPercent": 64,
      "remainingLabel": "Approx. 36% remaining",
      "resetAt": "2026-07-07T18:00:00Z"
    }
  ],
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

Experimental web-page sources must keep their authentication boundary inside an
AI Limitbar-owned WebKit view. They may receive a minimal, validated bridge
payload from that view, but must not read, import, export, or persist cookies,
tokens, raw HTML, browser storage, or raw bridge payloads. A parsing or session
failure must preserve the last valid normalized snapshot.

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

MVP status: opt-in `local-estimate` source backed by an AI Limitbar-owned
snapshot written by the Claude Code `statusLine` helper. The app does not parse
Claude interactive screens, private local files, or browser pages.

Research date: 2026-07-12.

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
| Claude Code status line | User-configured command receives JSON session data on stdin, including `rate_limits.five_hour` and `rate_limits.seven_day` with consumed percentages and reset timestamps when available. | Selected opt-in source. AI Limitbar's helper writes a versioned local snapshot with `local-estimate` confidence. It remains machine/session-local, not authoritative account-wide usage. |
| OpenTelemetry export | Metrics and logs/events for organization usage, cost, token counters, active time, tool activity, and API request events when telemetry is enabled. | Future team/admin mode can ingest telemetry with `local-estimate` or organization-reporting confidence. It requires explicit telemetry configuration and is not a default personal account source. |
| Claude Code analytics dashboard | Team/Enterprise usage and contribution dashboards, with CSV export; API customers have Console team insights. | Future admin/reporting mode only. Not a live personal remaining-limit source. |
| Claude Console Usage page | Authoritative billing for API users. | Manual source for API billing. It should not be shown as Claude subscription plan remaining quota. |

Selected initial confidence level: `local-estimate` for statusLine snapshots and
`manual` when the helper is not configured.

Selected MVP source mode: configure an AI Limitbar-owned statusLine helper. The
helper consumes only documented statusLine JSON and writes schema v1 to
`~/Library/Application Support/AI Limitbar/Claude Code/statusline.json`. The
user must explicitly add the generated command to `~/.claude/settings.json`;
AI Limitbar does not edit Claude Code settings automatically.

First real provider decision: Claude Code is the initial Milestone 5 provider.
The first implementation does not parse Claude's interactive screens or private
local files. It provides an opt-in helper that writes an AI Limitbar-owned JSON
snapshot. The snapshot contract is versioned and clearly labeled as local
machine data rather than authoritative account-level quota.

Configuration requirements:

- Provider settings persist a source mode for each provider.
- Claude Code supports `manual` and `local-snapshot` source modes.
- Claude Code local-snapshot mode persists a JSON file path; the Settings helper
  setup defaults to the managed Application Support path.
- One enabled account may use the managed helper path because Claude Code's
  statusLine input does not carry an account identifier.
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
  "limitWindows": [
    {
      "id": "weekly",
      "displayName": "Weekly",
      "usedPercent": 52,
      "remainingLabel": "Approx. 48% remaining",
      "resetAt": "2026-07-14T00:00:00Z"
    },
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

`schemaVersion` and `lastUpdatedAt` are required. Dates use ISO 8601 strings.
`usedPercent` and each `limitWindows[].usedPercent` value are optional, but if
present they must be in the inclusive `0...100` range. The adapter maps this
payload to a normalized `UsageSnapshot` with `local-estimate` confidence and
adds a warning that the data is local only. The legacy single-window fields
remain supported; `limitWindows` is used when the helper can report more than
one provider-defined window.

The bundled statusLine helper maps `rate_limits.five_hour` to
`rolling-5-hour` / `5-hour` and `rate_limits.seven_day` to `seven-day` / `7-day`.
It writes only windows with valid percentages, converts `resets_at` Unix
timestamps to ISO 8601, and leaves the last valid file untouched when Claude
does not provide subscription rate-limit data.

The schema intentionally excludes free-form provider warnings, raw responses,
credentials, cookies, and tokens so the app does not persist arbitrary provider
text outside Keychain.

OpenAI Codex remains manual-first because the checked sources do not document a
non-interactive personal quota API. Ollama Cloud remains manual-first by
default because the checked API docs do not expose account usage or
remaining-limit endpoints; its planned web-page mode is isolated and clearly
marked as experimental.

### Ollama Cloud

Ollama Cloud supports cloud model access and an authenticated account usage
page. Its documented API does not currently expose account usage or
remaining-limit endpoints.

Research result: the authenticated `https://ollama.com/settings` page currently
server-renders session and weekly usage percentages with reset information. No
separate usage JSON response was observed during the page-load check.

Current implementation status: manual-confidence placeholder remains the default,
and Milestone 14 adds an explicit opt-in `ollama-web-page` source mode. This does
not turn the undocumented page into a supported Ollama API.

Research dates: 2026-07-07 and 2026-07-13.

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
| Ollama account settings page | The authenticated `https://ollama.com/settings` page currently server-renders `Session usage` and `Weekly usage` percentages with reset information. | Current manual fallback. Planned experimental source only through an AI Limitbar-owned WebKit connection, semantic DOM parsing, and a visible compatibility warning. It must not reuse another browser's session or store raw page/session data. |

Current confidence level: `manual`.

Planned web-page confidence level: `live` only for a successfully parsed current
settings page, with source text `Ollama settings web page (Experimental)` and a
visible structural-compatibility warning. `live` describes freshness of the
provider-displayed value; it does not imply that the DOM integration is a
documented or stable API.

Current source mode: open Ollama account/settings pages and label the snapshot
as manual. Do not call Ollama Cloud APIs for usage monitoring until a documented
account usage endpoint exists.

Implemented source mode: `ollama-web-page` is opt-in and starts with an
AI Limitbar-owned `WKWebView` connection. Each account stores only an opaque
WebKit data-store UUID in provider configuration; WebKit owns the persistent
session data. The user completes sign-in in that view, and the app never reuses
or extracts a session from Codex, Safari, Chrome, or another browser.

The WebKit user script is guarded to `https://ollama.com/settings` and extracts
only semantic `Session usage` and `Weekly usage` values from their individual
usage cards, even when Ollama wraps both cards in a shared section. Interactive
login may follow the expected Ollama WorkOS/Google/GitHub authentication
redirects; reset times are carried through when exposed by the page.
scheduled refresh never follows auth redirects. Interactive login remains open
until it completes or the user cancels the connection sheet, while scheduled
refresh keeps a 20-second load timeout. Swift validates the
typed bridge payload before mapping it to two `UsageLimitWindow` entries,
discards the in-memory payload after validation, and leaves the last valid
snapshot in place after a missing session, parser drift, incomplete data,
timeout, or load failure. Scheduled refresh never foregrounds the login UI or
attempts unattended reauthentication. If AI Limitbar later becomes an Ollama
request proxy, it can expose its own `local-estimate` counters for observed
requests, but those must remain labeled as partial and not account-wide.

## App Architecture

The app should be structured around:

- `MenuBarExtra` for the primary interface.
- A SwiftUI `Settings` scene for provider/account configuration.
- `UsageSnapshotStore` for persisted snapshots.
- `ProviderRegistry` for available adapters.
- `ProviderAdapter` protocol for provider-specific logic.
- `ProviderRefreshCoordinator` for converting configured adapter refresh
  requests into normalized snapshots.
- Keychain-backed credential storage.
- A refresh coordinator that can run manual and scheduled refreshes.

The first scaffold can use a mock provider and local JSON storage before adding
real provider clients.

Modern macOS UI structure should use system SwiftUI patterns before custom
layout code. Settings, toolbars, sidebars, sheets, forms, pickers, toggles,
menus, and buttons should be native controls unless the product needs behavior
that the system cannot express.

## Snapshot Model Direction

`UsageSnapshot` should continue to represent normalized account state, but the
dashboard needs more than one usage percentage per account. Future snapshot
versions should add provider-defined limit windows while keeping the existing
summary fields for compatibility and menu bar title calculations.

A limit window should describe one visible quota window, not a hardcoded app
category. Common examples include a weekly window plus rolling 3-hour, 4-hour,
5-hour, or provider-specific hourly windows. Each window should carry a stable
kind or identifier when known, a display label, optional used percentage,
optional remaining/reset text, optional `resetAt`, and confidence/source
metadata inherited from or compatible with the parent snapshot.

When a provider exposes only one value, the dashboard can render that value as a
single limit window. When no machine-readable value exists, the account row
should show an unavailable/manual state instead of inventing progress bars.

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

Shared snapshot format version: `2`. `snapshots.json` is a JSON document with
`formatVersion` and `snapshots` fields. Version 2 stores account-scoped normalized
`UsageSnapshot` values and provider-defined limit windows.

Raw legacy arrays and documents with another format version are not decoded as
current snapshots. Before replacing an unsupported or malformed document, the
store preserves the original file as a local backup. A future App Group move
must use the same version-aware store behavior instead of a separate legacy
migrator.

Widget constraints:

- The widget is passive: it reads versioned normalized snapshots from the App
  Group container and renders them.
- The widget must not authenticate, call providers, read Keychain credentials,
  parse local provider files, or write provider configuration.
- Missing, stale, unavailable, or manual-confidence snapshots must be displayed
  honestly without invented usage values.
- Timeline reloads should follow stored snapshot freshness and the app's
  configured refresh interval; provider refresh remains the app's job.

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
- Keep Ollama WebKit sessions isolated per account and delete the corresponding
  WebKit data store when the account is deleted.

## UI Direction

The menu bar UI should behave like a compact dashboard. Opening the panel should
let the user assess all enabled accounts quickly and then move on.

The visual design should follow current macOS and Liquid Glass conventions. The
app should not recreate system hover, pressed, focus, toolbar, sidebar, sheet,
or glass behavior by hand when standard SwiftUI controls can provide it.
Custom backgrounds, opaque fills, manual selection states, and `.plain` button
styles should be removed or justified when they suppress native interaction
feedback.

Dashboard rows should:

- Show accounts in user-defined order, not grouped by provider by default.
- Treat the account name as the primary label and provider name as secondary
  context.
- Render one compact progress bar per known limit window, such as weekly plus
  provider-defined 3-hour, 4-hour, 5-hour, or other rolling windows.
- Keep unavailable, manual, stale, warning, and error states visible inline
  without hiding other accounts.
- Avoid scrolling for common small setups; 3-5 accounts should remain readable
  at a glance.

Account details should be available on demand rather than permanently occupying
the dashboard. Use an explicit `?` or info button to open a popover with source,
confidence, warnings, last refresh state, reset details, and per-account
actions. Hover may be added as a convenience, but it must not be the only way to
access details.

The settings UI should support:

- A native SwiftUI Settings window opened through the system settings action.
- A compact native segmented navigation control for Accounts, Refresh, and
  Provider Setup instead of a permanent top tile bar or navigation sidebar.
- An Accounts master-detail layout with an account-name-first list, provider as
  secondary text, footer add/delete controls, and selected-account detail pane.
- Enabling/disabling providers.
- Ordering accounts through native drag-and-drop, with Move Up/Down context-menu
  actions as a keyboard/accessibility fallback.
- Selecting auth/source mode where applicable.
- A visible Refresh All icon action in the account-list footer and a
  selected-account Refresh action, with Test Connection and Open Usage in an
  overflow menu without a separate disclosure chevron.
- The overflow trigger should remain visually consistent with the other glass
  buttons; its popup may use a narrow native `NSMenu` bridge when the SwiftUI
  Settings renderer cannot reproduce the standard macOS menu presentation.
- Read-first account details with explicit Edit, Save, and Cancel actions.
- A single discard-confirmation flow for meaningful unsaved account changes
  when switching accounts or Settings sections.
- Reset of transient account-editor state when Settings closes, so reopening
  starts from a clean Accounts view.
- Testing provider connection and opening the provider's usage page.

Settings should be redesigned around the modern macOS system language. Prefer
native tabs, lists, split layouts, buttons, forms, pickers, toggles, menus, and
confirmation dialogs because they already include the intended Liquid Glass
appearance and interaction behavior. Use custom Liquid Glass surfaces for
AI Limitbar-specific compositions, such as account status clusters or dashboard
summaries, not to recreate standard controls. Preserve the working account
workflows while removing legacy-looking custom chrome and custom account cards.

Settings windowing should use SwiftUI's `Settings` scene. Previous controlled
AppKit window lifecycle work is no longer the desired direction. Settings
behavior across macOS Spaces is explicitly deferred and is not part of the
current quality gate.

The app is intentionally menu-bar-only. Local development, debugging, logging,
telemetry, and verification should all run the same staged `LSUIElement` app
bundle so lifecycle behavior does not change between development modes. AppKit
is permitted at a narrow application-lifecycle boundary for normal termination;
it should not own Settings or feature state.

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
- Can the authenticated Ollama settings page retain the semantic usage and reset
  fields required by the experimental parser as the site evolves?
- What refresh interval is useful without hitting provider limits?

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
