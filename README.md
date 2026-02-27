# WhatTheLoad

WhatTheLoad is a macOS menu bar diagnostics app focused on fast, practical system visibility.

It shows live network throughput in the menu bar and provides a compact popover with deep system tabs for CPU, memory, network, Wi-Fi, disk, processes, timeline history, and battery.

## Highlights

- Live menu bar telemetry:
  - Download/upload speed (`↓` / `↑`)
  - Battery time remaining or charging state (no battery percentage noise)
- Multi-tab diagnostics dashboard:
  - CPU, Memory, Network, Wi-Fi, Disk, Processes, Timeline, Battery
- Smart alert engine:
  - CPU usage, CPU temp, memory pressure, packet loss, jitter, low disk, low battery
  - Cooldown + quiet hours
  - Blocking popups for critical events
- Timeline + history:
  - Persisted events and periodic metric snapshots
  - 24h / 7d view with trend sparklines
- Network incident detection:
  - Gateway unreachable
  - Internet outage
  - DNS failure
  - Unstable link
- Disk cleanup tools:
  - Category cleanup with size estimates: Caches, Logs, DerivedData, Browser Caches
  - Finder reveal and trash actions
- Process drilldown:
  - Select process for details, CPU/memory trends, executable path, open file/socket counts
  - Guarded Quit / Force Quit actions
- Battery automation:
  - Auto-enable low-power polling profile on low battery
  - Optional auto-open Battery settings
- Diagnostics bundle export:
  - `snapshot.json`, `timeline_events.json`, `metric_snapshots.json`, `process_top.json`, `network_diagnostics.json`

## Permissions

### Wi-Fi SSID access

macOS can hide SSID unless location permission is granted.

WhatTheLoad supports this flow directly in the Wi-Fi tab:

- `Request Access`
- `Open Location Settings` fallback when macOS does not show the prompt

Required `Info.plist` keys are included for location usage descriptions.

## Build

### Debug

```bash
xcodebuild -project WhatTheLoad.xcodeproj -scheme WhatTheLoad -configuration Debug build
```

### Release

```bash
xcodebuild -project WhatTheLoad.xcodeproj -scheme WhatTheLoad -configuration Release build
```

Built app path:

```bash
~/Library/Developer/Xcode/DerivedData/WhatTheLoad-*/Build/Products/Release/WhatTheLoad.app
```

## Install to Applications

```bash
pkill -x WhatTheLoad || true
cp -R ~/Library/Developer/Xcode/DerivedData/WhatTheLoad-*/Build/Products/Release/WhatTheLoad.app /Applications/
open /Applications/WhatTheLoad.app
```

## Diagnostics Export Contents

- `snapshot.json`: current monitor state
- `timeline_events.json`: recent timeline events
- `metric_snapshots.json`: periodic snapshots
- `process_top.json`: top processes at export time
- `network_diagnostics.json`: route/DNS/incident diagnostics
- `README.txt`: export timestamp and file guide

## Tech Notes

- SwiftUI + Observation (`@Observable` monitors)
- Main monitor coordinator with adaptive polling profile
- Uses macOS APIs: `mach`, `IOKit`, `CoreWLAN`, `Network`, `CoreLocation`, `SystemConfiguration`

## License

MIT (`LICENSE`)
