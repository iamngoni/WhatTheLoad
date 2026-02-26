# WhatTheLoad

WhatTheLoad is a macOS menu bar utility that surfaces the system metrics you usually have to dig around for: CPU, memory, network throughput, Wi-Fi quality, disk usage, processes, and battery health.

The goal is fast diagnostics from the menu bar, with a compact popover for deeper context.

## What It Shows

### Menu Bar (Always Visible)

- Live download/upload throughput (`↓` / `↑`)
- Battery remaining time (or charging ETA when macOS provides it)
- One-click access to the full popover dashboard

### Popover Dashboard Tabs

1. `CPU`
   - Total CPU usage
   - Per-core usage bars
   - CPU temperature (when available)
   - Frequency and throttle status fields

2. `Memory`
   - Used / wired / compressed / free breakdown
   - Memory pressure summary
   - Swap activity summary
   - Top memory consumers

3. `Network`
   - Upload/download sparklines
   - Interface name and local IP
   - Connection count field

4. `Wi-Fi`
   - Link rate, RSSI, noise floor
   - Router and internet ping/jitter/loss
   - DNS lookup timing
   - Band detection (`2.4 GHz`, `5 GHz`, `6 GHz`)
   - Wi-Fi speed test (manual)
   - SSID permission guidance + quick actions (request/open settings)

5. `Disk`
   - Mounted volumes
   - Capacity usage and free space
   - Read/write activity charts

6. `Processes`
   - Searchable process list
   - CPU / memory columns
   - Context menu to terminate a process

7. `Battery`
   - Charge state and percentage
   - Time remaining / time to full
   - Health and cycle count
   - Temperature (when available)

## Permissions (Important)

### Wi-Fi Name / SSID

macOS may return Wi-Fi radio details (band/channel) while hiding the SSID unless Location access is granted.

WhatTheLoad now handles this explicitly:

- It still shows Wi-Fi diagnostics when SSID is unavailable
- It shows a warning card explaining why
- It includes:
  - `Request Access` (if permission has not been decided yet)
  - `Open Location Settings` (if access was denied)

If you see `SSID` as unavailable but the Wi-Fi tab shows a band badge (for example `5 GHz`), you are connected; macOS is just withholding the network name.

## Installation

### Build from Source

```bash
git clone <your-repo-url>
cd WhatTheLoad
open WhatTheLoad.xcodeproj
```

Then build/run in Xcode (`WhatTheLoad` scheme, macOS target).

## Requirements

- macOS (modern version with SwiftUI menu bar support)
- Xcode with a recent Swift toolchain

## Architecture Notes

- SwiftUI UI with `@Observable` monitors
- Polling-based metrics collection with rolling history buffers
- Uses macOS APIs including:
  - `mach`
  - `IOKit`
  - `CoreWLAN`
  - `Network`
  - `CoreLocation` (for Wi-Fi SSID access)

## Current State / Known Gaps

This project is actively being improved. Some metrics are already strong and useful (especially live throughput, Wi-Fi radio diagnostics, and battery health), while some values are still simplified/approximate placeholders and should be treated as directional until replaced with fully native collectors.

Planned improvements include:

- Battery power draw (watts) on supported hardware
- Alerting thresholds for common problems
- Optional menu bar display modes (network-only / CPU+memory / rotating)
- Exportable diagnostic snapshots

## Privacy

WhatTheLoad runs locally on your Mac. Metrics are collected on-device and are not uploaded anywhere by the app.

The optional speed test feature performs network requests to measure throughput.

## License

MIT — see `LICENSE`.
