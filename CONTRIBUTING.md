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
export AILIMITBAR_DEVELOPMENT_TEAM=YOUR_TEAM_ID
export AILIMITBAR_DEVELOPER_IDENTITY="Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)"
export AILIMITBAR_PROVISIONING_PROFILE=/private/path/AILimitBar.provisionprofile
./script/package_release.sh 0.2.0 20260813.1 arm64
./script/package_release.sh 0.2.0 20260813.1 x86_64
```

Release staging fails closed unless the selected Developer ID identity matches
the single certificate in the supplied Developer ID provisioning profile. It
signs the bundled helper and outer app with Hardened Runtime and secure
timestamps, embeds the profile that authorizes the app's default Keychain
group, and revalidates the signature after the ZIP round trip. The identity,
profile, private key, Team ID, and future notarization credentials stay outside
the repository.

These archives are Developer ID signed but are not trusted release artifacts
until Apple notarization, stapling, and Gatekeeper validation also succeed.
The `Release` GitHub Actions workflow intentionally fails closed for both
manual dispatches and version tags: protected CI signing, notarization,
stapling, and Gatekeeper validation are not configured yet, so the workflow
must not package, upload, or publish an artifact. Local archives are for
authorized validation only and must not be represented as downloadable trusted
releases.

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
