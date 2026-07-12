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

## Milestone 14: Provider And Account Readiness

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

## Milestone 15: Daily Use Polish

Goal: make the menu bar app useful as a daily status tool before starting the
WidgetKit extension.

- [ ] Improve menu bar summary title and icon based on worst account state.
- [ ] Add near-limit state.
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
