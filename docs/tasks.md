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
- [x] Keep storage location switch explicit for pre-release builds.
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

- [x] Add `ProviderAccount` model.
- [x] Add stable account identifiers scoped by provider.
- [x] Add account display name and enabled state.
- [x] Allow providers to have zero, one, or many configured accounts.
- [x] Add account identity to stored snapshots.
- [x] Group menu bar rows by provider and account.
- [x] Update settings to configure accounts instead of only providers.
- [x] Keep existing single-provider mock and Claude local snapshot behavior
  working through configured accounts.

Acceptance:

- A provider can have more than one configured account.
- Providers can be left with no configured accounts.
- Menu bar rows clearly identify both provider and account.
- No provider credentials are introduced outside Keychain.

## Milestone 9: Account Details Panel

Goal: make the menu bar item open a useful compact window with details for each
account.

- [x] Add account row selection.
- [x] Add account details view.
- [x] Show usage, source, confidence, warnings, reset time, stale state, and
  last refresh state.
- [x] Add per-account refresh action.
- [x] Add per-account connection test action.
- [x] Add per-account open usage page action.
- [x] Add empty, unavailable, stale, and error states.
- [x] Keep the panel compact enough for repeated menu bar use.

Acceptance:

- Clicking an account row reveals detailed account state.
- Account actions affect only the selected account.
- Errors and stale data are visible without hiding the last known snapshot.

## Milestone 10: Dashboard Panel Redesign

Goal: make the menu bar panel a glanceable dashboard for all enabled accounts,
not a list with a permanently visible inspector.

- [x] Replace the selected-detail-first layout with compact dashboard rows.
- [x] Show every enabled account in user-defined order without grouping by
  provider.
- [x] Add account ordering controls in Settings with move up/down actions.
- [x] Add normalized limit-window rows for provider-defined windows such as
  weekly limits and 3-hour, 4-hour, 5-hour, or other rolling windows.
- [x] Render one compact progress bar per known limit window.
- [x] Keep unavailable, manual, stale, warning, and error states visible in the
  account row without hiding other accounts.
- [x] Move source, confidence, warnings, last refresh state, reset details, and
  account actions into an explicit details popover.
- [x] Use a `?` or info button for details; hover may preview or highlight but
  must not be the only way to access details.
- [x] Avoid scrolling for common small setups and keep 3-5 accounts readable at
  a glance.

Acceptance:

- Opening the menu bar panel gives a fast account-wide status overview.
- Accounts are not grouped by provider unless the user later chooses that sort.
- Each known limit window has its own label, progress bar, and reset/remaining
  text when available.
- Details are available on demand without occupying the main dashboard surface.

Decision:

- Milestone 9 remains the technical foundation for per-account selection,
  actions, and details. Milestone 10 replaces its visible panel layout with a
  dashboard-first design before adding more data-source work.
- Limit windows are provider-defined and must not be hardcoded to only hourly or
  weekly categories. A provider may expose weekly plus 3-hour, 4-hour, 5-hour,
  or other rolling windows.

## Milestone 11: Settings Window Redesign

Goal: replace the system SwiftUI `Settings` scene with a controlled settings
window and make account configuration clear enough for daily use.

Superseded by Milestone 12: Settings now uses SwiftUI's native `Settings`
scene again. The controlled AppKit settings window was removed in favor of the
current system windowing path.

- [x] Remove the system SwiftUI `Settings` scene.
- [x] Add a narrow settings window controller that owns one settings window.
- [x] Open Settings from the menu bar panel through the controlled window path.
- [x] Focus the existing Settings window when it is already open instead of
  creating duplicates.
- [x] Ensure closing Settings destroys/hides that window and does not reopen it
  during Spaces changes.
- [x] Redesign Settings around clear sections for Accounts, Refresh, and
  Provider Setup.
- [x] Make Accounts the primary Settings section.
- [x] Render each account as a readable block with name, provider, enabled
  state, source, optional local snapshot path, ordering controls, and actions.
- [x] Keep account cards read-first, with rename behind an explicit edit
  button instead of a permanently focused text field.
- [x] Use an inline add-account form instead of a modal sheet.
- [x] Require confirmation before deleting an account.
- [x] Keep add account, enable/disable, rename, move up/down, test connection,
  open usage page, delete account, Claude Code source mode, local snapshot path,
  and refresh interval working.
- [x] Keep the existing provider account and snapshot storage contracts
  unchanged.

Historical acceptance for the superseded controlled-window path:

- Settings opens as an app-controlled window from the menu bar panel.
- Pressing Settings while the window is open focuses the existing window.
- Closing Settings prevents it from reappearing on its own during Spaces changes.
- Account ordering and provider/source state are easy to understand.
- The redesign remains an MVP settings surface, not a large enterprise
  administration system.

## Milestone 12: Modern macOS And Liquid Glass Baseline

Goal: move AI Limitbar to a modern-only macOS baseline and redesign the visible
app surfaces around the current system design language instead of legacy
compatibility patterns.

- [x] Raise the deployment target to the current Liquid Glass-capable macOS
  baseline.
- [x] Remove macOS 14 compatibility as a product constraint.
- [x] Audit Settings and the menu bar panel for custom chrome, custom
  backgrounds, `.plain` button styles, and hand-built hover/selection states
  that replace standard system behavior.
- [x] Redesign Settings around standard SwiftUI structures and controls first:
  system sidebars, toolbar items, sheets, forms, pickers, toggles, and buttons
  where they fit the workflow, because those controls already carry the current
  Liquid Glass appearance and interaction model.
- [x] Treat Liquid Glass as the visual baseline for custom app-specific
  surfaces, not as a hand-built replacement for system buttons, sidebars,
  toolbars, sheets, forms, or pickers.
- [x] Prefer native hover, pressed, focus, keyboard, and accessibility behavior
  over custom visual effects.
- [x] Remove Settings window AppKit interop and use SwiftUI scene/windowing.
- [x] Remove or justify custom `GroupBox`-style account cards, opaque fills,
  manual sidebar selection backgrounds, and decorative materials that fight the
  system visual language.
- [x] Revisit Settings window strategy after the redesign: use the native
  SwiftUI `Settings` scene even if the old Spaces workaround is no longer
  preserved.
- [ ] Verify hover, click, focus ring, resize, close/reopen, and Settings
  state-reset behavior in a foreground `.app` bundle.
- [x] Update screenshots or documentation notes after the modern UI direction
  is implemented.

Acceptance:

- The app intentionally targets modern macOS technology instead of preserving
  old OS compatibility.
- Settings and menu bar controls feel like current macOS controls, including
  pointer, pressed, focus, and keyboard behavior.
- Standard SwiftUI controls and system structures are used before custom
  components.
- Custom Liquid Glass surfaces are used for product-specific compositions,
  such as account status clusters or dashboard summaries, and do not duplicate
  standard system controls.
- Settings UI and windowing use SwiftUI-native scene and control APIs.
- Modern visual behavior does not regress the account workflows, refresh
  controls, source configuration, or Settings close/reopen behavior.

Decision:

- AI Limitbar is a modern-only macOS app. Do not optimize UI architecture for
  macOS 14-era compatibility unless that decision is explicitly reopened.
- Liquid Glass and current SwiftUI macOS patterns are the default design
  baseline.
- The project should honor Apple's current controls and interaction work
  instead of recreating hover, click, focus, toolbar, sidebar, or glass behavior
  by hand.
- Implemented with macOS 26 as the deployment baseline, a SwiftPM 6.2 manifest,
  Swift 6 language mode, SwiftUI's native `Settings` scene, a system
  `NavigationSplitView` sidebar, and grouped `Form` sections for account
  settings.
- Removed the controlled AppKit settings window, close observer, text-field
  prewarm, and other Settings window lifecycle bridges.
- URL opening now goes through SwiftUI's `openURL`, and Settings opens through
  `openSettings`. AppKit is limited to the application termination boundary.
- Removed custom hover tint/scale effects; interaction feedback now comes from
  system controls and SwiftUI glass/button behavior.
- Foreground `.app` launch verification passed with `./script/build_and_run.sh --verify`;
  interactive hover/click/focus smoke still needs manual QA or Accessibility
  permission for GUI automation.

## Milestone 12.1: Quality Stabilization Gate

Goal: make the current modern macOS baseline reliable, testable, and maintainable
before starting another provider or product feature milestone.

- [x] Bound the menu bar dashboard and account-details popover by available
  screen space regardless of account or limit-window count.
- [x] Own and cancel account refresh tasks so deleting an account cannot restore
  orphan runtime state or persisted snapshots.
- [x] Validate every adapter result against the requested provider and account
  identity before it reaches app state.
- [x] Preserve unsupported or malformed snapshot documents before writing a new
  current-format document.
- [x] Make refresh retry cancellation cooperative and test it.
- [x] Add a dedicated app test target and cover orchestration for
  refresh, deletion, persistence, ordering, and menu bar summary behavior.
- [x] Remove unused inspector, grouping, selection, and row code left behind by
  the dashboard redesign.
- [x] Restore normal macOS termination behavior through a narrow lifecycle edge.
- [x] Make debug, run, logs, telemetry, and verify modes use the same staged app
  bundle.
- [x] Add explicit accessibility semantics for the menu bar status item and
  icon-only account actions.
- [x] Keep Settings compact and complete the expected Return/Escape keyboard
  flows.
- [x] Align README and architecture documentation with the implemented account,
  snapshot-format, launch, and storage behavior.
- [x] Pass debug and release builds, warnings-as-errors, the full test suite,
  script validation, code-sign validation, and a foreground app smoke test.

Acceptance:

- Valid provider data cannot make primary menu bar actions unreachable.
- Deleting an account while work is in flight leaves no account snapshot,
  refresh status, or persistence residue after the task completes.
- Malformed or newer snapshot formats are preserved before replacement.
- App-facing orchestration has deterministic automated coverage instead of
  relying only on `AILimitBarCore` tests.
- Every development mode exercises the same menu-bar-only `.app` bundle shape.
- The working tree contains no obsolete dashboard predecessor code.
- Documentation describes the live implementation and current quality gate.

Decision:

- Settings behavior across macOS Spaces is explicitly deferred and is not a
  blocker for this stabilization gate.
- The native SwiftUI `Settings` scene and the modern macOS/Liquid Glass direction
  remain in place.
- AppKit may be used only at a narrow platform lifecycle boundary where SwiftUI
  does not expose an equivalent application-termination action.

## Milestone 12.2: Settings Account Master-Detail Redesign

Goal: make Settings feel like a compact native macOS preference window, with
account management modeled after the Accounts pane in system apps.

- [x] Replace the top-level Settings sidebar and tile bar with a compact native
  segmented control for Accounts, Refresh, and Provider Setup; render each
  section below it so the Accounts master-detail sidebar remains local.
- [x] Rebuild Accounts as a master-detail layout: a compact account list on the
  left and selected-account configuration on the right.
- [x] Show account name first and provider name second in the list.
- [x] Add native drag-and-drop reordering; keep Move Up/Down in the row context
  menu as an accessibility fallback.
- [x] Put add/delete controls in the list footer and keep delete confirmation.
- [x] Add a read-only detail state with immediate Enabled control, visible
  Refresh action, Edit button, and overflow menu for Test Connection/Open Usage.
- [x] Add create and edit forms in the detail pane with Save/Cancel behavior.
- [x] Make multi-field account edits persist atomically without changing the
  existing configuration storage format.
- [x] Guard account and section navigation with one discard confirmation that
  appears only after meaningful draft changes.
- [x] Reset the editor session and return to Accounts when Settings closes;
  reopening Settings must not restore an active draft.
- [x] Normalize draft values using the same trimming/default rules as account
  persistence before deciding whether a draft is dirty.
- [x] Add app-model coverage for atomic account edits and multi-row reordering.
- [x] Use system glass icon buttons for account actions, move Refresh All into
  the account-list footer, and keep all Settings pane content on a consistent
  readable width.
- [x] Keep the overflow trigger as a matching glass button while presenting
  its actions through a narrow native `NSMenu` bridge, because the SwiftUI
  Settings toolbar renderer does not expose the Notes-style menu affordance.

Acceptance:

- Settings opens directly to Accounts with a compact segmented section control,
  without a permanent top tile bar.
- Account rows remain compact and preserve the user-defined dashboard order.
- Frequent refresh actions are discoverable; less frequent actions do not crowd
  the account detail header.
- Entering Edit without changing a field does not trigger a discard prompt.
- Closing and reopening Settings shows a clean Accounts state.
- Edit, create, delete, enable/disable, reorder, refresh, connection test, and
  usage-page workflows remain available.

## Milestone 13: Claude Code Data Source

Goal: make Claude Code useful without relying on hand-edited JSON files.

- [x] Define the first supported Claude Code local data source contract.
- [x] Add a helper/import path that writes AI Limitbar local snapshot JSON.
- [x] Validate helper output before storing snapshots.
- [x] Add source diagnostics for missing file, invalid schema, stale helper
  output, and invalid percentage values.
- [x] Document how to configure Claude Code local snapshot updates.
- [x] Avoid parsing Claude interactive screens, private local state, or browser
  pages.

Acceptance:

- [x] Claude Code can produce useful local-estimate data without manually editing
  JSON.
- [x] The source remains clearly labeled as local-estimate, not account-authoritative
  live usage.
- [x] Invalid helper output does not corrupt stored snapshots.

## Milestone 14: Ollama Cloud Web Page Data Source

Goal: add an explicit opt-in, experimental Ollama Cloud source that reads the
authenticated usage page without accessing, copying, or persisting browser
credentials.

- [x] Add an `ollama-web-page` source mode; keep `manual` as the default and
  fallback mode for Ollama Cloud accounts.
- [x] Add a compact `Connect Ollama…` / `Reconnect` flow backed by an
  AI Limitbar-owned `WKWebView`; the user completes sign-in directly with
  Ollama in that view.
- [x] Keep the WebKit session isolated from other browsers and apps. Do not
  read, export, import, log, or write cookies, tokens, passwords, profile data,
  or any browser storage outside WebKit's own managed session.
- [x] Load only `https://ollama.com/settings` after a successful connection and
  add a narrowly scoped user script for that exact origin and path.
- [x] Parse the current server-rendered usage page through semantic text
  anchors, not CSS utility-class names: `Session usage`, `Weekly usage`, their
  used percentages, and reset timestamps.
- [x] Validate the extracted payload in Swift before creating a snapshot:
  required windows must be present, percentages must be in `0...100`, and
  reset values must be valid future dates when supplied.
- [x] Normalize session and weekly values into provider-defined
  `UsageLimitWindow` entries; do not assume the session window has a fixed
  duration or that either page section is permanently available.
- [x] Keep per-model request counts and extra-usage balance out of the initial
  snapshot contract; they are not required to represent the two primary limits.
- [x] Label the source as `Experimental web page` in Settings, details, and
  warnings, including the risk that Ollama may change its authenticated page
  structure without notice.
- [x] Run refreshes only through the configured schedule or explicit user
  action. A refresh must never foreground the login UI, submit account changes,
  or attempt an unattended reauthentication.
- [x] Add clear recovery states for a missing connection, expired session,
  changed page structure, incomplete usage data, load failure, and timeout;
  preserve the last valid snapshot when a refresh fails.
- [x] Discard raw HTML and JavaScript bridge payloads after validation. Do not
  write them to snapshots, diagnostics, logs, tests, or export bundles.
- [x] Add fixture-based parser and adapter tests for both windows, a missing
  window, invalid percentages, stale/expired connection, parser drift, and a
  refresh failure that preserves the prior snapshot.
- [x] Document connection, reconnect, privacy, experimental compatibility, and
  manual-fallback behavior in the README and provider plan.

Acceptance:

- [x] An explicitly connected Ollama account supplies current session and weekly
  limit windows from its settings page without any AI Limitbar-managed
  credential storage.
- [x] The settings and dashboard clearly distinguish this source from an official
  machine-readable usage API and make reconnection actionable.
- [x] A page or session change produces a recoverable warning and retains the last
  valid snapshot instead of inventing or clearing limit values.
- [x] The initial implementation neither parses another browser's session nor
  stores raw page content, cookies, tokens, profile data, model request counts,
  or billing balance.

Decision:

- The current Ollama settings page is account-authenticated and server-rendered;
  no separate usage JSON response was observed during the research check.
- This source is intentionally an experimental DOM integration. Re-evaluate it
  if Ollama publishes a supported account-usage API.
- The user must sign in again through AI Limitbar's own WebKit view. The app
  must never reuse or extract a session from Codex, Safari, Chrome, or another
  browser.

## Milestone 15: Codex App-Server Data Source

Goal: add an opt-in, experimental OpenAI Codex source that reads structured
current CLI rate-limit data without scraping an interactive terminal, browser,
or local session history.

- [ ] Add an `app-server` source mode for OpenAI Codex; keep `manual` as the
  default and fallback mode.
- [ ] Locate an installed `codex` executable without storing authentication
  material, cookies, tokens, or account files.
- [ ] Start `codex app-server --listen stdio://` for one refresh, complete the
  JSON-RPC initialization handshake, and request `account/rateLimits/read`.
- [ ] Normalize `primary` and optional `secondary` rate-limit windows into
  provider-defined `UsageLimitWindow` values; do not assume a weekly window is
  always present.
- [ ] Handle multi-bucket responses defensively and select the Codex limit
  bucket only when it is explicitly identified.
- [ ] Discard raw app-server responses and unneeded account fields, including
  credit balance strings, reset-credit identifiers, and opaque account data.
- [ ] Add diagnostics for a missing CLI, unauthenticated CLI, unsupported or
  changed app-server schema, malformed JSON-RPC responses, timeouts, and
  process-launch failures.
- [ ] Use the configured refresh schedule rather than high-frequency polling;
  terminate the short-lived app-server process after each request.
- [ ] Label the source as experimental in Settings and snapshots, with clear
  compatibility and data-coverage warnings.
- [ ] Add fixture-based tests for current, missing-secondary, multi-bucket,
  malformed, and timeout/error responses without depending on a real account.
- [ ] Document setup, the experimental compatibility boundary, privacy rules,
  and the manual fallback.

Acceptance:

- An authenticated local Codex CLI can supply normalized rate-limit windows to
  an explicitly opted-in OpenAI Codex account.
- Missing windows or unsupported response fields degrade to a useful warning,
  never a fabricated quota value.
- The app never drives `/status` through a PTY and never reads browser content,
  raw Codex session files, or Codex authentication state.
- No credentials, raw app-server payloads, or opaque account identifiers are
  written to AI Limitbar storage or diagnostics.
- A Codex CLI update or unavailable experimental interface leaves the account
  in a clear recoverable state and preserves the manual usage-page workflow.

## Milestone 16: Local Database Migration

Goal: replace the app's JSON persistence and Claude Code snapshot file with one
app-owned SQLite database accessed through GRDB, without losing existing local
state or weakening the current privacy boundary.

- [ ] Add GRDB through Swift Package Manager and make it available to both
  `AILimitBar` and `AILimitBarClaudeStatusLine` through `AILimitBarCore`.
- [ ] Create one non-user-configurable database at
  `~/Library/Application Support/AI Limitbar/AI Limitbar.sqlite` and enable
  WAL mode, foreign-key enforcement, and a bounded busy timeout.
- [ ] Define versioned GRDB migrations for provider accounts, current
  normalized snapshots, refresh settings, and persisted source diagnostics.
  Preserve the current app behavior; history/chart retention is a separate
  feature, not an implicit migration requirement.
- [ ] Enforce one globally unique account display name across all persisted
  accounts, including disabled accounts. Trim leading/trailing whitespace and
  compare names case-insensitively before save; back the rule with a normalized
  database column and a unique constraint rather than UI validation alone.
- [ ] Replace `JSONSnapshotStore`, `ProviderConfigurationStore`, and
  `RefreshSettingsStore` behind focused store protocols so `AppModel` keeps its
  existing account and refresh behavior.
- [ ] Replace Claude Code's generic `local-snapshot` path with an
  AI Limitbar-managed `statusLine` database source. The helper must validate
  and write only the normalized snapshot in a short transaction, even when the
  app is not running.
- [ ] Remove the user-editable local snapshot path from Settings after the
  managed source is available. Existing custom paths must not be silently
  followed forever: import the last valid value once, retain a clear migration
  warning, and guide the user to configure the bundled helper.
- [ ] On first launch, import valid legacy `providers.json`, `snapshots.json`,
  refresh settings, and the managed Claude `statusline.json` into one atomic
  database migration. Preserve the original files as backups and make the
  migration idempotent. If legacy accounts collide after name normalization,
  retain every account by assigning deterministic display-name suffixes such as
  ` (2)` and record an actionable migration warning.
- [ ] Keep malformed, unsupported, or partially importable legacy data from
  replacing valid database rows; surface actionable diagnostics instead.
- [ ] Keep credentials, cookies, WebKit browser data, raw provider responses,
  and opaque account/authentication fields out of the database.
- [ ] Add tests for schema creation/upgrades, concurrent app/helper writes,
  legacy import, idempotency, rollback on failed migration, custom-path
  migration warnings, display-name uniqueness, deterministic legacy-name
  conflict resolution, and preservation of the last valid snapshot.
- [ ] Document the database location, backup/recovery behavior, migration
  result, and the new Claude Code setup flow.

Acceptance:

- A fresh install runs entirely from the GRDB-managed SQLite database and
  requires no user-provided snapshot path.
- Updating Claude Code through the bundled `statusLine` helper remains safe
  while AI Limitbar is closed or reading the same database.
- Existing supported JSON-based installations retain their accounts, refresh
  settings, and latest valid snapshots after one restart; their legacy files
  remain available as backups.
- A failed or malformed legacy import leaves the database usable and never
  destroys a prior valid state.
- The database contains normalized product data only, never credentials or raw
  provider/session material.
- All saved accounts have globally unique display names after migration; a
  legacy naming collision does not discard an account or silently overwrite it.

## Milestone 17: Terminal Dashboard And Details Redesign

Goal: replace the Liquid Glass dashboard cards and account-details presentation
with the approved terminal-fieldset status dashboard, without changing provider,
refresh, or persistence behavior.

Design contract: [`docs/dashboard-design.md`](dashboard-design.md).

- [ ] Replace dashboard glass cards with fieldset-style account panels whose
  border is interrupted by the account name.
- [ ] Truncate a long account legend with a tail ellipsis without displacing
  Refresh or Info controls, and expose the complete name in a tooltip and its
  accessibility label.
- [ ] Render one `NN% used` value, one progress bar, and a relative reset label
  per known limit window; do not show normal-state update timestamps or a
  duplicate remaining percentage.
- [ ] Move Refresh All to a glyph control in the menu-panel header and show its
  in-progress/disabled state.
- [ ] Add glyph-only individual Refresh and explicit Info controls to every
  account panel, using the existing per-account refresh and details paths.
- [ ] Keep stale, failed, manual-only, unavailable, and no-data states visible
  inline without inventing usage values or permanently occupying normal cards.
- [ ] Redesign `AccountDetailsView` as the matching technical inspector with
  precise timestamps, source, confidence, resets, diagnostics, and secondary
  actions.
- [ ] Remove dashboard and account-details Liquid Glass treatments, including
  glass buttons and glass/card hover behavior, while preserving accessible
  system control semantics.
- [ ] Add or update focused tests for refresh action availability and preserve
  existing refresh/account ordering behavior.
- [ ] Manually verify normal, refreshing, stale, failed, manual-only, and
  no-data examples in Light and Dark appearance.

Acceptance:

- The main menu panel is readable as an all-account usage dashboard without
  opening details.
- Normal cards show only account identity, usage, reset information, and
  necessary exception states.
- Refresh All, individual Refresh, and Info are discoverable and do not overlap
  or lose keyboard/accessibility support.
- The details popover holds timestamps and diagnostics without duplicating the
  dashboard or individual Refresh action.
- No provider, refresh, snapshot, or persistence contract changes are required
  solely for the visual redesign.

## Milestone 18: Provider And Account Readiness

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

## Milestone 19: Daily Use Polish

Goal: make the menu bar app useful as a daily status tool before starting the
WidgetKit extension.

- [ ] Improve menu bar summary title and icon based on worst account state.
- [ ] Add option to hide manual-only accounts from the main list.
- [ ] Add export/debug bundle without secrets.
- [ ] Add smoke verification for app launch, refresh, settings persistence, and
  snapshot persistence.
- [ ] Adapt Ollama-owned settings and sign-in pages in the isolated WebKit view
  to the effective macOS appearance with a separate visual-only `WKUserScript`.
  Change only colors, backgrounds, borders, text contrast, and color scheme;
  preserve page behavior, usage extraction, and the normalized bridge payload.
- [ ] Apply the Ollama visual stylesheet only to `ollama.com` and
  `signin.ollama.com`; leave WorkOS, Google, GitHub, and other third-party OAuth
  pages provider-controlled.

Acceptance:

- The menu bar item surfaces the most important account state at a glance.
- The panel remains usable with multiple providers and accounts.
- Debug output helps diagnose issues without leaking credentials or raw provider
  responses.
- Ollama-owned pages follow the active appearance without disrupting sign-in,
  navigation, keyboard focus, form controls, or usage parsing.

## Milestone 20: App Localization And General Settings

Goal: ship an English-first app with Russian localization and a compact
Settings organization where cross-account preferences live in General.

- [ ] Declare English as the Swift package's default localization and add
  English and Russian localized app resources. Ensure the custom app-bundle
  script stages the resources in `AILimitBar.app` instead of copying only
  binaries.
- [ ] Add a durable `AppLanguage` preference with `System Default`, `English`,
  and `Russian` choices. Render the native language `Picker` in a new General
  Settings section and apply a selection immediately to the menu bar panel,
  Settings window, alerts, accessibility text, and formatted values without a
  restart.
- [ ] Replace the current Settings navigation with General, Accounts, and
  Provider Setup. Move the refresh-schedule control and its explanatory copy
  into General; remove Refresh as a top-level Settings section without changing
  the persisted refresh setting or refresh behavior.
- [ ] Localize all app-owned, user-facing UI text, including dashboard labels,
  Settings, buttons, alerts, tooltips, accessibility labels and values, empty
  states, status text, and app-generated warnings or recovery instructions.
- [ ] Resolve dynamic app-owned strings at presentation time using the selected
  locale. Do not persist translated output or translate provider IDs, raw
  provider content, account names, JSON keys, file paths, or other technical
  identifiers.
- [ ] Replace hardcoded formatter locales with the effective app locale so
  dates, relative dates, numbers, and percentages follow the selected language.
- [ ] Add automated checks for English/Russian key parity, English fallback,
  language-preference persistence, immediate locale updates, and preservation
  of the refresh schedule. Manually verify the staged app in English and
  Russian, including long Settings labels and all dashboard states.
- [ ] Document the language choices, the System Default behavior, and the
  localization maintenance rule: every new app-owned user-facing string must
  ship with both English and Russian translations.

Acceptance:

- A user can select System Default, English, or Russian from General, and the
  visible app changes immediately without relaunching.
- English is the complete fallback language. A missing Russian translation
  cannot expose a raw localization key or make the interface unusable.
- General contains language and refresh schedule; Accounts and Provider Setup
  remain focused on their existing workflows, and refresh scheduling works
  exactly as before.
- User-created names, provider data, and persisted technical values stay intact
  when the language changes; only the app's presentation is localized.
- `dist/AILimitBar.app` contains and loads both localizations after the normal
  build-and-run workflow.

## Milestone 21: Per-Limit Usage Thresholds

Goal: let users define global warning and critical usage thresholds, then
override the pair for individual provider-defined limit windows without adding
provider- or account-wide inheritance layers.

- [ ] Add durable global `Warning` and `Critical` integer percentage defaults
  (`75` and `90` on a fresh install). Validate `1...100` values and require
  `Warning < Critical` at every write boundary.
- [ ] Add a versioned storage migration and focused store API for per-window
  overrides. Key each override by the saved account identifier and a stable
  provider-owned limit-window identifier; never by a localized label, display
  order, or a reset timestamp.
- [ ] Resolve effective thresholds as either the global pair or one complete
  per-window pair. Do not introduce provider-wide or account-wide defaults.
  New windows use global values, and overrides survive a temporarily missing
  snapshot window.
- [ ] Require adapters to expose a stable identifier before their windows can
  be individually configured. Keep an existing override visible and clearly
  marked when its window is not present in the latest snapshot; do not create
  overrides for unknown windows.
- [ ] Add a localized Thresholds section to General for global defaults, and a
  localized Limits section in the selected account's Settings detail. Each
  known window must show its effective values and a `Use global thresholds`
  control that creates or removes its override without changing the global
  settings.
- [ ] Derive `normal`, `warning`, and `critical` state per window from its
  effective thresholds and `usedPercent`. Surface the worst enabled-account
  state in the dashboard and menu-bar summary without fabricating state for
  manual-only, unavailable, or no-data windows.
- [ ] Deliver a local notification only on a newly crossed threshold when the
  user has granted notification permission. Persist enough non-sensitive
  crossing/reset-cycle state to prevent duplicate alerts across scheduled
  refreshes and app relaunches; if both levels are crossed together, notify
  only for `Critical`.
- [ ] Re-arm notifications only after usage drops below the warning threshold
  or the provider reports a newer reset cycle. Applying changed threshold
  settings must refresh the visible severity immediately but must not itself
  send a notification.
- [ ] Add tests for validation, global fallback, override creation/removal,
  stable-key matching, temporary window absence, severity resolution, worst
  account state, one-time crossing delivery, re-arming, relaunch deduplication,
  simultaneous warning/critical crossing, and notification-permission denial.
- [ ] Manually verify English and Russian Settings flows, per-window dashboard
  severity, and the resulting menu-bar/notification behavior with multiple
  accounts and limit windows.

Acceptance:

- A user can set one global warning/critical pair and selectively replace it
  for any reported limit window with a stable provider identifier.
- Changing global values immediately updates every non-overridden window;
  changing an override affects only that account-window.
- An overridden window retains its configuration across refreshes, relaunches,
  and transient provider responses that omit it.
- The dashboard accurately shows normal/warning/critical severity from the
  resolved thresholds, and its summary reflects the worst enabled account
  without changing the reported usage percentage.
- A sustained value above a threshold cannot spam notifications during refresh
  or after relaunch, while a genuine new usage/reset cycle can notify again.
- All new app-owned strings are localized in English and Russian; provider
  labels and identifiers remain provider data rather than translated storage
  keys.

## Later

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
