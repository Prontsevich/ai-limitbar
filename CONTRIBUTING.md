# Contributing to AI Limitbar

## Build & Test

**Requirements:** macOS 26+, Xcode 26+ (Swift 6.2)

```zsh
swift build                # Build all targets
swift test                 # Run full test suite
./script/build_and_run.sh  # Stage .app bundle and launch
```

### Run Modes

| Mode | Description |
| --- | --- |
| `--verify` | Build + foreground app smoke test |
| `--debug` | Attach LLDB to the staged bundle |
| `--logs` | Show live app logs |
| `--telemetry` | Enable telemetry output |

The run script builds the SwiftPM product, stages a local ad-hoc signed `.app`
bundle in `dist/`, and launches it. All modes use the same bundle shape.

## Release Packaging

Create a locally validated Apple Silicon release archive:

```zsh
./script/package_release.sh 0.1.0
```

The `Release` GitHub Actions workflow can be run manually to validate a package
before publication. A tag in `vMAJOR.MINOR.PATCH` format publishes the matching
archive automatically. Release tags must point to commits contained in `main`:

```zsh
git tag -a v0.1.0 -m "AI Limitbar 0.1.0"
git push origin v0.1.0
```

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