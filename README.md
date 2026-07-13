# 🖥️ AI Limitbar

> macOS menu bar app for viewing normalized AI provider usage —
> all your limits in one compact place.

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](#license)

The MVP is intentionally honest about data quality: values can be live,
delayed, local estimates, manual checks, or unknown. No real provider
credentials are required to start.

---

## ✨ Features

- Normalized snapshots across providers — live, delayed, local estimates, or manual
- Configurable refresh interval (manual by default)
- Per-provider refresh status with stale-snapshot flags
- Dashboard height presets: `Compact` (320 pt), `Standard` (440 pt), `Tall` (640 pt)
- Menu-bar-only `LSUIElement` bundle — no Dock icon, no main window

## 🔌 Providers

| Provider | Default | Experimental Source | Snapshot Type |
| --- | --- | --- | --- |
| **OpenAI Codex** | Manual | App-server (`codex app-server`) | 🟢 Live rate-limit windows |
| **Claude Code** | Manual | `statusLine` helper → SQLite | 🟡 Local estimate |
| **Ollama Cloud** | Manual | Web page (isolated WebKit) | 🟢 Live session/weekly |
| **Mock** | — | — | 🟡 Local estimate |

Experimental sources are opt-in. A successful experimental read is presented as
`OK`; the `Experimental` label is informational, not a warning.

→ See [`docs/providers/`](docs/providers/) for implementation details.

## 🚀 Quick Start

**Requirements:** macOS 26+, Xcode 26+ (Swift 6.2)

```zsh
swift build                # Build
swift test                 # Test
./script/build_and_run.sh  # Build, stage .app bundle, launch
```

| Mode | Description |
| --- | --- |
| `--verify` | Build + foreground app smoke test |
| `--debug` | Attach LLDB to the staged bundle |
| `--logs` | Show live app logs |
| `--telemetry` | Enable telemetry output |

## 🎨 Platform Direction

AI Limitbar is a modern-only macOS app targeting macOS 26 Tahoe or later.

- Standard SwiftUI controls and system structures are the default
- Terminal-fieldset dashboard is the product-specific composition (see [`docs/dashboard-design.md`](docs/dashboard-design.md))
- Settings follow a terminal-adjacent style (see [`docs/settings-design.md`](docs/settings-design.md))

## 📖 Documentation

| Document | Description |
| --- | --- |
| [`docs/plan.md`](docs/plan.md) | Full product plan, provider research, architecture |
| [`docs/tasks.md`](docs/tasks.md) | Milestone tracker (24 milestones, 16 done) |
| [`docs/dashboard-design.md`](docs/dashboard-design.md) | Terminal-fieldset dashboard design contract |
| [`docs/settings-design.md`](docs/settings-design.md) | Settings window lifecycle and visual contract |
| [`docs/design-qa.md`](docs/design-qa.md) | Dashboard visual QA findings and fixes |
| [`docs/providers/`](docs/providers/) | Per-provider implementation notes |

## 🗺️ Roadmap

**Done ✅** — Milestones 0–17: app skeleton, persistence, provider research, Claude Code, refresh coordination, account model, dashboard redesign, settings master-detail, modern macOS baseline, Ollama web source, Codex app-server, SQLite migration, terminal dashboard.

**Backlog 📋** — Milestones 18–24: settings window lifecycle, provider/account readiness, daily-use polish, localization (EN+RU), per-limit thresholds, usage notifications, dashboard themes, WidgetKit widget.

## 📄 License

MIT. A `LICENSE` file will be added before the first tagged release.