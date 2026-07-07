# AI Limitbar Tasks

## Milestone 0: Project Foundation

- [x] Create project directory.
- [x] Initialize git repository.
- [x] Draft MVP plan.
- [x] Create initial macOS project scaffold.
- [x] Add basic build/run script for local development.
- [x] Add project README.

## Milestone 1: App Skeleton

Goal: produce a runnable macOS menu bar app with mock data and no real provider
credentials.

- [x] Create SwiftUI macOS app target.
- [x] Add `MenuBarExtra` as the primary app surface.
- [x] Add settings scene placeholder.
- [x] Add `UsageSnapshot` model.
- [x] Add `ProviderAdapter` protocol.
- [x] Add mock provider adapter.
- [x] Add app-level snapshot state.
- [x] Render provider rows in the menu bar panel.
- [x] Add manual refresh action.
- [x] Show last updated state.
- [x] Show confidence/source labels.

Acceptance:

- The app launches.
- The menu bar item appears.
- Mock provider snapshots render.
- Manual refresh changes or reloads mock data.
- No real credentials are required.

## Milestone 2: Persistence

Goal: persist normalized snapshots locally without storing secrets.

- [x] Add application support directory resolver.
- [x] Add JSON snapshot store.
- [x] Load snapshots on app launch.
- [x] Save snapshots after refresh.
- [x] Handle missing/corrupt snapshot files gracefully.
- [x] Add lightweight error state for failed loads or saves.

Acceptance:

- Closing and reopening the app preserves the last mock snapshot.
- Snapshot JSON contains no credentials or raw provider responses.

## Milestone 3: Provider Configuration

Goal: let users enable providers and prepare for real credentials.

- [x] Add provider registry.
- [x] Add provider enabled/disabled state.
- [x] Add settings UI for provider toggles.
- [x] Add placeholder connection test action.
- [x] Add provider usage URL action.
- [x] Add Keychain service interface.
- [x] Keep credential entry disabled until real provider requirements are known.

Acceptance:

- The settings window controls which providers appear in the menu bar list.
- Provider state survives app restart.
- The app has a clear place to add credentials later.

## Milestone 4: Provider Research Spikes

Goal: determine what each provider can support reliably before implementation.

- [x] OpenAI Codex: identify supported usage sources by account type.
- [x] OpenAI Codex: decide MVP source mode and confidence level.
- [x] Claude Code: identify CLI/local usage source and output format.
- [x] Claude Code: decide whether usage can be parsed reliably.
- [x] Ollama Cloud: determine whether a documented usage API exists.
- [x] Ollama Cloud: decide MVP source mode and confidence level.
- [x] Document unsupported or manual-only cases in the plan.

Acceptance:

- Each provider has a documented source strategy.
- Each provider has a selected initial confidence level.
- No provider implementation starts from an unverified assumption.

## Milestone 5: First Real Provider

Goal: add one real provider end to end.

- [x] Pick first provider based on research results.
- [x] Implement configuration requirements.
- [x] Implement adapter fetch logic.
- [x] Normalize provider result into `UsageSnapshot`.
- [x] Add structured error handling.
- [x] Add connection test.
- [x] Add manual refresh.
- [x] Verify no secrets are logged or persisted outside Keychain.

Acceptance:

- One real provider returns a useful snapshot.
- Errors are visible and actionable.
- The mock provider still works.

Decision:

- Claude Code is the first real provider target.
- Initial mode is opt-in `local-estimate` from an AI Limitbar-owned JSON
  snapshot file.
- The provider must not parse Claude's interactive `/usage` screen,
  undocumented local session files, browser pages, or private provider state.
- The settings `Test` action uses the configured adapter fetch path and surfaces
  structured adapter errors as snapshot warnings.
- Manual refresh uses the same configured adapter fetch path for every enabled
  provider and persists the resulting normalized snapshot.
- The Claude Code local snapshot schema excludes credentials, cookies, tokens,
  raw provider responses, and free-form provider warnings; the app persists only
  normalized snapshot fields and app-generated warnings.

## Milestone 6: Refresh Coordination

Goal: make refresh behavior predictable and respectful of provider limits.

- [x] Add refresh coordinator.
- [x] Add per-provider refresh status.
- [x] Prevent overlapping refreshes.
- [x] Add configurable refresh interval.
- [x] Add stale snapshot detection.
- [x] Add retry/backoff policy for transient failures.

Acceptance:

- Manual refresh remains immediate.
- Scheduled refreshes do not overlap.
- Stale data is clearly labeled.

## Milestone 7: Widget Readiness

Goal: prepare snapshots for WidgetKit without adding the widget yet.

- [x] Move snapshot storage behind a container abstraction.
- [x] Decide App Group identifier.
- [x] Add shared snapshot format version.
- [x] Add migration path for local snapshot files.
- [x] Document widget constraints.

Acceptance:

- The app can switch storage locations without changing provider adapters.
- Widget work can start without redesigning snapshot storage.

Decision:

- Provisional App Group identifier: `group.com.lestroy.ai-limitbar`.
- The identifier must be verified against the final Apple Developer Team and
  bundle identifiers before signing a WidgetKit build.

Widget constraints:

- The widget must be passive and read only versioned normalized snapshots from
  the App Group container.
- The widget must not fetch providers, authenticate, read Keychain credentials,
  parse local provider state, or write provider configuration.
- Widget UI must handle stale, unavailable, and missing snapshots without
  inventing usage values.
- Timeline reload policy should be derived from stored snapshot freshness and
  the app's configured refresh interval.

## Milestone 8: Account Model

Goal: make the menu bar app model provider accounts explicitly before adding
more real data sources.

- [ ] Add `ProviderAccount` model.
- [ ] Add stable account identifiers scoped by provider.
- [ ] Add account display name and enabled state.
- [ ] Migrate current provider-level settings into one default account per
  provider.
- [ ] Add account identity to stored snapshots.
- [ ] Group menu bar rows by provider and account.
- [ ] Update settings to configure accounts instead of only providers.
- [ ] Keep existing single-provider mock and Claude local snapshot behavior
  working through default accounts.

Acceptance:

- A provider can have more than one configured account.
- Existing users keep their current provider settings as default accounts.
- Menu bar rows clearly identify both provider and account.
- No provider credentials are introduced outside Keychain.

## Milestone 9: Account Details Panel

Goal: make the menu bar item open a useful compact window with details for each
account.

- [ ] Add account row selection.
- [ ] Add account details view.
- [ ] Show usage, source, confidence, warnings, reset time, stale state, and
  last refresh state.
- [ ] Add per-account refresh action.
- [ ] Add per-account connection test action.
- [ ] Add per-account open usage page action.
- [ ] Add empty, unavailable, stale, and error states.
- [ ] Keep the panel compact enough for repeated menu bar use.

Acceptance:

- Clicking an account row reveals detailed account state.
- Account actions affect only the selected account.
- Errors and stale data are visible without hiding the last known snapshot.

## Milestone 10: Claude Code Data Source

Goal: make Claude Code useful without relying on hand-edited JSON files.

- [ ] Define the first supported Claude Code local data source contract.
- [ ] Add a helper/import path that writes AI Limitbar local snapshot JSON.
- [ ] Validate helper output before storing snapshots.
- [ ] Add source diagnostics for missing file, invalid schema, stale helper
  output, and invalid percentage values.
- [ ] Document how to configure Claude Code local snapshot updates.
- [ ] Avoid parsing Claude interactive screens, private local state, or browser
  pages.

Acceptance:

- Claude Code can produce useful local-estimate data without manually editing
  JSON.
- The source remains clearly labeled as local-estimate, not account-authoritative
  live usage.
- Invalid helper output does not corrupt stored snapshots.

## Milestone 11: Provider And Account Readiness

Goal: prepare the app for more providers and account-level credentials while
keeping provider implementations conservative.

- [ ] Add provider/account source diagnostics model.
- [ ] Track last successful refresh separately from failed refresh attempts.
- [ ] Add account-level credential slots backed by Keychain.
- [ ] Add credential presence checks without exposing secret values.
- [ ] Add provider capability metadata for manual, local snapshot, live, and
  delayed modes.
- [ ] Improve error copy for missing credentials, unsupported source modes, and
  unavailable provider APIs.

Acceptance:

- The app can explain why each account is or is not refreshable.
- Credentials have a clear account-level home without touching JSON storage.
- Provider adapters can advertise supported source modes.

## Milestone 12: Daily Use Polish

Goal: make the menu bar app useful as a daily status tool before starting the
WidgetKit extension.

- [ ] Improve menu bar summary title and icon based on worst account state.
- [ ] Add near-limit state.
- [ ] Add compact and detailed row display modes.
- [ ] Add account sorting controls.
- [ ] Add option to hide manual-only accounts from the main list.
- [ ] Add export/debug bundle without secrets.
- [ ] Add smoke verification for app launch, refresh, settings persistence, and
  snapshot persistence.

Acceptance:

- The menu bar item surfaces the most important account state at a glance.
- The panel remains usable with multiple providers and accounts.
- Debug output helps diagnose issues without leaking credentials or raw provider
  responses.

## Later

- [ ] Add notifications for near-limit state.
- [ ] Add Linear backlog if the project grows beyond local docs.

## Final: WidgetKit Extension

- [ ] Add WidgetKit extension.
- [ ] Read snapshots from the App Group container.
- [ ] Render account-aware snapshot summaries.
- [ ] Respect stale, unavailable, manual, and error states.
- [ ] Keep all provider refresh, auth, and parsing inside the app, not the
  widget.

## MVP Verification

- [x] `swift build`
- [x] `swift test`
- [x] `./script/build_and_run.sh --verify`
