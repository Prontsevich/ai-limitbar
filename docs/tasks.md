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

Historical note: Milestone 18 plans to supersede the native `Settings` scene
decision after daily use exposed unresolved activation, key-window, placement,
and Spaces behavior in the menu-bar-only `LSUIElement` app. The replacement
remains SwiftUI-owned and adds only a narrow application-activation boundary.

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
  remain in place for this stabilization gate. Milestone 18 later revisits the
  scene choice without returning Settings ownership to AppKit.
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
- [x] Label the source as `Experimental web page` in Settings and details,
  including the risk that Ollama may change its authenticated page structure
  without notice; a successful experimental read remains `OK`.
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

- [x] Add an `app-server` source mode for OpenAI Codex; keep `manual` as the
  default and fallback mode.
- [x] Locate an installed `codex` executable without storing authentication
  material, cookies, tokens, or account files.
- [x] Start `codex app-server --listen stdio://` for one refresh, complete the
  JSON-RPC initialization handshake, and request `account/rateLimits/read`.
- [x] Normalize `primary` and optional `secondary` rate-limit windows into
  provider-defined `UsageLimitWindow` values; do not assume a weekly window is
  always present.
- [x] Handle multi-bucket responses defensively and select the Codex limit
  bucket only when it is explicitly identified.
- [x] Discard raw app-server responses and unneeded account fields, including
  credit balance strings, reset-credit identifiers, and opaque account data.
- [x] Add diagnostics for a missing CLI, unauthenticated CLI, unsupported or
  changed app-server schema, malformed JSON-RPC responses, timeouts, and
  process-launch failures.
- [x] Use the configured refresh schedule rather than high-frequency polling;
  terminate the short-lived app-server process after each request.
- [x] Label the source as experimental in Settings and snapshots, with clear
  compatibility and data-coverage context; a successful experimental read
  remains `OK`.
- [x] Add fixture-based tests for current, missing-secondary, multi-bucket,
  malformed, and timeout/error responses without depending on a real account.
- [x] Document setup, the experimental compatibility boundary, privacy rules,
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

- [x] Add GRDB through Swift Package Manager and make it available to both
  `AILimitBar` and `AILimitBarClaudeStatusLine` through `AILimitBarCore`.
- [x] Create one non-user-configurable database at
  `~/Library/Application Support/AI Limitbar/AI Limitbar.sqlite` and enable
  WAL mode, foreign-key enforcement, and a bounded busy timeout.
- [x] Define versioned GRDB migrations for provider accounts, current
  normalized snapshots, refresh settings, and persisted source diagnostics.
  Preserve the current app behavior; history/chart retention is a separate
  feature, not an implicit migration requirement.
- [x] Enforce one globally unique account display name across all persisted
  accounts, including disabled accounts. Trim leading/trailing whitespace and
  compare names case-insensitively before save; back the rule with a normalized
  database column and a unique constraint rather than UI validation alone.
- [x] Replace `JSONSnapshotStore`, `ProviderConfigurationStore`, and
  `RefreshSettingsStore` behind focused store protocols so `AppModel` keeps its
  existing account and refresh behavior.
- [x] Replace Claude Code's generic `local-snapshot` path with an
  AI Limitbar-managed `statusLine` database source. The helper must validate
  and write only the normalized snapshot in a short transaction, even when the
  app is not running.
- [x] Remove the user-editable local snapshot path from Settings after the
  managed source is available. Existing custom paths must not be silently
  followed forever: import the last valid value once, retain a clear migration
  warning, and guide the user to configure the bundled helper.
- [x] On first launch, import valid legacy `providers.json`, `snapshots.json`,
  refresh settings, and the managed Claude `statusline.json` into one atomic
  database migration. Preserve the original files as backups and make the
  migration idempotent. If legacy accounts collide after name normalization,
  retain every account by assigning deterministic display-name suffixes such as
  ` (2)` and record an actionable migration warning.
- [x] Keep malformed, unsupported, or partially importable legacy data from
  replacing valid database rows; surface actionable diagnostics instead.
- [x] Keep credentials, cookies, WebKit browser data, raw provider responses,
  and opaque account/authentication fields out of the database.
- [x] Add tests for schema creation/upgrades, concurrent app/helper writes,
  legacy import, idempotency, rollback on failed migration, custom-path
  migration warnings, display-name uniqueness, deterministic legacy-name
  conflict resolution, and preservation of the last valid snapshot.
- [x] Document the database location, backup/recovery behavior, migration
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

- [x] Replace dashboard glass cards with fieldset-style account panels whose
  border is interrupted by the account name.
- [x] Truncate a long account legend with a tail ellipsis without displacing
  Refresh or Info controls, and expose the complete name in a tooltip and its
  accessibility label.
- [x] Render one `NN% used` value, one compact outlined usage meter, and a relative reset label
  per known limit window; do not show normal-state update timestamps or a
  duplicate remaining percentage.
- [x] Move Refresh All to a glyph control in the menu-panel header and show its
  in-progress/disabled state.
- [x] Add glyph-only individual Refresh and explicit Info controls to every
  account panel, using the existing per-account refresh and details paths.
- [x] Keep stale, failed, manual-only, unavailable, and no-data states visible
  inline without inventing usage values or permanently occupying normal cards.
- [x] Redesign `AccountDetailsView` as the matching technical inspector with
  precise timestamps, source, confidence, resets, diagnostics, and secondary
  actions.
- [x] Remove dashboard and account-details Liquid Glass treatments, including
  glass buttons and glass/card hover behavior, while preserving accessible
  system control semantics.
- [x] Apply the approved Codex `/status` and lazygit visual grammar: adaptive
  terminal palette, monospaced hierarchy, thin outlined custom usage meters,
  flat actions, and one label/value details inspector with a nested diagnostics
  note.
- [x] Add or update focused tests for refresh action availability and preserve
  existing refresh/account ordering behavior.
- [x] Add persisted device-local Compact (320 pt), Standard (460 pt), and Tall
  (640 pt) dashboard-height presets; retain a scrolling viewport for overflow.
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
- The selected dashboard-height preset persists between launches, changes the
  scroll viewport immediately, and leaves short account lists naturally sized.
- No provider, refresh, snapshot, or persistence contract changes are required
  solely for the visual redesign.

## Milestone 18: Settings Window Lifecycle And Terminal-Adjacent Redesign

Goal: replace the system-managed Settings presentation with a predictable
singleton SwiftUI window, then align the Settings workspace with the approved
terminal-fieldset product language and one consistent interactive control layer.

Design contract: [`docs/settings-design.md`](settings-design.md).

- [x] Replace the SwiftUI `Settings` scene and `SettingsLink` entry point with a
  singleton `Window("AI Limitbar Settings", id: "settings")` scene opened through
  `openWindow(id:)`.
- [x] Add one narrow application-activation boundary that calls the current
  `NSApplication.activate()` API in direct response to the Settings action before
  opening the SwiftUI window. Do not restore an AppKit-owned `NSWindowController`
  or use deprecated focus-stealing APIs.
- [x] Keep the staged app `LSUIElement` and menu-bar-only. Opening Settings must
  make the app active and the Settings window key without adding a Dock icon,
  changing the normal activation policy, or making the window float above other
  apps.
- [x] Disable the native minimize, resize, and full-screen controls while
  preserving close. A menu-bar utility Settings window is closed to dismiss it
  rather than minimized to the Dock or expanded into a primary app window.
- [x] Make the Settings scene singleton: reopening an existing window brings it
  forward instead of creating a duplicate or repositioning it. A closed or
  hidden window is centered again on the display hosting the new Settings action.
- [x] Define a deterministic default size and center new Settings windows on the
  display that hosts the menu-bar panel when the Settings action is invoked,
  using the pointer display and then the active/default visible display only as
  fallbacks. After creation, use the real window frame to center it in that
  display's visible bounds.
  Respect the user's move and resize choices while that window remains open,
  including multi-display setups.
- [x] Disable unwanted restoration for the Settings scene so a closed window does
  not reappear during launch or Spaces changes. Closing and reopening must reset
  transient editor, pending-navigation, alert, and section-selection state.
- [x] Preserve the current Accounts, Refresh, and Provider Setup information
  architecture for this milestone. Leave the planned General-section
  reorganization to Milestone 23 so lifecycle and visual work do not absorb
  localization or preference-model changes.
- [x] Restyle Settings as terminal-adjacent rather than as a literal terminal:
  reuse compact spacing, thin fieldset borders, restrained semantic status color,
  and a monospaced text hierarchy. Terminal selectors, sidebar selection,
  toggles, and actions share visible hover/pressed feedback; native editing,
  dialogs, menus, and focus behavior remain intact.
- [x] Remove opaque sidebar/list backgrounds and decorative glass treatments that
  fight the new composition. Keep system-adaptive Light and Dark appearances and
  do not introduce the custom theme-token model planned for Milestone 26.
- [x] Hide the non-actionable Credentials placeholder from Provider Setup until a
  verified provider integration needs an actual credential workflow.
- [x] Replace the account create/edit `Form` column layout with top-aligned
  `ACCOUNT` and `SOURCE` terminal fieldsets while preserving text editing, file
  import, validation, Save/Cancel, Return, and Escape.
- [x] Replace the account editor's system Provider popup and text-field focus
  ring with a keyboard-accessible terminal provider selector, a terminal focus
  border, and a square-cornered, scrollable provider overlay without a decorative
  title. Space/Return opens the selector, arrows move its list focus, Tab enters
  and traverses its items, and Escape closes it. Hide a provider that cannot
  accept another account, and hide the redundant source fieldset for providers
  with no configurable source.
- [x] Remove `Manual` as a real-provider Create/Edit source. New and saved real
  accounts use the provider's single current source; `Manual` remains only for
  the built-in Mock provider.
- [x] Preserve add, edit, delete, enable/disable, reorder, refresh, connection,
  usage-page, configured-source, helper-install, Save/Cancel, and dirty-draft
  workflows without changing refresh, persistence, or snapshot contracts.
- [x] Manually verify opening from behind another app, repeated open, close/reopen,
  active selection accent, keyboard focus, dirty drafts, Light/Dark appearance,
  multiple Spaces, and multiple displays in the staged `.app` bundle.

Acceptance:

- Every explicit Settings action opens one active, key Settings window in a
  predictable location; an already open window comes forward without duplication.
- Closing Settings prevents spontaneous reappearance and reopening starts from a
  clean Accounts state without stale editor or confirmation UI.
- Active selectors, selection, toggles, and actions use the terminal palette with
  visible hover/pressed feedback; the implementation does not use system-blue
  selection or a mixed control style.
- Every selector segment has a compact fixed height and responds across its full
  bordered cell, not only over its label.
- Account creation and editing remain top-aligned and readable at the normal
  Settings window size; labels, source selectors, and validation do not clip or
  overlap one another.
- Provider choices, text-field focus, and action hover feedback use the terminal
  palette without system-blue popup or focus styling.
- Settings is recognizably related to the terminal-fieldset dashboard while still
  behaving like a native macOS configuration workspace in Light and Dark modes.
- The redesign changes windowing and presentation only; existing account and
  provider workflows and their storage contracts remain intact.

## Milestone 19: Claude Code `/usage` CLI Data Source

Goal: add an explicit opt-in experimental Claude Code source that actively
reads current subscription plan limits through the local non-interactive CLI,
including model-specific weekly limits such as Fable, without driving a PTY,
running a model turn, or replacing the existing managed `statusLine` source.

- [x] Add a `claude-usage-cli` provider source mode for Claude Code. Keep
  `manual` and `claude-status-line` available, preserve the current default,
  and label `/usage` CLI as informational `Experimental` rather than a warning
  after a successful read.
- [x] Allow only one saved Claude Code account to use `/usage` CLI at a time,
  because the launched process reads the identity currently authenticated in
  that CLI environment. Keep managed `statusLine` available for explicitly
  configured multi-account snapshots.
- [x] Add automatic Claude executable discovery plus an optional saved
  executable override. Reuse a provider-neutral executable-path model instead
  of placing Claude paths in the existing Codex-specific field; migrate the
  current Codex value without changing Codex behavior.
- [x] Add a bounded, cancellable process client that launches the selected
  executable with `--safe-mode`, `-p "/usage"`, `--output-format json`,
  `--tools ""`, and `--no-session-persistence`, while forcing UTC and an English
  POSIX-compatible locale. Apply a short timeout and stdout size limit,
  terminate the child on cancellation, and do not expose stderr or raw command
  output through logs or diagnostics.
- [x] Decode the CLI JSON result envelope before parsing usage text. Accept
  only a successful built-in command response with zero model turns, zero
  model-token usage, and zero reported model cost; reject unsupported versions,
  authentication failures, inference activity, malformed envelopes, and
  oversized responses.
- [x] Parse only recognized plan-limit lines from the in-memory `result` text:
  `Current session`, `Current week (all models)`, and generic
  `Current week (<model>)` entries. Ignore session-cost details, activity
  attribution, skills, subagents, MCP servers, request counts, and every other
  local-history breakdown.
- [x] Normalize the recognized values into stable `UsageLimitWindow` entries:
  `session`, `weekly-all`, and provider-derived model IDs such as
  `weekly-fable`. Preserve provider display labels while keeping stored IDs
  locale-independent and collision-safe.
- [x] Parse UTC weekly reset timestamps with and without minutes and across year
  boundaries. Preserve the verified `Current session` value with no fabricated
  reset when Claude Code omits it. Reject percentages outside `0...100`,
  unparseable supplied reset values, duplicate required windows, and responses
  with no usable plan limits.
- [x] Produce a normalized live snapshot with the experimental Claude Code
  `/usage` source label. A successful read remains `OK` unless normal usage
  thresholds require another status; parser compatibility is represented by
  the source-mode label and diagnostics, not by forcing every valid snapshot
  into Warning.
- [x] Preserve the last valid snapshot when the executable is missing, the CLI
  is unauthenticated, `/usage` is unavailable, the text format changes, reset
  parsing fails, the process times out, or cancellation occurs. Surface a
  sanitized actionable recovery message and keep Manual and managed
  `statusLine` as selectable fallbacks.
- [x] Add compact Settings support for the new source: optional Claude
  executable path, automatic-location help, Browse, source conflict feedback,
  and connection testing. Do not show the statusLine helper installer when
  `/usage` CLI is selected.
- [x] Add fixture-based parser and process-client tests for the verified Claude
  Code `2.1.207` result, no-minute reset times, year rollover, generic
  model-specific windows, absent Fable, API-key/session-only output, malformed
  JSON, non-zero inference metadata, unsupported CLI output, timeout,
  cancellation, response limits, executable discovery, account conflicts, and
  last-valid-snapshot preservation.
- [x] Document setup, the authenticated-CLI identity boundary, the distinction
  between account-wide plan bars and machine-local activity attribution, the
  experimental text-compatibility boundary, privacy rules, diagnostics, and
  fallback behavior in `docs/plan.md`, the provider docs, and README.
- [x] Manually verify the staged app against an authenticated Claude Code CLI:
  confirm session, all-model weekly, and Fable weekly windows; confirm reset
  times where supplied, the verified session-without-reset behavior, refresh
  scheduling, connection testing, relaunch persistence, format failure recovery,
  zero model turns/cost/tokens, and no raw payloads in SQLite or logs.

Acceptance:

- An explicitly opted-in Claude Code account can refresh current session,
  all-model weekly, and available model-specific weekly plan limits through the
  authenticated local CLI without opening an interactive terminal.
- A successful refresh performs no model turn, exposes no tools, creates no
  persisted Claude session, and stores only the normalized `UsageSnapshot` in
  AI Limitbar's database.
- Machine-local activity attribution from `/usage` is never presented as an
  account-wide quota value or retained in storage or diagnostics.
- A Claude CLI or text-format change fails closed, preserves the last valid
  snapshot, and leaves Manual and managed `statusLine` immediately available.
- The experimental source is `OK` after a valid read, while its compatibility
  boundary remains visible without turning the informational Experimental label
  into a false health warning.
- Only one `/usage` CLI account can claim the active local CLI identity; other
  Claude accounts remain configurable through Manual or managed `statusLine`.

## Milestone 20: GitHub Release Distribution

Goal: let people download and run a tested AI Limitbar `.app` from GitHub
Releases without building from source, while keeping the initial ad-hoc-signed,
non-notarized distribution path honest about macOS Gatekeeper warnings.

Implementation status (2026-07-14): local Apple Silicon packaging, archive
round-trip validation, 111 automated tests, staged-app smoke verification, the
manual GitHub Actions run, the first published release, and outside-build
artifact verification are complete.

- [x] Add one reproducible release-packaging script that builds the SwiftPM
  products, stages the complete `AILimitBar.app` bundle (including the bundled
  Claude Code helper, selected AppIcon asset, and localized resources), signs
  the bundle ad-hoc, and creates `AILimitBar-<version>.zip` with
  `ditto --keepParent`.
- [x] Give the staged bundle explicit `CFBundleShortVersionString` and
  `CFBundleVersion` values derived from the release version, without changing
  the existing local build-and-run workflow.
- [x] Add a GitHub Actions release workflow with a manual package-validation
  path and a version-tag publication path. Use the Apple Silicon `macos-26`
  runner, run `swift test`, create the release ZIP, and verify the app bundle
  before publication.
- [x] Configure only the publication job with the required `contents: write`
  permission to create a GitHub Release and upload the ZIP. Keep the workflow
  free of Apple-signing credentials, tokens, and other secrets in this first
  distribution milestone.
- [x] Publish the archive as `AILimitBar-<version>.zip` on the matching GitHub
  Release, with generated or maintained release notes that state the version
  and macOS 26+ / Apple Silicon requirement.
- [x] Document the tag-to-release procedure and installation path: download the
  ZIP, unpack it, move `AILimitBar.app` to Applications, and use the standard
  macOS Gatekeeper recovery action on first launch when required.
- [x] State plainly in release documentation that ad-hoc signing is not
  Developer ID signing or Apple notarization; do not describe this first path
  as trusted, notarized, or warning-free.
- [x] Add the promised MIT license before the first tagged release.
- [x] Verify one published release artifact by downloading it outside the build
  directory, inspecting the archive contents and bundle version, checking the
  ad-hoc code signature, and manually launching it on macOS 26.

Acceptance:

- Pushing one version tag creates a GitHub Release with exactly one custom
  `AILimitBar-<version>.zip` application archive and no source build is needed
  by the downloader.
- The archive expands directly to `AILimitBar.app`, whose main executable,
  bundled helper, resources, and version metadata are present and valid.
- The workflow fails before publication when tests, staging, archive creation,
  or code-sign verification fails.
- The documented first-run Gatekeeper behavior and the absence of notarization
  are clear to a downloader.

## Milestone 21: Provider And Account Readiness

Goal: prepare the app for more providers, multi-account identity mappings, and
clear account/source readiness diagnostics while keeping provider
implementations conservative and requiring evidence before adding authenticated
web sources.

- [x] Add provider/account source diagnostics model.
- [x] Track last successful refresh separately from failed refresh attempts.
- [x] Improve error copy for missing connections, unsupported source modes, and
  unavailable provider APIs.
- [x] Add provider capability metadata for manual, local snapshot, live, and
  delayed modes.
- [ ] Run an authenticated multi-account web-source research gate for Claude and
  OpenAI Codex before adding either provider to the existing Ollama WebKit
  implementation. Treat Claude and Codex as independent feasibility decisions;
  success for one provider must not imply support for the other.
- [ ] For each provider and available account type, verify the actual usage
  surface, resolved URL and navigation flow, visible plan-limit and credit data,
  reset semantics, localization behavior, and whether the page exposes useful
  account-wide values beyond the existing Claude `statusLine` / `/usage` CLI and
  Codex app-server sources.
- [ ] Verify interactive authentication inside an AI Limitbar-owned `WKWebView`,
  including the login methods available to the test account, MFA or passkey
  behavior when encountered, expected OAuth/SSO redirects, session restoration
  after relaunch, explicit reconnect, and clean failure when embedded sign-in is
  rejected or challenged.
- [ ] Verify that two saved accounts of the same provider can use distinct
  persistent `WKWebsiteDataStore` identifiers without sharing authentication,
  navigation state, extracted values, or reconnect lifecycle. Never import or
  reuse a session from Safari, Chrome, Codex, Claude Desktop, or another app.
- [ ] Inspect candidate data shapes without committing to an extractor first.
  Prefer, in order, a documented provider API, a documented structured local
  interface, and semantic DOM extraction. Treat an internal/private JSON request
  as a separate architecture and privacy decision rather than an automatic
  fallback when DOM parsing is inconvenient.
- [ ] Use a minimal non-production WebKit probe when necessary to validate real
  macOS behavior. Do not add a production source mode, generalize the Ollama
  controller, or retain a speculative parser until the provider passes the
  research gate.
- [ ] Keep research artifacts privacy-safe: do not record passwords, tokens,
  cookies, browser storage, raw HTML, complete network responses, profile data,
  opaque account identifiers, or unredacted screenshots. Persist only sanitized
  findings needed to reproduce the capability decision.
- [ ] Record one evidence-backed outcome for each provider: `documented-interface`,
  `semantic-dom`, `private-integration-decision`, `embedded-auth-blocked`,
  `no-additional-value`, or `not-feasible`. Document supported account types,
  missing coverage, compatibility risks, and the manual/current-source fallback.
- [ ] If a provider passes the gate, create a separate implementation milestone
  with its confirmed URL, authentication boundary, extraction method, typed
  payload, navigation allowlist, reconnect behavior, multi-account contract,
  fixtures, and manual verification plan. Do not silently expand Milestone 21
  from research/readiness into production web scraping.

Acceptance:

- The app can explain why each account is or is not refreshable.
- Provider adapters can advertise supported source modes.
- Claude and Codex each have an independently documented feasibility result
  backed by an authenticated WebKit check rather than an assumed page shape or
  login flow.
- Multi-account web isolation is either demonstrated with separate persistent
  WebKit stores or recorded as a blocker; no supported design shares one browser
  identity across saved accounts.
- The research identifies whether a web source adds useful data beyond current
  structured/local sources and selects no private integration by default.
- A positive result produces a separate implementation milestone; a negative or
  blocked result leaves the current source and manual fallback intact without
  speculative production code.
- Research notes and diagnostics contain no credentials, cookies, raw pages,
  private responses, opaque account identifiers, or other browser-session data.

## Milestone 22.1: Menu Bar Status Indicator

Goal: make warning and error state recognizable at the real menu-bar icon size
without adding visible text or encoding state in tiny gauge-needle variants.

- [x] Keep one neutral image-only base icon for the `NSStatusItem`. Do not
  add a visible title, percentage, account name, or other status text to the
  menu bar.
- [x] Overlay one small circular badge in the icon's upper-right corner: red
  when any enabled account has a refresh failure or error snapshot, yellow when
  there is no error and at least one enabled account has a warning snapshot,
  and no badge otherwise. Red takes precedence over yellow.
- [x] Ignore disabled accounts when resolving the badge. Refreshing, stale,
  unavailable, no-data, and ordinary Mock state do not create a badge unless
  the account also has an explicit warning or error.
- [x] Keep explicit accessibility label and value text for the image-only status
  item so badge color is not the sole representation of warning or error state.
- [x] Add focused tests for normal, warning, error, mixed-state priority, and
  disabled-account cases.
- [ ] Manually verify the staged app at the real menu-bar size in Light and Dark
  appearance, including inactive menu-bar presentation.

Implementation status (2026-07-14): the `NSStatusItem` uses one composite,
non-template image with a neutral gauge base and a state badge. Enabled-account
state aggregation, accessibility text, and focused AppModel/renderer tests are
complete. Staged-app visual verification remains pending.

Acceptance:

- The neutral base icon remains recognizable and does not change its gauge
  needle to communicate state.
- A warning produces one clearly visible yellow badge, an error produces one
  clearly visible red badge, and red wins when both states exist.
- Normal state has no badge, and the menu-bar panel itself is unchanged.
- VoiceOver exposes the same state without depending on badge color.

## Milestone 22.2: Daily-Use Smoke Verification

Goal: provide one repeatable verification command for app launch, refresh, and
the persistence paths needed for normal daily use.

- [x] Add one deterministic app-layer integration smoke test that uses a fake
  provider and disposable storage to create an account, change the refresh
  schedule, perform a refresh, persist a normalized snapshot, recreate
  `AppModel`, and verify that the account, settings, and snapshot reload.
- [x] Keep `./script/build_and_run.sh --verify` as the public smoke entrypoint.
  It runs the deterministic integration check, stages the normal debug `.app`
  bundle, launches it through Launch Services, waits for the `AILimitBar`
  process, and fails when the process cannot start or exits immediately.
- [x] Give the automated smoke path disposable storage. It must not read or
  write the user's normal Application Support database, Keychain, WebKit data,
  provider CLIs, or network sources.
- [x] Terminate only the smoke-launched process after verification and leave the
  staged bundle available for manual QA. Keep interactive menu-bar, Settings,
  focus, and pointer checks documented as manual verification rather than
  claiming that process launch proves them.

Implementation status (2026-07-15): the app-layer test uses a fixed fake
provider snapshot and disposable GRDB storage. `--verify` runs that test before
staging, launches the staged bundle through Launch Services with a disposable
storage-directory argument, verifies a new process remains alive, and cleans up
only that process and its temporary storage. Full automated verification passed;
interactive menu-bar, Settings, focus, and pointer checks remain manual.

Acceptance:

- One documented command verifies deterministic refresh, account and refresh
  settings persistence,
  snapshot persistence, bundle staging, and foreground app launch.
- The command is repeatable and leaves no account, snapshot, refresh status,
  process, or persistence residue in the user's real app data.
- A successful process launch is reported separately from manual UI verification.

## Milestone 22.3: Ollama-Owned Web Appearance

Goal: make Ollama-owned settings and sign-in pages follow the effective macOS
appearance without changing authentication, navigation, or usage extraction.

- [x] Add a separate visual-only `WKUserScript` for the isolated Ollama WebKit
  session. It may change only colors, backgrounds, borders, text contrast, and
  the page `color-scheme`; it must not alter layout, visibility, controls,
  focus, submission, navigation, or page content.
- [x] Apply the visual stylesheet only when the exact HTTPS host is
  `ollama.com` or `signin.ollama.com`. WorkOS, Google, GitHub, and every other
  third-party OAuth page remain provider-controlled.
- [x] Keep the visual script independent from the existing usage-extraction
  script and normalized bridge payload. Appearance changes must not trigger,
  suppress, or rewrite usage extraction.
- [x] Apply the current effective Light or Dark appearance when an Ollama-owned
  page loads and when the effective appearance changes while the page remains
  open.
- [x] Add focused tests for host allowlisting and visual/extraction separation.
- [ ] Manually verify settings, Ollama sign-in, third-party OAuth redirects,
  keyboard focus, form controls, navigation, and usage parsing in Light and
  Dark appearance.

Implementation status (2026-07-15): a main-frame, document-start visual script
uses an isolated WebKit client content world and an exact-origin guard for
`https://ollama.com` and `https://signin.ollama.com`. Its adaptive Radix color
tokens follow `prefers-color-scheme`; the separate settings-only usage bridge is
unchanged. `swift build`, `swift test`, and `./script/build_and_run.sh --verify`
passed. Authenticated interactive visual verification remains pending.

Acceptance:

- Ollama-owned settings and sign-in pages remain readable in the active Light
  or Dark appearance.
- No visual stylesheet reaches WorkOS, Google, GitHub, or another third-party
  page.
- Sign-in, navigation, keyboard focus, form submission, and normalized usage
  parsing behave exactly as before the visual adaptation.

## Milestone 22.4: About AI Limitbar

Goal: provide a compact, discoverable source of app identity, build metadata,
and project-support links without expanding Settings or touching provider data.

- [x] Add an `About` text action beside `Settings` in the menu-bar panel footer.
  Keep the existing compact terminal text-action style, `Quit` alignment, and an
  explicit `About AI Limitbar` help/accessibility label.
- [x] Present one fixed-size, non-restoring `About AI Limitbar` utility window.
  It activates the `LSUIElement` app, reuses and foregrounds an open window,
  centers a newly reopened window on the display that received the menu-bar
  action, and leaves only the native Close control available.
- [x] Show the bundled app icon, app name, and `Version <version> (build
  <build>)` from `CFBundleShortVersionString` / `CFBundleVersion`. If either
  release value is absent, show `Development build` rather than an empty or
  misleading version.
- [x] Add static, accessible external links to the GitHub project and the
  existing Boosty support page. Keep the README Boosty badge unchanged.
- [x] Keep About independent of `AppModel`, provider state, SQLite, Keychain,
  diagnostics, and persisted preferences.
- [x] Add unit coverage for release/development build text and both link URLs.
- [x] Manually verify the staged app: footer layout, accessibility, first open,
  repeated open, close/reopen, version fallback, and both external links.

Implementation status (2026-07-15): `swift build`, 133-test `swift test`, the
staged-app `--verify` smoke check, local release-package metadata validation,
and manual About UI verification passed.

Acceptance:

- A user can open About directly from the menu-bar panel without opening
  Settings, and repeated activation never produces duplicate About windows.
- The window reliably identifies a release build or the local development
  fallback, contains no account or provider information, and does not return at
  app launch after it is closed.
- GitHub and Boosty open through the system link handler; no support or release
  URL is persisted with user data.

## Milestone 23: App Localization And General Settings

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
  Provider Setup. Move the refresh-schedule and dashboard-height controls and
  their explanatory copy into General; remove Refresh as a top-level Settings
  section without changing either persisted preference or refresh behavior.
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
- General contains language, refresh schedule, and dashboard height; Accounts
  and Provider Setup remain focused on their existing workflows, and refresh
  scheduling works exactly as before.
- User-created names, provider data, and persisted technical values stay intact
  when the language changes; only the app's presentation is localized.
- `dist/AILimitBar.app` contains and loads both localizations after the normal
  build-and-run workflow.

## Milestone 24: Per-Limit Usage Thresholds

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
  effective thresholds and `usedPercent`. Surface the state in the dashboard
  and feed the image-only status badge from Milestone 22.1: `Warning` uses the
  yellow badge and `Critical` uses the red badge, while refresh errors retain
  red precedence. Do not fabricate state for unavailable or no-data windows.
- [ ] Add tests for validation, global fallback, override creation/removal,
  stable-key matching, temporary window absence, severity resolution, worst
  account state, and all normal/warning/critical boundaries.
- [ ] Manually verify English and Russian Settings flows, per-window dashboard
  severity, and menu-bar behavior with multiple accounts and limit windows.

Acceptance:

- A user can set one global warning/critical pair and selectively replace it
  for any reported limit window with a stable provider identifier.
- Changing global values immediately updates every non-overridden window;
  changing an override affects only that account-window.
- An overridden window retains its configuration across refreshes, relaunches,
  and transient provider responses that omit it.
- The dashboard accurately shows normal/warning/critical severity from the
  resolved thresholds, and the menu-bar badge reflects the worst enabled
  threshold severity without adding a visible percentage or account label.
- All new app-owned strings are localized in English and Russian; provider
  labels and identifiers remain provider data rather than translated storage
  keys.

## Milestone 25: Usage Limit Notifications

Goal: deliver actionable, user-controlled macOS local notifications for newly
observed warning and critical threshold crossings without prompting on launch,
spamming during refreshes, or treating a configuration change as a crossing.

- [ ] Add a localized `Usage notifications` preference in General. It is off
  on a fresh install; only an explicit attempt to enable it may request macOS
  notification permission. Show the current authorization state and an `Open
  Notification Settings` recovery action when permission is denied or
  restricted. Do not repeatedly request permission or attempt to bypass Focus
  and system notification policy.
- [ ] Introduce a testable `UsageNotificationCoordinator` behind a local
  notification client. It consumes resolved per-window severity only after a
  successful usable snapshot is available; it must not fetch providers,
  change provider configuration, or derive usage values itself.
- [ ] Persist non-sensitive delivery state through GRDB, keyed by the saved
  account identifier and stable provider-owned limit-window identifier. Store
  enough information to distinguish a silent baseline, the provider reset
  cycle when available, the highest level already delivered in that cycle, and
  the last usable severity. Never persist raw provider payloads, credentials,
  opaque account identifiers, or notification body text.
- [ ] Establish a silent baseline for a newly enabled notification preference,
  a newly discovered window, and a window returning after unavailable or
  no-data samples. Notify only for an observed `normal → warning` or
  `normal/warning → critical` transition in the same usable reset cycle. If
  both levels are crossed in one update, notify only for `Critical`.
- [ ] Re-arm a window only after its usable usage falls below the effective
  warning threshold or the provider reports a newer reset cycle. A threshold
  edit updates visible severity immediately, but neither it nor app launch,
  permission approval, a stale snapshot, an error, or a missing window sends a
  notification.
- [ ] Coalesce all crossings discovered by one refresh into at most one local
  notification, with `Critical` taking precedence. For one affected window,
  use localized account, limit-window, level, and percentage text; for several,
  use a localized severity summary and count. Selecting the notification brings
  AI Limitbar forward and opens the dashboard focused on the affected account
  when one account is involved.
- [ ] Present alerts while AI Limitbar is active according to the user's macOS
  notification settings. Respect system delivery, preview, sound, Focus, and
  notification-center retention behavior; the app must not add custom bypasses
  or urgent interruption levels.
- [ ] Add tests with a fake notification client for authorization states,
  no-launch prompt, silent baselines, warning and critical crossings,
  simultaneous crossings, per-refresh coalescing, re-arming, reset-cycle
  changes, relaunch deduplication, threshold edits, unavailable/no-data gaps,
  persistence migration, and notification selection routing.
- [ ] Manually verify English and Russian flows: enable/deny/re-enable in
  General, foreground and background delivery, multiple accounts and windows,
  alert selection, refresh/relaunch deduplication, and a new provider reset
  cycle.

Acceptance:

- A person is never asked for notification permission at launch or because a
  refresh happened; the request follows their explicit General-settings action.
- A newly observed threshold crossing produces one useful local alert when
  enabled and authorized, while a sustained value cannot spam during later
  refreshes or after relaunch.
- One refresh with several crossings creates one highest-severity summary, and
  notification selection takes the person to the relevant dashboard context.
- A window can notify again only after it falls below Warning or a newer reset
  cycle is observed; changing thresholds alone never sends an alert.
- Denied permission, Focus, stale data, unavailable data, manual-only windows,
  and notification delivery failures remain recoverable and do not corrupt
  stored usage or delivery state.
- All app-owned notification and settings strings are localized in English and
  Russian; provider labels and stable identifiers remain provider data.

## Milestone 26: Dashboard Appearance And Themes

Goal: let people choose an app appearance and a reusable dashboard palette
without weakening the terminal-fieldset visual system or turning severity into
a full-panel tint.

- [ ] Add a durable app-appearance choice: `System`, `Light`, or `Dark`. It
  changes the app's effective color scheme immediately; native Settings
  controls remain native macOS controls rather than receiving custom chrome.
- [ ] Store individual light and dark dashboard palettes, including curated
  presets and user-created palettes, then persist separate `lightPaletteID` and
  `darkPaletteID` selections. Resolve the active palette from the effective app
  appearance and apply it consistently to the menu-bar dashboard and its
  matching account-details popover.
- [ ] Add `Import Theme…` and `Export Theme…` for portable JSON theme files.
  An import must contain at least one complete `light` or `dark` palette; copy
  the missing selection from the matching built-in `Default` palette for the
  import preview. `Apply` persists only the imported palette variants, selects
  the imported or Default palette for each mode, and leaves no dependency on
  the source file. `Cancel` changes neither the palette library nor current
  selections; import never changes the user's selected `System` / `Light` /
  `Dark` app appearance.
- [ ] Model palette values as named, Codable sRGB color tokens rather than
  serializing platform color objects or assigning colors directly inside views.
  Custom tokens include dashboard background, fieldset surface and border,
  primary and secondary text, plus the four progress colors below.
- [ ] Provide exactly four configurable progress-bar colors: `Free` for the
  unused portion/track, `Used` for consumed usage below the warning threshold,
  `Warning` for consumed usage from the effective warning threshold up to the
  critical threshold, and `Critical` for consumed usage at or above the
  effective critical threshold.
- [ ] Keep the `Free` portion constant while deriving only the consumed portion
  from the per-window severity resolved by Milestone 24. Do not introduce a
  fifth track color or recolor the dashboard, account panel, or popover
  background when a threshold is crossed.
- [ ] Use the same `Warning` or `Critical` token for a compact status marker on
  the affected limit window. Keep the percentage and a textual/accessibility
  state available so color is never the sole threshold signal.
- [ ] Add an `Appearance` section to General with preset selection, custom
  color controls, separate Light Theme and Dark Theme pickers, a live compact
  preview with `Apply` / `Cancel`, and a reset-to-Default action. Keep the
  General, Accounts, and Provider Setup workflows compact and unchanged.
- [ ] Store the appearance preference through the app's GRDB settings layer;
  add a versioned migration and use defaults for existing installations.
- [ ] Add tests for default values, Codable color round-tripping, storage
  migration, light-only and dark-only theme imports, rejection of an import
  with no complete palette, per-appearance palette resolution, import preview
  apply/cancel behavior, reset behavior, and all normal/warning/critical
  progress-color boundaries.
- [ ] Manually verify the staged app in System, Light, and Dark appearance with
  every preset and a custom palette, including dashboard, details popover,
  native Settings controls, keyboard focus, and accessibility values.

Acceptance:

- A person can choose System, Light, or Dark appearance, then independently
  select the palette used in Light and Dark without restarting the app.
- A JSON theme with either one complete light or dark palette imports
  predictably: preview uses the matching Default palette for its missing mode;
  Apply selects that Default palette while keeping the imported variant
  available for editing or export.
- Cancelling an import preview leaves persisted palettes and both selected
  palette IDs unchanged.
- Dashboard and details popover use the same resolved static palette; native
  Settings retains macOS-standard control behavior and appearance.
- Each progress bar visibly separates its free portion from its consumed
  portion, and the consumed portion changes from Used to Warning to Critical at
  the effective per-window thresholds.
- Warning and Critical never dynamically recolor an entire dashboard, account
  panel, or popover; they affect only the consumed progress portion and its
  compact marker.
- Threshold state remains understandable through text and accessibility APIs
  when colors are indistinguishable or overridden by a custom palette.

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
