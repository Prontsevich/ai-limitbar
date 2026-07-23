# Regular-Window UI Test Host

## Purpose

The debug-only UI test host exposes app-owned SwiftUI surfaces through a regular
macOS window that accessibility tooling can inspect. It reuses the production
`AILimitBar` executable, `MenuBarPanelView`, `SettingsView`, dashboard keyboard
responder, localization, and resources. It does not alter the production
`LSUIElement` bundle or release workflow.

The host is a presentation test boundary, not a provider-integration emulator.
It creates only scripted synthetic adapters, normalized fixtures, and isolated
local state. It never creates a status item, WebKit controller, real provider
client, executable override, credential, or personal account value.

## Command Contract

Stage and run a scenario through Launch Services:

```zsh
AILIMITBAR_DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  ./script/build_and_run.sh --ui-test-host dashboard-healthy \
  --ui-test-language en \
  --ui-test-appearance dark \
  --ui-test-height standard
```

Like every locally staged DEBUG bundle, the host requires an explicit
caller-owned Apple Development Team ID through
`AILIMITBAR_DEVELOPMENT_TEAM`; the repository does not store a default.

Supported values:

| Argument | Values | Default |
| --- | --- | --- |
| `--ui-test-host` | `dashboard-empty`, `dashboard-healthy`, `dashboard-mixed`, `settings`, `settings-dirty-editor` | `dashboard-healthy` when the host bundle is opened directly |
| `--ui-test-language` | `en`, `ru` | `en` |
| `--ui-test-appearance` | `light`, `dark` | `dark` |
| `--ui-test-height` | `compact`, `standard`, `tall` | `standard` |

The launcher validates its public arguments. The app also uses a typed parser:
missing or invalid UI-test values fail launch explicitly, while unrelated
system-injected arguments are ignored.

`script/stage_ui_test_host_bundle.sh` stages the debug production app, copies it
to `dist/AILimitBarUITestHost.app`, changes only the copied bundle metadata, and
ad-hoc signs and validates the result. The host identity is:

- bundle ID: `io.github.Prontsevich.AILimitBar.UITestHost`;
- display name: `AI Limitbar UI Test Host`;
- executable and process: `AILimitBarTest`;
- `LSUIElement=false`.

The launcher terminates only a previous `AILimitBarTest` process. A production
`AILimitBar` process may remain running alongside it.

## Scenarios

- `dashboard-empty` renders the production empty dashboard state.
- `dashboard-healthy` renders two healthy synthetic accounts with deterministic
  usage windows and supports refresh, meter selection, keyboard navigation, and
  switching the same host window to Settings.
- `dashboard-mixed` covers healthy, warning, stale, failed, manual-only, and
  no-data accounts, a deliberately long synthetic name, details, and scrolling.
- `settings` opens the real Settings surface with healthy synthetic accounts.
- `settings-dirty-editor` opens Accounts with the first synthetic account in
  edit mode so an account-name edit can exercise the discard confirmation flow.

All fixture timestamps derive from one minute-rounded launch instant and remain
away from stale and reset thresholds. Scripted refreshes use one attempt and may
have an explicit deterministic delay. Scheduled refresh is disabled.

## Accessibility Workflow

Inspect the running app by bundle ID
`io.github.Prontsevich.AILimitBar.UITestHost`. Stable language-independent
identifiers include:

- `ui-test-host.root.<scenario>`;
- `dashboard.refresh-all` and `dashboard.open-settings`;
- `dashboard.meter.<provider>.<account>.<window>`;
- `settings.navigation.<section>`;
- `settings.general.language.<value>`;
- `settings.general.refresh.<value>`;
- `settings.general.limit-display.<value>`;
- `settings.general.height.<value>`;
- `settings.account-name`, `settings.discard`, and `settings.keep-editing`.

Use the host AX tree and screenshots to verify app-owned layout, labels, values,
focus, keyboard paths, Settings navigation, preference controls, scrolling, and
Light/Dark plus English/Russian presentation. Record only interactions that were
actually performed.

## State Reset

Each launch receives a unique temporary GRDB directory and unique
`UserDefaults` suite. The suite is passed to `AppModel`,
`AppLanguagePreference`, and SwiftUI through `defaultAppStorage`. Normal app
termination removes both. The launcher removes its exact temporary directory as
a fallback after the host exits or is interrupted.

## Coverage Boundary

The host covers app-owned SwiftUI dashboard and Settings behavior. It does not
claim coverage for the production `NSStatusItem`, `NSPopover` anchoring,
`LSUIElement` activation or Spaces behavior, OAuth/WebKit sessions, real provider
processes or network integrations, Keychain, release signing, or notarization.
Those paths retain their existing unit, integration, telemetry, staged-app, and
explicit manual verification requirements.
