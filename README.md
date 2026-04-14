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

### 2. Build
```bash
cd Flyby
swift build -c release
```

### 3. Install
```bash
cp .build/release/Flyby /Applications/Flyby
chmod +x /Applications/Flyby
```

### 4. Run
```bash
/Applications/Flyby
```

Or open from Finder:
- Go to `/Applications`
- Double-click Flyby
- If prompted about "unidentified developer", right-click > Open > Open

### 5. Add to Login Items (optional)
- System Settings > General > Login Items
- Click + and add Flyby

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

### CPU/RAM showing 0%
The app needs a second refresh cycle to calculate CPU usage. Wait 10 seconds for accurate readings.

### Thermal shows "Nominal" always
This is expected - Apple Silicon Macs rarely reach elevated thermal states under normal use.

## License

MIT License