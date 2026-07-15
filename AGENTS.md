# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project Overview

AI Limitbar is a macOS menu-bar-only app (`LSUIElement`) for viewing normalized
AI provider usage snapshots. Built with SwiftUI on Swift 6.2 / macOS 15+.

## Build & Test

```zsh
swift build                # Build all targets
swift test                 # Run full test suite
./script/build_and_run.sh  # Stage .app bundle and launch
```

Useful run modes: `--verify`, `--debug`, `--logs`, `--telemetry`.

The run script builds the SwiftPM product, stages a local ad-hoc signed `.app`
bundle in `dist/`, and launches it. All modes use the same bundle shape.

## Architecture

### Targets

| Target | Type | Purpose |
| --- | --- | --- |
| `AILimitBar` | Executable | Main menu-bar app (SwiftUI `MenuBarExtra`) |
| `AILimitBarClaudeStatusLine` | Executable | Bundled helper for Claude Code `statusLine` |
| `AILimitBarCore` | Library | Shared models, providers, services, stores |
| `AILimitBarCoreTests` | Tests | Core layer: providers, DB, snapshots, refresh |
| `AILimitBarTests` | Tests | App layer: orchestration, dashboard presentation |

### Layers

```
AILimitBar (app)
├── App/        — SwiftUI app entry, lifecycle
├── Models/     — Dashboard presentation models
├── Support/    — Telemetry, statusLine installer, WebKit controller
├── ViewModels/ — AppModel and extensions (accounts, persistence, refresh)
└── Views/      — MenuBarPanel, Settings, account details, terminal styling

AILimitBarCore (library)
├── Models/    — UsageSnapshot, ProviderConfiguration, RefreshSettings
├── Providers/ — ProviderAdapter protocol + 5 adapters (Codex, Claude, Ollama, Mock, Manual)
├── Services/  — CodexAppServerClient, ClaudeCodeStatusLine, Keychain, RefreshCoordinator
└── Stores/    — GRDB/SQLite database, stores, legacy importer

AILimitBarClaudeStatusLine (helper)
└── main.swift — Reads statusLine JSON from stdin, writes snapshot to SQLite
```

### Key Patterns

- **Provider adapters** implement `ProviderAdapter` protocol. Each normalizes
  provider data into a `UsageSnapshot`. Adapters never touch UI state directly.
- **`AppModel`** is the main view model, split across `+Accounts`, `+Persistence`,
  `+Refresh` extensions.
- **GRDB/SQLite** stores provider accounts, refresh settings, current normalized
  snapshots, and source diagnostics. It uses WAL mode, foreign keys, and a
  bounded busy timeout. Device-local UI preferences may use `UserDefaults`;
  credentials belong only in Keychain, and browser session data stays in its
  isolated `WKWebsiteDataStore`.
- **AppKit** stays behind narrow platform-integration boundaries such as app and
  window lifecycle, native menus, adaptive colors, and SwiftUI/WebKit bridges.
  Feature state remains in SwiftUI and `AppModel`.
- **Terminal-fieldset dashboard** — the menu bar panel and account details
  use a compact terminal-fieldset composition, not glass cards. See
  `docs/dashboard-design.md`.

## Working Agreement

- Treat the live code and `Package.swift` as the source of truth for the current
  implementation, `docs/plan.md` for current architecture and settled public
  contracts, the private Linear workspace for active strategy, priorities,
  project documents, and issues, and `docs/tasks.md` for completed-history
  evidence.
- When Linear is connected, read the team document `AI Limitbar — Working Guide`
  before selecting, creating, or starting work. Then read the relevant Project
  document, issue, and any linked design or provider document.
- Use the Linear lifecycle consistently: new ideas start in `Triage`, confirmed
  unscheduled work moves to `Backlog`, only the next 3–5 ready issues belong in
  `Todo`, active implementation moves through `In Progress` and `In Review`,
  and `Done` requires completed verification rather than implementation alone.
- An issue labeled `Requires Apple Developer Program` must remain unassigned in
  `Backlog`, without an estimate or target date, until the team-level Apple
  Developer Program membership gate is `Done`. A Project existing in Linear is
  not permission to start gated work.
- Update the linked Linear issue and documentation alongside implementation
  when behavior, architecture, or milestone status changes. Do not defer either
  to a later cleanup pass.
- Keep private Linear issue identifiers and URLs out of branch names, commits,
  public GitHub issues, and pull requests. Attach a public pull request URL from
  the private Linear issue instead.
- Verify changes in proportion to their scope. Run `swift build` and `swift test`
  for code changes; use the staged `.app` bundle for UI, lifecycle, or provider
  integration checks. Do not mark manual verification complete unless it was
  actually performed.
- Preserve unrelated working-tree changes. Create commits only when the user asks,
  and keep each requested commit scoped to one coherent task.

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(scope): description
docs(scope): description
fix(scope): description
refactor(scope): description
style(scope): description
build(scope): description
```

Common scopes: `storage`, `codex`, `dashboard`, `ollama`, `claude`, `settings`,
`roadmap`, `readme`, `core`, `app`, `ui`, `dev`, `mvp`, `project`.

## Constraints

- **macOS 15+ only.** Do not add compatibility fallbacks for older macOS.
- **SwiftUI-first.** Use system controls before custom components. The
  terminal-fieldset visual system is the product-specific composition.
- **Privacy-first.** Never put credentials, tokens, cookies, browser session
  data, or raw provider responses in SQLite, `UserDefaults`, logs, or
  diagnostics. Persist credentials only in Keychain, keep browser data in its
  isolated per-account `WKWebsiteDataStore`, and do not persist raw responses.
- **Menu-bar-only.** The app uses `LSUIElement` — no Dock icon, no main window.
- **Experimental sources are opt-in.** A successful experimental read is `OK`;
  the `Experimental` label is informational, not a warning.
- **No external dependencies** except GRDB.swift.
- **Don't edit** `.codex/environments/environment.toml` — it is autogenerated.

## Documentation

- `docs/plan.md` — Current architecture, provider evidence, and settled public
  contracts
- `docs/tasks.md` — Completed milestone scope, acceptance criteria, and
  verification history; active and future scope is tracked privately in Linear
- `docs/dashboard-design.md` — Terminal-fieldset dashboard design contract
- `docs/settings-design.md` — Settings window lifecycle and visual contract
- `docs/design-qa.md` — Dashboard visual QA findings and fixes
- `docs/providers/` — Per-provider implementation notes
