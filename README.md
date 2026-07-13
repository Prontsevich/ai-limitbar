# 🖥️ AI Limitbar

> macOS menu bar app for viewing normalized AI provider usage —
> all your limits in one compact place.

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-package-FA7343?logo=swift&logoColor=white)](https://swift.org/package-manager)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](#license)

The MVP is intentionally honest about data quality: values can be live,
delayed, local estimates, manual checks, or unknown. No real provider
credentials are required to start.

---

## ✨ Features

**📊 Usage Tracking**
- Normalized snapshots across providers — live, delayed, local estimates, or manual
- Configurable refresh interval (manual by default)
- Per-provider refresh status with stale-snapshot flags
- Configurable dashboard height presets: `Compact` (320 pt), `Standard` (440 pt), `Tall` (640 pt)

**🔌 Providers**
- OpenAI Codex — manual + experimental app-server rate-limit source
- Claude Code — `statusLine` helper for local-estimate snapshots
- Ollama Cloud — experimental web-page source with isolated WebKit sessions
- Mock provider for development

**🔒 Privacy-first**
- No credentials stored — Keychain interface ready for future integrations
- No raw provider responses, cookies, or tokens persisted
- Each web source gets an isolated WebKit data store

**🖥️ Menu-bar-only**
- `LSUIElement` bundle — no Dock icon, no main window
- Liquid Glass-capable, macOS 26 Tahoe baseline
- Terminal-fieldset dashboard design (Codex `/status` + lazygit visual grammar)

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

Useful run modes:

| Mode | Description |
| --- | --- |
| `--verify` | Build + foreground app smoke test |
| `--debug` | Attach LLDB to the staged bundle |
| `--logs` | Show live app logs |
| `--telemetry` | Enable telemetry output |

The run script stages a menu-bar-only `.app` bundle in `dist/AILimitBar.app`,
ad-hoc signed and validated after staging.

## 🎨 Platform Direction

AI Limitbar is a modern-only macOS app targeting macOS 26 Tahoe or later.

- Standard SwiftUI controls and system structures are the default — Liquid Glass is the design baseline
- Custom glass surfaces for AI Limitbar-specific compositions only, not for recreating system controls
- Terminal-fieldset dashboard is an intentional exception (see [`docs/dashboard-design.md`](docs/dashboard-design.md))
- Settings follow a terminal-adjacent style (see [`docs/settings-design.md`](docs/settings-design.md))

## 🗄️ Storage

Accounts, snapshots, refresh settings, and source diagnostics are stored in a
local [GRDB](https://github.com/groue/GRDB.swift)/SQLite database:

```
~/Library/Application Support/AI Limitbar/AI Limitbar.sqlite
```

SQLite WAL mode, foreign keys, and a bounded write timeout are enabled so the
bundled Claude Code `statusLine` helper can update snapshots while the app is
closed or reading. The dashboard-height preset is stored separately in
`UserDefaults`.

Legacy `snapshots.json`, `providers.json`, and `refresh-settings.json` files
are imported once on first launch and preserved as `.backup` — never deleted.

**Never stored:** credentials, cookies, tokens, raw provider responses, or raw
statusLine payloads.

## 📖 Documentation

| Document | Description |
| --- | --- |
| [`docs/plan.md`](docs/plan.md) | Full product plan, provider research, architecture |
| [`docs/tasks.md`](docs/tasks.md) | Milestone tracker (24 milestones, 16 done) |
| [`docs/dashboard-design.md`](docs/dashboard-design.md) | Terminal-fieldset dashboard design contract |
| [`docs/settings-design.md`](docs/settings-design.md) | Settings window lifecycle and visual contract |
| [`docs/providers/`](docs/providers/) | Per-provider implementation notes |

## 🗺️ Roadmap

Completed milestones ✅ → future work 📋.

**Done ✅** (Milestones 0–17)
App skeleton · persistence · provider research · Claude Code source · refresh
coordination · widget readiness · account model · dashboard redesign · settings
master-detail · modern macOS baseline · stabilization · Ollama web source ·
Codex app-server · SQLite migration · terminal dashboard.

**Backlog 📋** (Milestones 18–24)
Settings window lifecycle · provider/account readiness · daily-use polish ·
app localization (EN+RU) · per-limit thresholds · usage notifications ·
dashboard themes · WidgetKit widget.

## 📄 License

MIT. A `LICENSE` file will be added before the first tagged release.