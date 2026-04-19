# Flyby

Real-time system monitoring app for macOS (Apple Silicon M1+/M2+).

## Features

- **CPU %** - Processor usage via Mach APIs
- **RAM %** - Memory usage via vm_statistics64  
- **Thermal State** - System thermal state (official API)
- **Menu Bar** - Always visible in menu bar
- **Dashboard** - Detailed view with charts
- **Auto-login** - Launch at login option
- **Configurable** - Adjustable refresh interval

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1, M2, M3, M4, M5)
- Xcode 15.3+

## Installation

### 1. Install Command Line Tools (if needed)
```bash
xcode-select --install
```

### 2. Package the app bundle
```bash
./scripts/package-app.sh
```

This creates `dist/Flyby.app`.

### 3. Install to Applications
```bash
./scripts/install-app.sh
```

By default the installer copies `Flyby.app` to `/Applications`. If that folder is not writable, it falls back to `~/Applications`.

### 4. Run without Terminal
- Open `Flyby` from Finder
- Search for `Flyby` in Spotlight
- Search for `Flyby` in Raycast

If macOS warns that the app is from an unidentified developer, right-click `Flyby.app` in Finder and choose `Open` once.

### 5. Add to Login Items (optional)
- Open Flyby once from `/Applications/Flyby.app`
- Enable `Launch at Login` inside the app

## How It Works

### Menu Bar
The app displays in your menu bar:
```
CPU: 12% | RAM: 47% | ●
```
- Click to open Dashboard
- Updates every 5 seconds (configurable)

### Dashboard
Shows:
- CPU usage chart
- Memory usage chart  
- Thermal state indicator
- Settings (refresh interval, auto-login)

### Thermal State
| State | Description |
|-------|------------|
| ● Nominal | Normal temperature |
| ◐ Fair | Running warm |
| ◑ Serious | Hot, may throttle |
| ◉ Critical | Reduce load immediately |

Note: Apple does NOT provide a public API for actual temperature readings. Thermal state is the official API available.

## Project Structure

```
Flyby/
├── Sources/Flyby/
│   ├── App/SystemMonitorApp.swift      # Main app + menu bar
│   ├── Services/SystemMonitorService.swift  # Monitoring logic
│   ├── Views/
│   │   ├── DashboardView.swift       # Main dashboard
│   │   └── Components/
│   │       ├── CPUChartView.swift
│   │       ├── RAMChartView.swift
│   │       └── ThermalStateView.swift
│   └── Utilities/Settings.swift       # Settings
└── Package.swift
```

## Troubleshooting

### "App cannot be opened because it is from an unidentified developer"
1. Right-click the app in Finder
2. Select "Open"
3. Click "Open" in the dialog

### Flyby does not appear in Spotlight or Raycast yet
- Confirm the app is installed as `Flyby.app` in `/Applications` or `~/Applications`
- Wait a few seconds for macOS indexing to catch up
- Run `mdimport /Applications/Flyby.app` if you want to force a metadata refresh

### CPU/RAM showing 0%
The app needs a second refresh cycle to calculate CPU usage. Wait 10 seconds for accurate readings.

### Thermal shows "Nominal" always
This is expected - Apple Silicon Macs rarely reach elevated thermal states under normal use.

## License

MIT License
