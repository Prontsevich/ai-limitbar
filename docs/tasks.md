# AI Limitbar Tasks

## Milestone 0: Project Foundation

- [x] Create project directory.
- [x] Initialize git repository.
- [x] Draft MVP plan.
- [ ] Create initial macOS project scaffold.
- [ ] Add basic build/run script for local development.
- [ ] Add project README.

## Milestone 1: App Skeleton

Goal: produce a runnable macOS menu bar app with mock data and no real provider
credentials.

- [ ] Create SwiftUI macOS app target.
- [ ] Add `MenuBarExtra` as the primary app surface.
- [ ] Add settings scene placeholder.
- [ ] Add `UsageSnapshot` model.
- [ ] Add `ProviderAdapter` protocol.
- [ ] Add mock provider adapter.
- [ ] Add in-memory snapshot store.
- [ ] Render provider rows in the menu bar panel.
- [ ] Add manual refresh action.
- [ ] Show last updated state.
- [ ] Show confidence/source labels.

Acceptance:

- The app launches.
- The menu bar item appears.
- Mock provider snapshots render.
- Manual refresh changes or reloads mock data.
- No real credentials are required.

## Milestone 2: Persistence

Goal: persist normalized snapshots locally without storing secrets.

- [ ] Add application support directory resolver.
- [ ] Add JSON snapshot store.
- [ ] Load snapshots on app launch.
- [ ] Save snapshots after refresh.
- [ ] Handle missing/corrupt snapshot files gracefully.
- [ ] Add lightweight error state for failed loads or saves.

Acceptance:

- Closing and reopening the app preserves the last mock snapshot.
- Snapshot JSON contains no credentials or raw provider responses.

## Milestone 3: Provider Configuration

Goal: let users enable providers and prepare for real credentials.

- [ ] Add provider registry.
- [ ] Add provider enabled/disabled state.
- [ ] Add settings UI for provider toggles.
- [ ] Add placeholder connection test action.
- [ ] Add provider usage URL action.
- [ ] Add Keychain service interface.
- [ ] Keep credential entry disabled until real provider requirements are known.

Acceptance:

- The settings window controls which providers appear in the menu bar list.
- Provider state survives app restart.
- The app has a clear place to add credentials later.

## Milestone 4: Provider Research Spikes

Goal: determine what each provider can support reliably before implementation.

- [ ] OpenAI Codex: identify supported usage sources by account type.
- [ ] OpenAI Codex: decide MVP source mode and confidence level.
- [ ] Claude Code: identify CLI/local usage source and output format.
- [ ] Claude Code: decide whether usage can be parsed reliably.
- [ ] Ollama Cloud: determine whether a documented usage API exists.
- [ ] Ollama Cloud: decide MVP source mode and confidence level.
- [ ] Document unsupported or manual-only cases in the plan.

Acceptance:

- Each provider has a documented source strategy.
- Each provider has a selected initial confidence level.
- No provider implementation starts from an unverified assumption.

## Milestone 5: First Real Provider

Goal: add one real provider end to end.

- [ ] Pick first provider based on research results.
- [ ] Implement configuration requirements.
- [ ] Implement adapter fetch logic.
- [ ] Normalize provider result into `UsageSnapshot`.
- [ ] Add structured error handling.
- [ ] Add connection test.
- [ ] Add manual refresh.
- [ ] Verify no secrets are logged or persisted outside Keychain.

Acceptance:

- One real provider returns a useful snapshot.
- Errors are visible and actionable.
- The mock provider still works.

## Milestone 6: Refresh Coordination

Goal: make refresh behavior predictable and respectful of provider limits.

- [ ] Add refresh coordinator.
- [ ] Add per-provider refresh status.
- [ ] Prevent overlapping refreshes.
- [ ] Add configurable refresh interval.
- [ ] Add stale snapshot detection.
- [ ] Add retry/backoff policy for transient failures.

Acceptance:

- Manual refresh remains immediate.
- Scheduled refreshes do not overlap.
- Stale data is clearly labeled.

## Milestone 7: Widget Readiness

Goal: prepare snapshots for WidgetKit without adding the widget yet.

- [ ] Move snapshot storage behind a container abstraction.
- [ ] Decide App Group identifier.
- [ ] Add shared snapshot format version.
- [ ] Add migration path for local snapshot files.
- [ ] Document widget constraints.

Acceptance:

- The app can switch storage locations without changing provider adapters.
- Widget work can start without redesigning snapshot storage.

## Later

- [ ] Add WidgetKit extension.
- [ ] Add multiple account support per provider.
- [ ] Add provider-specific detail windows.
- [ ] Add notifications for near-limit state.
- [ ] Add export/debug bundle without secrets.
- [ ] Add Linear backlog if the project grows beyond local docs.
