import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let monitors: MonitorCoordinator
    let historyStore: HistoryStore

    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    init(
        monitors: MonitorCoordinator = .shared,
        historyStore: HistoryStore = .shared
    ) {
        self.monitors = monitors
        self.historyStore = historyStore
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pollIntervalsSection
                    divider
                    menuBarSection
                    divider
                    alertsSection
                    divider
                    batteryAutomationSection
                    divider
                    diagnosticsSection
                    divider
                    systemSection
                }
                .padding(16)
            }
        }
        .frame(width: 360, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var pollIntervalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "POLL INTERVALS")

            SliderRow(title: "CPU", value: $settings.cpuPollInterval, range: 0.5...10, unit: "s")
            SliderRow(title: "Memory", value: $settings.memoryPollInterval, range: 1...30, unit: "s")
            SliderRow(title: "Network", value: $settings.networkPollInterval, range: 0.5...10, unit: "s")
            SliderRow(title: "Wi-Fi", value: $settings.wifiPollInterval, range: 0.5...10, unit: "s")
            SliderRow(title: "Disk", value: $settings.diskPollInterval, range: 1...60, unit: "s")
            SliderRow(title: "Processes", value: $settings.processesPollInterval, range: 1...30, unit: "s")
            SliderRow(title: "Battery", value: $settings.batteryPollInterval, range: 5...120, unit: "s")

            Button("Apply Polling Changes") {
                monitors.restartAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "MENU BAR")

            Toggle("Show Sparkline", isOn: $settings.showMenuBarSparkline)
                .font(.system(size: 12))

            Toggle("Show Network Speed", isOn: $settings.showMenuBarNetworkText)
                .font(.system(size: 12))

            Picker("Sparkline Metric", selection: $settings.menuBarSparklineMetric) {
                Text("CPU").tag("cpu")
                Text("Memory").tag("memory")
                Text("Network").tag("network")
            }
            .pickerStyle(.segmented)
            .font(.system(size: 11))
        }
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "ALERTS")

            Toggle("Enable Alerts", isOn: $settings.alertsEnabled)
                .font(.system(size: 12))

            if settings.alertsEnabled {
                SliderRow(title: "Cooldown", value: $settings.alertsCooldownMinutes, range: 1...60, unit: "m")

                Toggle("Quiet Hours", isOn: $settings.alertsQuietHoursEnabled)
                    .font(.system(size: 12))

                if settings.alertsQuietHoursEnabled {
                    HourPickerRow(title: "Start", value: $settings.alertsQuietHoursStartHour)
                    HourPickerRow(title: "End", value: $settings.alertsQuietHoursEndHour)
                }

                SliderRow(title: "CPU %", value: $settings.cpuUsageAlertThreshold, range: 50...100, unit: "%")
                SliderRow(title: "CPU Temp", value: $settings.cpuTempAlertThreshold, range: 60...110, unit: "°C")
                SliderRow(title: "Packet Loss", value: $settings.packetLossAlertThreshold, range: 1...20, unit: "%")
                SliderRow(title: "Jitter", value: $settings.jitterAlertThreshold, range: 5...150, unit: "ms")
                SliderRow(title: "Low Disk", value: $settings.lowDiskFreePercentThreshold, range: 2...30, unit: "%")
            }

            Toggle("Low Battery Popup", isOn: $settings.lowBatteryAlertsEnabled)
                .font(.system(size: 12))

            if settings.lowBatteryAlertsEnabled {
                SliderRow(title: "Battery Alert", value: $settings.lowBatteryAlertThreshold, range: 5...50, unit: "%")
            }
        }
    }

    private var batteryAutomationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "BATTERY AUTOMATION")

            Toggle("Enable Low Battery Automation", isOn: $settings.batteryAutomationEnabled)
                .font(.system(size: 12))

            if settings.batteryAutomationEnabled {
                SliderRow(title: "Automation Threshold", value: $settings.batteryAutomationThreshold, range: 5...60, unit: "%")

                Toggle("Auto-open Battery Settings", isOn: $settings.batteryAutomationAutoOpenSettings)
                    .font(.system(size: 12))
            }

            HStack {
                Text("Power Save Mode")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text(settings.powerSaveModeActive ? "Active" : "Inactive")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(settings.powerSaveModeActive ? .orange : .secondary)
            }
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "DIAGNOSTICS")

            Button("Export Diagnostics Bundle") {
                DiagnosticsExporter.export(monitors: monitors, historyStore: historyStore, settings: settings)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !settings.lastDiagnosticsExportStatus.isEmpty {
                Text(settings.lastDiagnosticsExportStatus)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "SYSTEM")

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .font(.system(size: 12))
                .onChange(of: settings.launchAtLogin) { _, newValue in
                    toggleLaunchAtLogin(enabled: newValue)
                }

            Button("Reset to Defaults") {
                settings.resetToDefaults()
                monitors.setPowerSaveMode(false)
                monitors.restartAll()
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .font(.system(size: 12))
        }
    }

    private var divider: some View {
        Divider().padding(.vertical, 4)
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
            .tracking(0.5)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                Spacer()

                Text(String(format: "%.1f%@", value, unit))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Slider(value: $value, in: range)
        }
    }
}

private struct HourPickerRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()

            Picker(title, selection: Binding(
                get: { Int(value) },
                set: { value = Double($0) }
            )) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d:00", hour)).tag(hour)
                }
            }
            .frame(width: 110)
        }
    }
}
