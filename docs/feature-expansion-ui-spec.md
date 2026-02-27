# WhatTheLoad Feature Expansion UI Spec

This spec defines the UI before implementation for features 1-7:
alert rules, timeline/history, network incident detection, disk cleanup v2,
process drilldown, battery automation, and diagnostics export.

## Global Navigation

- Add a new `Timeline` tab in the main tab strip (`clock.badge.exclamationmark`).
- Keep existing tab order and append Timeline before Battery:
  `CPU | Memory | Network | Wi-Fi | Disk | Processes | Timeline | Battery`.

## Settings Additions

### Alerts

- `Enable Alerts` toggle.
- `Cooldown` slider (minutes).
- `Quiet Hours` toggle.
- `Quiet Hours Start` + `Quiet Hours End` selectors (hour-of-day).
- Threshold sliders:
  - CPU usage %
  - CPU temperature C
  - Packet loss %
  - Jitter ms
  - Low disk free %
  - Low battery %

### Battery Automation

- `Enable Low Battery Automation` toggle.
- `Automation Threshold %` slider.
- `Auto-open Battery Settings` toggle.
- Read-only status text: `Power Save Mode: Active/Inactive`.

### Diagnostics

- `Export Diagnostics Bundle` button.
- Status line for last export result.

## Timeline Tab

- Header: `TIMELINE` with range selector:
  - `24h`
  - `7d`
- Summary cards:
  - Alerts count
  - Incidents count
  - Cleanup actions
  - Last snapshot age
- Trend strip charts:
  - CPU
  - Memory pressure
  - Network download/upload
  - Battery %
- Event list (newest first):
  - Timestamp
  - Severity badge (`info|warning|critical`)
  - Category (`alert|network|disk|system`)
  - Title + message

## Network + Wi-Fi Incident UX

- Add incident card in `Network` and `Wi-Fi` tabs when detected:
  - `Gateway Unreachable`
  - `Internet Outage`
  - `DNS Failure`
  - `Unstable Link`
- Each card includes:
  - concise cause
  - recommended action
  - relevant metrics (loss/jitter/ping/dns)

## Disk Cleanup v2 UX

- Keep existing disk volume + throughput.
- Add `Cleanup Categories` panel:
  - `Caches`
  - `Logs`
  - `Xcode DerivedData`
  - `Browser Caches`
- Each category row:
  - dry-run size preview
  - `Clean` button
  - `Reveal` button
- Add safe exclusions note for protected paths.

## Processes Drilldown UX

- Keep list view.
- Add row selection state.
- Detail panel for selected process:
  - live CPU sparkline
  - live memory sparkline
  - executable path
  - top open files count
  - network sockets count
- Safe actions:
  - `Reveal in Finder`
  - `Quit` (guarded)
  - `Force Quit` (guarded + confirm)

## Battery UX

- Keep current health and cycle stats.
- Add automation status banner when active.
- Keep low-battery modal popup requiring dismiss.

## Export Bundle Contents

- `snapshot.json` (current monitor state).
- `timeline_events.json`.
- `metric_snapshots.json`.
- `process_top.json`.
- `network_diagnostics.json` (route, DNS, incident state).
- `README.txt` with capture timestamp and app version.
