<div align="center">
  <img src="docs/screenshot.png" width="420" alt="Command Code Usage Bar popover showing plan limits">
  <h1>Command Code Usage Bar</h1>
  <p>Live Command Code plan usage in your macOS menu bar.</p>
</div>

<p align="center">
  <a href="README.ko.md">한국어</a> ·
  <a href="#install">Install</a> ·
  <a href="#what-it-shows">What it shows</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#privacy">Privacy</a>
</p>

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-000000">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138">
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-2ea44f">
  <a href="https://github.com/jhparkdev/commandcode-usage-bar/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/jhparkdev/commandcode-usage-bar?label=release">
  </a>
  <a href="https://github.com/jhparkdev/commandcode-usage-bar/actions/workflows/ci.yml">
    <img alt="CI" src="https://github.com/jhparkdev/commandcode-usage-bar/actions/workflows/ci.yml/badge.svg">
  </a>
</p>

---

## Why

Your plan limits live in a browser tab that you have to remember to open. Usage is the
kind of number you want to see *while* you work, not after the fact.

Command Code Usage Bar keeps the three numbers that matter in the macOS menu bar, and
turns them into a history you can actually look at.

## What it shows

Everything is expressed as **remaining**, not spent — the question you care about is
"how much is left", not "how much did I use".

| Panel | Reads as | Resets |
|---|---|---|
| **5-hour limit** | remaining credits, cap, % left, time to reset | rolling 5 hours |
| **Weekly limit** | remaining credits, cap, % left, time to reset | rolling 7 days |
| **Monthly limit** | remaining credits, cap, % left, days left | billing period |
| **Today** | credits, requests, input/output tokens observed locally | daily |
| **Last 7 days** | daily credit usage | — |

The menu bar item mirrors whichever limit you pick, and changes color as the remaining
amount runs out.

## Install

Requires **macOS 13 or later** (Intel x86_64 and Apple Silicon arm64 are both supported).

1. Download the latest `.dmg` or `.zip` from [Releases](https://github.com/jhparkdev/commandcode-usage-bar/releases).
2. Drag the app into `Applications`.
3. Launch it. It appears in the menu bar — no Dock icon, no window.
4. Make sure you are signed in to the Command Code desktop app.

```bash
curl -LO https://github.com/jhparkdev/commandcode-usage-bar/releases/latest/download/Command.Code.Usage.Bar-0.1.0-universal.dmg
hdiutil attach "Command.Code.Usage.Bar-0.1.0-universal.dmg"
cp -R "/Volumes/Command Code Usage Bar/Command Code Usage Bar.app" ~/Applications/
hdiutil detach "/Volumes/Command Code Usage Bar"
```

> The release build is not signed with a Developer ID certificate. On first launch macOS
> may ask you to confirm: right-click the app → **Open**.

## How it works

1. **Auth** — the app reads the API key from your local Command Code session
   (`~/.commandcode/auth.json`) and keeps it in memory only.
2. **Query** — it calls the same endpoints the Command Code desktop app uses
   (`/alpha/whoami`, `/alpha/billing/credits`, `/alpha/billing/subscriptions`,
   `/alpha/usage/summary`) every 60 seconds, and immediately after the machine wakes.
3. **Accumulate** — the server only reports the current period total, so snapshots are
   written to a local SQLite database and the delta between observations is what the
   daily and hourly history is built from. The first observation of a period is a
   baseline, so pre-install usage is never misattributed to today.
4. **Render** — a SwiftUI `MenuBarExtra` surfaces the numbers, styled with the macOS 26
   Liquid Glass design language.

Nothing is sent anywhere except `api.commandcode.ai`.

## Settings

| Setting | Options |
|---|---|
| Refresh interval | 30s / 60s / 120s / 300s |
| Menu bar shows | 5-hour limit / weekly limit / monthly limit |
| Notifications | when remaining drops below 20% or 5% |
| Launch at login | on / off |
| Authentication | local session file / user-selected file / manual API key |

## Development

```bash
git clone https://github.com/jhparkdev/commandcode-usage-bar.git
cd commandcode-usage-bar

swift run UsageCoreTestRunner     # run the test suite
./scripts/build-app.sh --run      # build and launch (current architecture)
./scripts/build-app.sh --universal # build arm64 + x86_64
```

The project is plain SwiftPM — no Xcode project, no third-party dependencies. It is
organized as three targets:

| Target | Role |
|---|---|
| `UsageCore` | domain model, API client, SQLite store, authentication |
| `GlassUI` | the Liquid Glass design system (tokens, panels, meters, buttons) |
| `CommandCodeUsageBar` | the menu bar app and its views |

## Compatibility

| macOS | Appearance |
|---|---|
| 26 and later | native Liquid Glass (`glassEffect`, glass button styles) |
| 13 – 25 | material-based fallback with the same layout and metrics |

The app is built against the macOS 26 SDK but deploys back to macOS 13, so both the
new glass surfaces and the older material surfaces come from the same design tokens.

## Privacy

- Your API key is read from disk, held in memory, and never written to disk, logs, or
  `UserDefaults`. If you enter a key manually it is stored in the macOS Keychain.
- Usage numbers stay on your machine, in
  `~/Library/Application Support/CommandCodeUsageBar/usage.sqlite` (mode `0600`).
- No telemetry, no analytics, no crash reporting.

## Contributing

Issues and pull requests are welcome. Please keep the design system in `GlassUI`
consistent — spacing comes from `GlassLayout` roles, not ad-hoc numbers — and add
tests for behavior changes (`swift run UsageCoreTestRunner`).

Implementation details live in [docs/architecture.md](docs/architecture.md): API
contract, accumulation rules, the spacing system, and the release pipeline.

## License

MIT — see [LICENSE](LICENSE).
