# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Flyby is a macOS menu bar app (Swift Package, no Xcode project, Apple Silicon, macOS 13+) showing CPU, RAM, thermal state and a per-app volume mixer. UI copy is in Brazilian Portuguese; code and docs are in English.

## Commands

- `swift build` / `swift build -c release`: compile (there is no `Tests/` target yet, so `swift test` has nothing to run).
- `swift run Flyby`: run from the package. This is not an `.app` bundle, so the in-app updater refuses to install (it needs `Bundle.main.bundleURL` to end in `.app`) and audio-capture permission prompts behave differently.
- `./scripts/package-app.sh`: builds release and assembles an ad-hoc signed `dist/Flyby.app` (copies `Resources/App/Info.plist` and `Flyby.icns`).
- `./scripts/install-app.sh`: packages, copies to `/Applications` (or `~/Applications`) and opens it.
- `./scripts/make-dmg.sh`: builds `dist/Flyby-macos-arm64.dmg` from `dist/Flyby.app`. Needs `dmgbuild` (pip) for the styled window, otherwise it falls back to a plain DMG.
- The binary has hidden CLI modes used by the scripts: `Flyby --export-icons <dir>` (see `generate-icns.sh`) and `Flyby --export-dmg-background <dir> <version> <minOS>`. They render with the same Swift code as the app and quit.

## Architecture

- **App shell** (`App/SystemMonitorApp.swift`): SwiftUI `@main` with an empty `Settings` scene; everything real happens in `AppDelegate` (`LSUIElement`, so no Dock icon). It owns the `NSStatusItem`, updates its title every 2 s, and re-applies title/icon whenever `AppSettings` publishes a change.
- **Panel** (`Views/PanelController.swift`, `PanelView.swift`): the UI is a borderless `NSPanel` hosting SwiftUI, not an `NSPopover`, so the view draws its own surface. Preferences replace the panel content (`PanelState.showingPreferences`) rather than opening a window. The panel closes through a global mouse-down monitor; clicks on the status item itself must be ignored by that monitor, otherwise `toggle()` reopens the panel.
- **Services** are `ObservableObject` singletons (`.shared`) observed directly by views:
  - `SystemMonitorService`: timer-driven CPU (Mach), RAM (`vm_statistics64`), thermal state.
  - `AppVolumeService`: per-app volume using Core Audio **process taps** (macOS 14.2+, guarded by `#available`, taps are type-erased in a dictionary). Tapped apps are muted at the source and replayed through an aggregate device at the chosen gain; at 100% the tap is removed. Needs `NSAudioCaptureUsageDescription` in `Info.plist`.
  - `OutputVolumeService`: master volume/mute of the default output, polled only while the panel is visible.
  - `UpdateService`: checks GitHub Releases (`femitz/flyby`) at launch and every 5 h (10-minute timer compared against a stored timestamp), installs only on user click: downloads `Flyby-macos-arm64.zip`, verifies `SHA256SUMS` and `codesign`, then a detached bash helper waits for the app to exit, swaps the bundle (restoring the old one on failure) and relaunches. Release asset names are part of this contract.
- **Settings** (`Utilities/Settings.swift`): `AppSettings.shared` wraps `UserDefaults`; booleans default to `true` when unset.
- **Design** (`Design/Brand.swift`): palette, fonts and shared components (`BrandLabel`, `BrandDivider`, `BrandButtonStyle`, `TelemetryRing`, `BrandSlider`). Use these instead of ad-hoc colors. App icons and the DMG background are drawn in code (`Utilities/AppIcon.swift`, `InstallerBackground.swift`), not stored as images.

## Brand rules

For any UI or copy change, follow `.claude/skills/flyby-brand/SKILL.md` ("direção Órbita"): dark vacuum surfaces, mono numbers, and a single orange accent (`Brand.ignicao`) used only to mark where something happens, never as a large fill.

## Release flow

`.github/workflows/build.yml` runs on `v*` tags: stamps the tag into `CFBundleShortVersionString`, packages, builds the DMG and ZIP, writes `SHA256SUMS`, and creates the GitHub Release. The installed app's version comes from that stamp, and `UpdateService` compares it to the latest release tag, so tags must be `vX.Y.Z`. The app is ad-hoc signed, not notarized.

## Notes

- Commits and PRs use short imperative subjects with prefixes (`feat:`, `fix:`, `docs:`, `build:`). The project is licensed PolyForm Noncommercial 1.0.0.
