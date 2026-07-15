# 🖥️ AI Limitbar

> macOS menu bar app for viewing normalized AI provider usage —
> all your limits in one compact place.

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](#license)

## Why

Checking AI provider usage limits usually means opening each provider's page
separately. AI Limitbar brings them together in one menu bar dropdown — with
honest labels for what's live, what's estimated, and what needs attention.

No real provider credentials are required to start.

![AI Limitbar dashboard in dark mode](docs/screenshots/dashboard-dark.png)

## Features

- One menu bar panel for all your AI provider usage limits
- Normalized snapshots — live, delayed, local estimates, or manual
- Configurable refresh interval (manual by default)
- Stale-snapshot flags so you know when data is outdated
- Dashboard height presets: Compact, Standard, Tall
- Menu-bar-only — no Dock icon, no main window

## Providers

| Provider | Source | Data Type |
| --- | --- | --- |
| **OpenAI Codex** | App-server | 🟢 Live rate-limit windows |
| **Claude Code** | Helper + `/usage` CLI | 🟡 Local estimate / 🟢 Live plan limits |
| **Ollama Cloud** | Web page (isolated WebKit) | 🟢 Live session/weekly |

Experimental sources are opt-in. A successful experimental read is `OK`;
the `Experimental` label is informational, not a warning.

→ See [`docs/providers/`](docs/providers/) for implementation details.

## Download

**Requirements:** macOS 15+ on Apple Silicon or Intel

Download the matching archive from the
[latest GitHub Release](https://github.com/Prontsevich/ai-limitbar/releases/latest):

- `AILimitBar-<version>-arm64.zip` for Apple Silicon Macs
- `AILimitBar-<version>-x86_64.zip` for Intel Macs

Unpack the archive and move `AILimitBar.app` to Applications.

Release builds are ad-hoc signed and are not notarized by Apple. On first
launch, macOS may block the app because the developer cannot be verified. If
you trust this repository and its release, try opening the app once, then use
**System Settings → Privacy & Security → Open Anyway**. See Apple's
[Gatekeeper instructions](https://support.apple.com/guide/mac-help/open-an-app-by-overriding-security-settings-mh40617/mac).

## Roadmap

**Done ✅** — Core app, persistence, Claude Code, refresh coordination, account
model, dashboard redesign, settings, Ollama web source, Codex app-server, SQLite
migration, terminal dashboard, Settings redesign, Claude `/usage` CLI, and
GitHub Release distribution.

**Planned directions 📋** — localization, additional provider research,
per-limit thresholds, notifications, dashboard appearance, trusted macOS
distribution, and a passive WidgetKit extension.

## Documentation

| Document | Description |
| --- | --- |
| [`docs/plan.md`](docs/plan.md) | Product plan, provider research, architecture |
| [`docs/tasks.md`](docs/tasks.md) | Roadmap scope, acceptance criteria, and completed-history evidence |
| [`docs/dashboard-design.md`](docs/dashboard-design.md) | Dashboard design contract |
| [`docs/settings-design.md`](docs/settings-design.md) | Settings design contract |
| [`docs/providers/`](docs/providers/) | Per-provider implementation notes |

Private strategy, priorities, project documents, and implementation tasks are
managed in Linear. GitHub is the public surface for source code, pull requests,
releases, and user-reported bugs or feature requests. Private Linear issue IDs
and planning discussions are not copied into public branches, commits, issues,
or pull requests.

GitHub Releases are the public changelog. Release notes are assembled from
merged pull requests and completed work, with private planning details removed.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for build instructions, development
setup, and release procedures.

## Feedback And Support

Report bugs and feature ideas through the public
[GitHub issue forms](https://github.com/Prontsevich/ai-limitbar/issues/new/choose), send
direct feedback to [prontsevich@gmail.com](mailto:prontsevich@gmail.com), or
message [@s_prontsevich](https://t.me/s_prontsevich) on Telegram.

If you find AI Limitbar useful, consider supporting its development.
All contributions go toward **Apple Developer Program membership** — enabling
Developer ID signing, notarized builds, and a smoother install experience for
everyone.

[![Boosty](https://img.shields.io/badge/Boosty-Support-FF6B00?logo=boosty&logoColor=white)](https://boosty.to/sergey.pro)

## License

MIT. See [`LICENSE`](LICENSE).
