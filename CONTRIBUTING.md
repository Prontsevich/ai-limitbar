# Contributing to AI Limitbar

## Build & Test

**Requirements:** macOS 15+, Xcode 26+ (Swift 6.2)

```zsh
swift build                                           # Build all targets
swift test                                            # Run full test suite
AILIMITBAR_DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  ./script/build_and_run.sh                           # Stage DEBUG .app and launch
```

### Run Modes

| Mode | Description |
| --- | --- |
| `--verify` | Deterministic integration smoke + staged Launch Services startup check |
| `--debug` | Attach LLDB to the staged bundle |
| `--logs` | Show live app logs |
| `--telemetry` | Enable telemetry output |

The run script builds the SwiftPM product and stages the DEBUG `.app` bundle in
`dist/`. DEBUG staging requires the caller's explicit
`AILIMITBAR_DEVELOPMENT_TEAM`; Xcode automatic signing selects an installed
Apple Development identity and an Xcode-managed provisioning profile that
authorizes the restricted application-identifier and default Keychain-group
entitlements. `--verify` first runs the deterministic app-layer integration
test, then launches the staged bundle through Launch Services with disposable
storage, verifies startup stability, and terminates only the process created by
that check. The staged bundle remains in `dist/` for manual QA. Interactive
menu-bar, Settings, focus, and pointer checks are not inferred from the process
check and must be performed manually.

## Release Packaging

Create locally validated architecture-specific release archives:

```zsh
./script/package_release.sh 0.2.0 arm64
./script/package_release.sh 0.2.0 x86_64
```

The `Release` GitHub Actions workflow can be run manually to validate a package
before publication. A tag in `vMAJOR.MINOR.PATCH` format publishes the matching
archive automatically. Release tags must point to commits contained in `main`:

```zsh
git tag -a v0.2.0 -m "AI Limitbar 0.2.0"
git push origin v0.2.0
```

Release staging remains ad-hoc and non-credential-capable pending the separate
distribution signing, authorized provisioning, and notarization gate.

## Architecture

See [`AGENTS.md`](AGENTS.md) for the full architecture guide: target layout,
layer responsibilities, key patterns, and working agreements.

## Documentation

- [`docs/plan.md`](docs/plan.md) — Product plan, provider research, architecture decisions
- [`docs/tasks.md`](docs/tasks.md) — Milestone tracker and completion state
- [`docs/dashboard-design.md`](docs/dashboard-design.md) — Terminal-fieldset dashboard design contract
- [`docs/settings-design.md`](docs/settings-design.md) — Settings window lifecycle and visual contract
- [`docs/design-qa.md`](docs/design-qa.md) — Dashboard visual QA findings and fixes
- [`docs/providers/`](docs/providers/) — Per-provider implementation notes

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
