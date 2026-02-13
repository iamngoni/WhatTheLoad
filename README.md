# WhatTheLoad

> "Figure out what the load is going on with your Mac"

A comprehensive macOS menu bar app for real-time system monitoring.

![WhatTheLoad Screenshot](screenshot.png)

## Features

### 📊 Comprehensive Monitoring

- **CPU**: Real-time usage, per-core metrics, temperature, frequency, throttle status
- **Memory**: Usage breakdown (used/wired/compressed/free), pressure monitoring, swap tracking
- **Network**: Upload/download speeds, interface info, local/public IP, active connections
- **Wi-Fi**: Deep diagnostics with signal strength, ping, jitter, packet loss, speed tests
- **Disk**: Volume capacity, read/write speeds, SMART status
- **Processes**: Top processes by CPU/memory, searchable, killable
- **Battery**: Charge level, health, cycle count, temperature, power draw, time remaining

### 📈 Menu Bar Display

- **Live sparkline**: CPU load visualized as a gradient chart (green/orange/red)
- **Network throughput**: Real-time upload/download speeds in monospaced text
- Single-click access to full dashboard popover

### 🎯 Advanced Wi-Fi Diagnostics

- Signal strength and noise floor monitoring
- Router health: ping, jitter, packet loss tracking
- Internet health: separate metrics to 1.1.1.1
- DNS lookup time measurement
- Cloudflare-based speed testing
- Intelligent diagnostic tips based on network conditions
- Band detection (2.4 GHz / 5 GHz / 6 GHz)

### ⚙️ Customization

- Adjustable poll intervals for each metric
- Menu bar display options
- Launch at login support
- Color-coded metrics (green = good, orange = warning, red = critical)

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac

## Installation

### Direct Download

1. Download the latest release from [Releases](../../releases)
2. Open the DMG file
3. Drag WhatTheLoad.app to your Applications folder
4. Launch from Applications

### Build from Source

```bash
git clone https://github.com/yourusername/WhatTheLoad.git
cd WhatTheLoad
open WhatTheLoad.xcodeproj
# Build and run in Xcode
```

## Usage

1. **Launch the app**: WhatTheLoad appears in your menu bar
2. **Click the menu bar item**: Opens the dashboard popover
3. **Navigate tabs**: Click the icons to switch between monitoring sections
4. **Settings**: Click the gear icon to customize poll intervals and display options

### Menu Bar Display

- **Sparkline**: Live CPU usage chart with color-coded gradient
- **Network text**: `↑2.3 ↓14.1 MB/s` format showing upload/download speeds

### Dashboard Sections

1. **CPU** (⚙️): Aggregate and per-core usage with temperature/frequency
2. **Memory** (💾): Ring chart with breakdown and pressure monitoring
3. **Network** (↕️): Upload/download sparklines with connection info
4. **Wi-Fi** (📡): Comprehensive diagnostics with speed test
5. **Disk** (💿): Volume capacity and I/O speeds
6. **Processes** (📋): Sortable process list with kill capability
7. **Battery** (🔋): Charge, health, and power metrics

## Architecture

- **Swift 5.9+** with SwiftUI and `@Observable` macro
- **Real system APIs**: mach, IOKit, CoreWLAN, Network framework
- **No sandboxing**: Direct download distribution for full system access
- **Background monitoring**: Independent dispatch queues per monitor
- **Rolling history**: 60-120 sample buffers for sparklines

## Privacy

WhatTheLoad runs entirely locally on your Mac. No data is collected, transmitted, or shared. All monitoring happens using standard macOS system APIs.

## License

MIT License - see LICENSE file for details

## Credits

Built with ❤️ using Swift and SwiftUI

Inspired by:
- iStat Menus
- MenuMeters
- WhyFi

---

**Have feedback or found a bug?** [Open an issue](../../issues)
