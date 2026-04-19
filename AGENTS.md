# Repository Guidelines

## Project Structure & Module Organization
`Flyby` is a Swift Package Manager macOS app. The executable target lives in `Sources/Flyby`.

- `Sources/Flyby/App`: app entry point and menu bar lifecycle (`SystemMonitorApp.swift`)
- `Sources/Flyby/Services`: system metric collection and refresh logic
- `Sources/Flyby/Views`: SwiftUI screens such as `DashboardView.swift` and `MenuBarView.swift`
- `Sources/Flyby/Views/Components`: reusable chart and status components
- `Sources/Flyby/Utilities`: persisted settings and small support types
- `Resources/Assets.xcassets`: app assets

Keep new code in the existing folder split: app wiring in `App`, metric logic in `Services`, and UI in `Views`.

## Build, Test, and Development Commands
- `swift build`: compile the app in debug mode
- `swift build -c release`: produce the optimized binary in `.build/release/Flyby`
- `swift run Flyby`: launch the app locally from the package
- `swift test`: run package tests when a `Tests/` target is present

Example install flow:

```bash
swift build -c release
cp .build/release/Flyby /Applications/Flyby
```

## Coding Style & Naming Conventions
Use Swift defaults with 4-space indentation and one top-level type per file where practical. Prefer `UpperCamelCase` for types (`SystemMonitorService`), `lowerCamelCase` for properties and methods (`refreshInterval`, `updateInterval`), and singular names for service objects.

Follow the current architecture: SwiftUI views stay declarative, platform integration stays in `AppKit`-backed app delegate code, and system calls stay isolated in `Services`.

## Testing Guidelines
There is no committed `Tests/` target yet. For new logic-heavy changes, add focused unit tests under `Tests/FlybyTests` and name them by behavior, for example `testRAMUsageMatchesExpectedFormula()`. Until tests exist, verify changes with `swift build` and a local run on macOS 13+ Apple Silicon hardware.

## Commit & Pull Request Guidelines
Recent history uses short, imperative subjects with optional prefixes, such as `feat: add ...`, `Fix CPU: ...`, and `UI: ...`. Keep commit titles concise and scoped to one change.

PRs should include:
- a short description of user-visible behavior
- linked issue or task when applicable
- screenshots for menu bar or dashboard UI changes
- notes about macOS or hardware-specific validation
